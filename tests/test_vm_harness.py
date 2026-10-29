#!/usr/bin/env python3
"""Opt-in real amd64/KVM checks. Run only on a disposable Linux test host.

SYSEXT_VM_WORKDIR=/path/to/artifacts python3 tests/test_vm_harness.py
Requires Docker, QEMU/KVM, mksquashfs, curl, GPG, and outbound downloads.
"""

import contextlib
import hashlib
import json
import os
from pathlib import Path
import shutil
import signal
import socket
import subprocess
import tempfile
import time
import unittest

ROOT = Path(__file__).resolve().parents[1]


class FlatcarVM(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.base = Path(os.environ["SYSEXT_VM_WORKDIR"]).resolve()
        cls.base.mkdir(parents=True, exist_ok=True)
        cls.images = cls.base / "images"
        cls.logs = cls.base / "logs"
        cls.images.mkdir(exist_ok=True)
        cls.logs.mkdir(exist_ok=True)
        cls.resources = contextlib.ExitStack()
        cls.addClassCleanup(cls.resources.close)
        cls.recipes = []
        cls.records = []
        for marker in ["one", "two", "incompatible"]:
            directory = Path(cls.resources.enter_context(tempfile.TemporaryDirectory(
                prefix="harness-fixture-", suffix=".sysext", dir=ROOT)))
            cls.recipes.append(directory)
            name = directory.name.removesuffix(".sysext")
            root = Path(cls.resources.enter_context(tempfile.TemporaryDirectory(dir=cls.base)))
            release = root / "usr/lib/extension-release.d"
            release.mkdir(parents=True)
            (release / f"extension-release.{name}").write_text(
                f'ID={"incompatible" if marker == "incompatible" else "flatcar"}\n'
                'SYSEXT_LEVEL=1.0\nARCHITECTURE=x86-64\n')
            targets = root / "usr/share/harness"
            targets.mkdir(parents=True)
            (targets / marker).write_text(marker)
            subprocess.run(["mksquashfs", str(root), str(cls.images / (name + ".raw")),
                            "-all-root", "-noappend", "-quiet"], check=True, stdout=subprocess.DEVNULL)
            image = cls.images / (name + ".raw")
            (cls.images / ("SHA256SUMS." + name)).write_text(
                f"{hashlib.sha256(image.read_bytes()).hexdigest()}  {image.name}\n")
        cls.one, cls.two, cls.bad = [directory.name.removesuffix(".sysext") for directory in cls.recipes]
        (cls.images / "corrupt.raw").write_text("not an extension filesystem")

    @classmethod
    def tearDownClass(cls):
        (cls.logs / "results.json").write_text(json.dumps(cls.records, indent=2) + "\n")

    def setUp(self):
        for recipe in self.recipes:
            (recipe / "test.sh").unlink(missing_ok=True)
        self.temps = Path(tempfile.mkdtemp(prefix=self._testMethodName + "-", dir=self.base))
        self.addCleanup(self.check_cleanup)

    def check_cleanup(self):
        private_keys = list(self.temps.rglob("id_ed25519*"))
        self.assertFalse(private_keys, f"private keys retained: {private_keys}")
        self.assertFalse(list(self.temps.glob("*/artifacts")))
        self.assertFalse(list(self.temps.glob("*/vm")))
        for run in self.temps.iterdir():
            self.assertFalse([path for path in run.iterdir() if path.is_dir()],
                             f"unexpected temporary directories retained in {run}")
        supervisors = subprocess.run(["pgrep", "-af", "qemu-system|test_harness.py"], text=True,
                                     capture_output=True).stdout
        self.assertNotIn(str(self.temps), supervisors, supervisors)
        # Keep explicitly preserved diagnostics; remove an otherwise empty test root.
        if not any(self.temps.iterdir()):
            self.temps.rmdir()

    def command(self, *args):
        return [str(ROOT / "bakery.sh"), "test", "--timeout", "90", "--keep-vm", "true", *args]

    def invoke(self, *args, expected=0, environment=None):
        start = time.monotonic()
        result = subprocess.run(self.command(*args), cwd=self.images, text=True,
                                capture_output=True, env={**os.environ, "TMPDIR": str(self.temps),
                                                          **(environment or {})}, timeout=180)
        self.record(result, start)
        self.assertEqual(result.returncode, expected, result.stdout + result.stderr)
        if expected:
            self.assertNotIn("Test run finished: PASS", result.stdout)
        return result.stdout + result.stderr

    def record(self, result, start, suffix=""):
        name = self._testMethodName + suffix
        repeats = sum(record["case"].startswith(name) for record in self.records)
        if repeats:
            name += f"-{repeats + 1}"
        (self.logs / (name + ".log")).write_text(result.stdout + result.stderr)
        self.records.append({"case": name, "arguments": result.args[2:], "exit": result.returncode,
                             "seconds": round(time.monotonic() - start, 2)})

    def test_single_images_and_skipped_hooks(self):
        for name in [self.one, self.two]:
            output = self.invoke(name)
            self.assertIn("workflow tests SKIPPED", output)
            self.assertIn("merge-only coverage", output)

    def test_composition_and_marker_hooks(self):
        (self.recipes[0] / "test.sh").write_text('test "$(cat /usr/share/harness/one)" = one\n')
        (self.recipes[1] / "test.sh").write_text('test "$(cat /usr/share/harness/two)" = two\n')
        output = self.invoke(self.one, self.two, "--require-checksums", "true")
        self.assertEqual(output.count("recipe hook passed"), 2)
        self.assertNotIn("SKIPPED", output)
        self.assertEqual(output.count("Recorded checksum passed"), 2)

    def test_manifest_rejection_and_missing_checksum_fallback(self):
        manifest = self.images / ("SHA256SUMS." + self.one)
        original = manifest.read_text()
        try:
            manifest.write_text(f"{'0' * 64}  {self.one}.raw\n")
            output = self.invoke(self.one, expected=1)
            self.assertIn("checksum mismatch", output)
            self.assertNotIn("Booting", output)
            manifest.unlink()
            output = self.invoke(self.one, "--require-checksums", "true", expected=1)
            self.assertIn("No recorded checksum", output)
            self.assertNotIn("Booting", output)
            output = self.invoke(self.one)
            self.assertIn("No recorded checksum; delivery verification only", output)
        finally:
            manifest.write_text(original)

    def test_explicit_manifest_for_multiple_images(self):
        with tempfile.TemporaryDirectory(dir=self.base) as temp:
            manifest = Path(temp) / "custom SHA256SUMS"
            manifest.write_text("".join((self.images / ("SHA256SUMS." + name)).read_text()
                                        for name in (self.one, self.two)))
            output = self.invoke(self.one, self.two, "--checksums", str(manifest))
            self.assertEqual(output.count("Recorded checksum passed"), 2)

    def test_failing_hook(self):
        (self.recipes[0] / "test.sh").write_text('false\necho SHOULD_NOT_RUN\n')
        output = self.invoke(self.one, expected=1)
        self.assertIn("Recipe hook failed", output)
        self.assertNotIn("SHOULD_NOT_RUN", output)

    def test_hook_timeout(self):
        (self.recipes[0] / "test.sh").write_text('sleep 300\n')
        output = self.invoke(self.one, "--test-timeout", "2", expected=1)
        self.assertIn("timed out", output)

    def test_empty_and_comment_only_hooks(self):
        (self.recipes[0] / "test.sh").write_text('')
        (self.recipes[1] / "test.sh").write_text('#!/usr/bin/env bash\n# no tests yet\n')
        output = self.invoke(self.one, self.two)
        self.assertEqual(output.count("workflow tests SKIPPED"), 3)  # Two images and final coverage.

    def test_incompatible_and_corrupt_images(self):
        self.invoke(self.bad, expected=1)
        self.invoke("corrupt.raw", expected=1)

    def test_ssh_readiness_timeout(self):
        self.invoke(self.one, "--timeout", "1", expected=1)

    def test_occupied_explicit_ssh_port(self):
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            listener.listen()
            self.invoke(self.one, "--port", str(listener.getsockname()[1]), expected=1)

    def test_concurrent_runs(self):
        started = time.monotonic()
        processes = [subprocess.Popen(self.command(name), cwd=self.images, text=True,
                                      stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                                      env={**os.environ, "TMPDIR": str(self.temps)})
                     for name in [self.one, self.two]]
        try:
            for index, process in enumerate(processes):
                stdout, stderr = process.communicate(timeout=180)
                result = subprocess.CompletedProcess(process.args, process.returncode, stdout, stderr)
                self.record(result, started, f"-{index}")
                self.assertEqual(process.returncode, 0, stdout + stderr)
        finally:
            for process in processes:
                if process.poll() is None:
                    process.terminate()
                    process.communicate(timeout=30)

    def test_cancellation_during_boot_and_hook(self):
        for phase, sig in [("boot", signal.SIGTERM), ("hook", signal.SIGINT), ("hook", signal.SIGHUP)]:
            (self.recipes[0] / "test.sh").write_text('sleep 300\n')
            log = self.logs / f"cancel-{phase}-{sig}.log"
            started = time.monotonic()
            with log.open("w") as stream:
                process = subprocess.Popen(self.command(self.one), cwd=self.images,
                                           stdout=stream, stderr=subprocess.STDOUT,
                                           env={**os.environ, "TMPDIR": str(self.temps)})
                try:
                    deadline = time.monotonic() + 120
                    marker = "Booting amd64" if phase == "boot" else "Running recipe hook"
                    while marker not in log.read_text():
                        if process.poll() is not None or time.monotonic() > deadline:
                            self.fail("cancellation phase not reached: " + log.read_text())
                        time.sleep(0.1)
                    process.send_signal(sig)  # The CLI PID, not its process group.
                    process.wait(timeout=20)
                    self.assertEqual(process.returncode, 128 + sig, log.read_text())
                    self.assertNotIn("Test run finished: PASS", log.read_text())
                    self.records.append({"case": f"cancel-{phase}-{sig}", "exit": process.returncode,
                                         "seconds": round(time.monotonic() - started, 2)})
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.wait(timeout=20)

    def test_named_butane_container_is_removed(self):
        started = time.monotonic()
        name = "sysext-test-container-" + self.temps.name.lower()
        subprocess.run(["docker", "run", "--rm", "-di", "--name", name,
                        "quay.io/coreos/butane:latest"], check=True, stdout=subprocess.DEVNULL)
        try:
            result = subprocess.run(["bash", "-c",
                                     'source "$1/lib/test.sh"; _harness_butane_name="$2"; _cleanup_harness 143',
                                     "_", str(ROOT), name], text=True, capture_output=True, timeout=20)
            self.assertEqual(result.returncode, 143, result.stdout + result.stderr)
            remaining = subprocess.run(["docker", "ps", "-aq", "--filter", f"name=^/{name}$"],
                                       text=True, capture_output=True, check=True).stdout
            self.assertFalse(remaining.strip(), "Butane container survived cancellation cleanup")
            self.record(result, started)
        finally:
            subprocess.run(["docker", "rm", "-f", name], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

    def test_automatic_ssh_bind_collision_is_retried(self):
        with tempfile.TemporaryDirectory(dir=self.base) as temp:
            root = Path(temp)
            qemu = shutil.which("qemu-system-x86_64")
            wrapper = root / "qemu-system-x86_64"
            wrapper.write_text(f'''#!/usr/bin/python3
import os, re, socket, subprocess, sys
from pathlib import Path
marker = Path({str(root / "bound-once")!r})
if not marker.exists():
    netdev = sys.argv[sys.argv.index('-netdev') + 1]
    port = int(re.search(r'hostfwd=tcp:127.0.0.1:(\\d+)-:22', netdev).group(1))
    with socket.socket() as listener:
        listener.bind(('127.0.0.1', port))
        listener.listen()
        marker.touch()
        result = subprocess.run([{qemu!r}, *sys.argv[1:]])
    sys.exit(result.returncode)
os.execv({qemu!r}, [{qemu!r}, *sys.argv[1:]])
''')
            wrapper.chmod(0o755)
            output = self.invoke(self.one, environment={"PATH": temp + ":" + os.environ["PATH"]})
            self.assertEqual(output.count("Retrying automatic SSH port after bind failure"), 1)
            self.assertIn("attempt 2", output)

    def test_early_qemu_failure_is_not_retried_as_port_collision(self):
        with tempfile.TemporaryDirectory(dir=self.base) as temp:
            wrapper = Path(temp) / "qemu-system-x86_64"
            wrapper.write_text('#!/bin/sh\necho "forced early QEMU failure" >&2\nexit 2\n')
            wrapper.chmod(0o755)
            output = self.invoke(self.one, expected=1,
                                 environment={"PATH": temp + ":" + os.environ["PATH"]})
            self.assertIn("forced early QEMU failure", output)
            self.assertNotIn("Retrying automatic SSH port", output)


if __name__ == "__main__":
    if "SYSEXT_VM_WORKDIR" not in os.environ:
        raise SystemExit("Set SYSEXT_VM_WORKDIR to a scratch directory on a disposable Linux/KVM host.")
    unittest.main(verbosity=2)
