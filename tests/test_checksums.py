#!/usr/bin/env python3
"""Checksum contract checks; run with python3 tests/test_checksums.py."""

import hashlib
import importlib.util
import json
from pathlib import Path
import shutil
import subprocess
import tempfile
import time
import unittest
from unittest.mock import patch

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location("harness", ROOT / "lib/test_harness.py")
harness = importlib.util.module_from_spec(spec)
spec.loader.exec_module(harness)


class ExtensionChecksums(unittest.TestCase):
    def test_manifest_validation_and_fallback(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            image = root / "one.raw"
            image.write_bytes(b"extension")
            digest = hashlib.sha256(image.read_bytes()).hexdigest()
            self.assertEqual(harness.expected_checksum(image, "one", "", False), (digest, "local fallback"))
            with self.assertRaisesRegex(ValueError, "No recorded checksum"):
                harness.expected_checksum(image, "one", "", True)
            manifest = root / "SHA256SUMS.one"
            manifest.write_text(f"{digest}  ./build/one.raw\n")
            self.assertEqual(harness.expected_checksum(image, "one", "", True), (digest, str(manifest)))
            image.write_bytes(b"corrupted")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                harness.verify_artifact(image, "one", "", False)

    def test_invalid_duplicate_and_conflicting_records_fail(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            image = root / "one.raw"
            image.write_bytes(b"extension")
            record = f"{'a' * 64} *one.raw\n"
            manifest = root / "SHA256SUMS"
            for content in ["not a checksum\n", record + record]:
                manifest.write_text(content)
                with self.assertRaises(ValueError):
                    harness.expected_checksum(image, "one", "", False)
            manifest.write_text(record)
            (root / "SHA256SUMS.one").write_text(f"{'b' * 64}  one.raw\n")
            with self.assertRaisesRegex(ValueError, "Conflicting"):
                harness.expected_checksum(image, "one", "", False)

    def test_explicit_manifest_is_exclusive_and_requires_each_image(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            image = root / "one.raw"
            image.write_bytes(b"extension")
            (root / "SHA256SUMS.one").write_text(f"{'a' * 64}  one.raw\n")
            manifest = root / "custom sums"
            manifest.write_text(f"{'b' * 64}  two.raw\n")
            with self.assertRaisesRegex(ValueError, "No recorded checksum"):
                harness.expected_checksum(image, "one", str(manifest), False)
            manifest.write_text(f"{'c' * 64}  one-other.raw\n")
            with self.assertRaisesRegex(ValueError, "No recorded checksum"):
                harness.expected_checksum(image, "one", str(manifest), False)

    def test_bad_manifest_fails_before_docker_or_qemu(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            image = root / "one.raw"
            image.write_bytes(b"extension")
            (root / "SHA256SUMS").write_text(f"{'0' * 64}  one.raw\n")
            result = subprocess.run([str(ROOT / "bakery.sh"), "test", str(image)],
                                    cwd=root, text=True, capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("checksum mismatch", result.stdout + result.stderr)
            self.assertNotIn("Booting", result.stdout)
            self.assertFalse(list(root.glob("sysext-test-*")))

    def test_copied_artifact_is_checked_and_manifest_paths_are_not_opened(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            source = root / "one.raw"
            source.write_bytes(b"extension")
            copy = root / "copy" / "one.raw"
            copy.parent.mkdir()
            copy.write_bytes(source.read_bytes())
            digest = hashlib.sha256(source.read_bytes()).hexdigest()
            (root / "SHA256SUMS").write_text(f"{digest}  /does/not/exist/one.raw\n")
            self.assertEqual(harness.verify_artifact(copy, "one", "", True, source), digest)
            copy.write_bytes(b"bad copy")
            with self.assertRaisesRegex(ValueError, "checksum mismatch"):
                harness.verify_artifact(copy, "one", "", True, source)


class OSChecksums(unittest.TestCase):
    def test_failed_download_does_not_publish_cache(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cache, destination = root / "cache", root / "vm"
            cache.mkdir()
            destination.mkdir()
            def failed_download(url, path):
                Path(path).write_text("partial")
                raise ValueError("failed download")
            with patch.object(harness, "download", failed_download):
                with self.assertRaisesRegex(ValueError, "failed download"):
                    harness.prepare_files("amd64", cache, destination)
            self.assertFalse((cache / "verified").exists())
            self.assertFalse(list(cache.glob(".download-*")))
            self.assertFalse(list(destination.iterdir()))

    def test_cancelled_download_removes_staging_and_children(self):
        with tempfile.TemporaryDirectory() as temp:
            root = Path(temp)
            cache, destination = root / "cache", root / "vm"
            cache.mkdir()
            destination.mkdir()
            fake = root / "curl"
            ready = root / "ready"
            fake.write_text(f'''#!/usr/bin/env python3
import os, sys, time
from pathlib import Path
Path(sys.argv[sys.argv.index('-o') + 1]).write_text('partial')
Path({str(ready)!r}).write_text(str(os.getpid()))
time.sleep(300)
''')
            fake.chmod(0o755)
            import os
            process = subprocess.Popen(["python3", str(ROOT / "lib/test_harness.py"), "prepare", "amd64",
                                        str(cache), str(destination)], stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                       env={**os.environ, "PATH": str(root) + ":" + os.environ["PATH"]})
            try:
                deadline = time.monotonic() + 5
                while not ready.exists():
                    if process.poll() is not None or time.monotonic() > deadline:
                        self.fail("fake download did not start")
                    time.sleep(0.02)
                process.terminate()
                stdout, stderr = process.communicate(timeout=10)
                self.assertEqual(process.returncode, 143, (stdout, stderr))
                self.assertFalse(list(cache.glob(".download-*")))
                self.assertFalse(list(destination.iterdir()))
                with self.assertRaises(ProcessLookupError):
                    os.kill(int(ready.read_text()), 0)
            finally:
                if process.poll() is None:
                    process.kill()
                    process.communicate()


@unittest.skipUnless(shutil.which("gpg"), "Run signed-artifact tests on the Linux test host with GPG")
class SignedOSChecksums(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.temporary = tempfile.TemporaryDirectory()
        cls.addClassCleanup(cls.temporary.cleanup)
        cls.root = Path(cls.temporary.name)
        cls.home = cls.root / "keyring"
        cls.home.mkdir(mode=0o700)
        cls.gpg = ["gpg", "--no-options", "--homedir", str(cls.home), "--batch",
                   "--pinentry-mode", "loopback", "--passphrase", ""]
        cls.addClassCleanup(lambda: subprocess.run(["gpgconf", "--homedir", str(cls.home),
                                                   "--kill", "gpg-agent"], capture_output=True))
        subprocess.run([*cls.gpg, "--quick-generate-key", "Harness Fixture <fixture@example.invalid>",
                        "ed25519", "sign", "0"], check=True, capture_output=True)
        listing = subprocess.run([*cls.gpg, "--with-colons", "--list-keys"],
                                 check=True, text=True, capture_output=True).stdout
        cls.fingerprint = next(line.split(":")[9] for line in listing.splitlines() if line.startswith("fpr:"))
        cls.fixture = cls.root / "fixture"
        cls.fixture.mkdir()
        (cls.fixture / "signing-key.asc").write_bytes(subprocess.run(
            [*cls.gpg, "--armor", "--export"], check=True, capture_output=True).stdout)
        (cls.fixture / "release.json").write_text(json.dumps({"arch": "amd64", "release": "1.2.3"}))
        (cls.fixture / "version.txt").write_text("FLATCAR_VERSION=1.2.3\n")
        for name in harness.OS_FILES:
            (cls.fixture / name).write_text("VM_BOARD='amd64-usr'\n" if name == harness.OS_FILES[0]
                                           else "signed boot fixture " + name)
            subprocess.run([*cls.gpg, "--detach-sign", "--output", str(cls.fixture / (name + ".sig")),
                            str(cls.fixture / name)], check=True, capture_output=True)

    def setUp(self):
        self.temporary = tempfile.TemporaryDirectory()
        self.addCleanup(self.temporary.cleanup)
        self.root = Path(self.temporary.name)
        self.cache, self.destination = self.root / "cache", self.root / "vm"
        self.cache.mkdir()
        self.destination.mkdir()
        self.key = patch.object(harness, "KEY_FINGERPRINT", self.fingerprint)
        self.key.start()
        self.addCleanup(self.key.stop)
        self.downloads = []

    def download(self, url, path):
        self.downloads.append(url)
        name = "signing-key.asc" if url == harness.KEY_URL else url.rsplit("/", 1)[1]
        shutil.copyfile(self.fixture / name, path)

    def prepare(self):
        with patch.object(harness, "download", self.download):
            harness.prepare_files("amd64", self.cache, self.destination)

    def test_verified_download_cache_reuse_and_copy(self):
        self.prepare()
        self.assertEqual(len(self.downloads), 10)
        self.assertTrue(all("/1.2.3/" in url for url in self.downloads[2:]))
        for name in harness.OS_FILES:
            self.assertEqual((self.destination / name).read_bytes(), (self.fixture / name).read_bytes())
        self.assertTrue((self.destination / harness.OS_FILES[0]).stat().st_mode & 0o111)
        with patch.object(harness, "download", side_effect=AssertionError("unexpected network access")):
            harness.prepare_files("amd64", self.cache, self.destination)
        self.assertFalse(list(self.cache.glob(".gpg-*")))

    def test_tampered_cache_is_replaced_once(self):
        self.prepare()
        (self.cache / "verified" / harness.OS_FILES[0]).write_text("tampered launcher")
        self.downloads.clear()
        self.prepare()
        self.assertEqual(len(self.downloads), 10)
        self.assertEqual((self.destination / harness.OS_FILES[0]).read_bytes(),
                         (self.fixture / harness.OS_FILES[0]).read_bytes())

    def test_unknown_key_missing_signature_and_tampering_fail_closed(self):
        for failure in ["unknown key", "missing signature", "tampered image"]:
            with self.subTest(failure=failure):
                def bad_download(url, path):
                    self.download(url, path)
                    if failure == "missing signature" and str(path).endswith(".sig"):
                        Path(path).unlink()
                    if failure == "tampered image" and Path(path).name == harness.OS_FILES[-1]:
                        Path(path).write_text("corrupt")
                fingerprint = "0" * 40 if failure == "unknown key" else self.fingerprint
                with patch.object(harness, "KEY_FINGERPRINT", fingerprint), patch.object(harness, "download", bad_download):
                    with self.assertRaises(ValueError):
                        harness.prepare_files("amd64", self.cache, self.destination)
                self.assertFalse((self.cache / "verified").exists())
                self.assertFalse(list(self.destination.iterdir()))
                self.assertFalse(list(self.cache.glob(".download-*")))

    def test_legacy_cache_cannot_bypass_signature_verification(self):
        for name in harness.OS_FILES:
            (self.cache / name).write_text("legacy unverified artifact")
        self.prepare()
        self.assertEqual(len(self.downloads), 10)
        self.assertNotIn("legacy", (self.destination / harness.OS_FILES[0]).read_text())

    def test_architecture_and_release_metadata_are_validated(self):
        bundle = self.cache / "verified"
        shutil.copytree(self.fixture, bundle)
        for metadata in [{"arch": "arm64", "release": "1.2.3"}, {"arch": "amd64", "release": "../current"}, []]:
            (bundle / "release.json").write_text(json.dumps(metadata))
            with self.assertRaises(ValueError):
                harness.verify_os(bundle, "amd64")

    def test_damaged_per_run_copy_is_never_launched(self):
        self.prepare()
        for path in self.destination.iterdir():
            path.unlink()
        copyfile = shutil.copyfile
        def corrupted_copy(source, destination, *args, **kwargs):
            result = copyfile(source, destination, *args, **kwargs)
            if Path(destination).name == harness.OS_FILES[0]:
                Path(destination).write_text("corrupted copy")
            return result
        with patch.object(harness.shutil, "copyfile", corrupted_copy):
            with self.assertRaisesRegex(ValueError, "signature verification failed"):
                harness.prepare_files("amd64", self.cache, self.destination)
        self.assertFalse(list(self.destination.iterdir()))


if __name__ == "__main__":
    unittest.main()
