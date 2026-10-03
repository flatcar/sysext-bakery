#!/usr/bin/env python3
"""Small standard-library helpers for the Bash test harness (POSIX hosts)."""

import hashlib
import fcntl
import http.server
import json
import os
from pathlib import Path
import re
import shutil
import signal
import socket
import subprocess
import sys
import tempfile
import time
import urllib.parse


def checksum(path):
    digest = hashlib.sha256()
    with open(path, "rb") as image:
        for chunk in iter(lambda: image.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def expected_checksum(image, recipe, explicit, required):
    image = Path(image)
    manifests = [Path(explicit)] if explicit else [image.parent / "SHA256SUMS"]
    if not explicit:
        for name in dict.fromkeys(filter(None, (recipe, image.stem))):
            manifests.append(image.parent / ("SHA256SUMS." + name))
    matches = []
    for manifest in manifests:
        if not explicit and not manifest.exists() and not manifest.is_symlink():
            continue
        found = []
        with manifest.open() as records:
            for number, line in enumerate(records, 1):
                if not line.strip() or line.startswith("#"):
                    continue
                record = re.fullmatch(r"([0-9a-fA-F]{64}) [ *](.+)\n?", line)
                if not record:
                    raise ValueError(f"Malformed checksum record: {manifest}:{number}")
                if Path(record[2]).name == image.name:
                    found.append(record[1].lower())
        if len(found) > 1:
            raise ValueError(f"Duplicate checksum records for {image.name}: {manifest}")
        if found:
            matches.append((found[0], str(manifest)))
    if len({digest for digest, _ in matches}) > 1:
        raise ValueError(f"Conflicting checksum records for {image.name}")
    if matches:
        return matches[0]
    if required or explicit:
        raise ValueError(f"No recorded checksum for {image.name}")
    return checksum(image), "local fallback"


def verify_artifact(image, recipe, explicit, required, source=None):
    expected, provenance = expected_checksum(source or image, recipe, explicit, required)
    if checksum(image) != expected:
        raise ValueError(f"Extension checksum mismatch: {Path(image).name}")
    if provenance == "local fallback":
        print(f"{Path(image).name}: No recorded checksum; delivery verification only.", file=sys.stderr)
    else:
        print(f"{Path(image).name}: Recorded checksum passed ({provenance})", file=sys.stderr)
    return expected


def merged(name):
    rows = json.load(sys.stdin)
    if not isinstance(rows, list) or not rows:
        raise ValueError("invalid sysext status")
    found = False
    for row in rows:
        if not isinstance(row, dict) or row.get("hierarchy") not in ("/usr", "/opt"):
            raise ValueError("invalid sysext hierarchy")
        extensions = row.get("extensions")
        if extensions is None or extensions == "none":
            extensions = []
        if not isinstance(extensions, list) or any(not isinstance(e, str) for e in extensions):
            raise ValueError("invalid sysext extensions")
        found |= name in extensions
    return 0 if found else 1


def serve(directory, port_file):
    root = Path(directory).resolve()
    allowed = {p.name for p in root.iterdir() if p.is_file() and not p.is_symlink() and p.suffix == ".raw"}

    class Artifacts(http.server.SimpleHTTPRequestHandler):
        def __init__(self, *args, **kwargs):
            super().__init__(*args, directory=str(root), **kwargs)

        def send_head(self):
            path = urllib.parse.unquote(urllib.parse.urlsplit(self.path).path)
            if path not in {"/" + name for name in allowed}:
                self.send_error(404)
                return None
            return super().send_head()

    with http.server.HTTPServer(("127.0.0.1", 0), Artifacts) as server:
        Path(port_file).write_text(str(server.server_port))
        server.serve_forever()


def stop_group(process):
    # The launcher can exit before QEMU or a hook's descendants do.
    for sig in (signal.SIGTERM, signal.SIGKILL):
        try:
            os.killpg(process.pid, sig)
        except ProcessLookupError:
            break
        if sig == signal.SIGTERM:
            deadline = time.monotonic() + 3
            while time.monotonic() < deadline:
                process.poll()  # Reap the direct child while checking its group.
                try:
                    os.killpg(process.pid, 0)
                except ProcessLookupError:
                    break
                time.sleep(0.05)
    process.wait()


def run(seconds, ready_file, command):
    process = None

    def cancelled(signum, _frame):
        raise SystemExit(128 + signum)

    # Block cancellation across Popen so cleanup cannot lose a newly created child.
    signals = {signal.SIGINT, signal.SIGTERM, signal.SIGHUP}
    old_mask = signal.pthread_sigmask(signal.SIG_BLOCK, signals)
    try:
        for sig in signals:
            signal.signal(sig, cancelled)
        process = subprocess.Popen(command, start_new_session=True)
        if ready_file != "-":
            Path(ready_file).write_text(str(process.pid))
        signal.pthread_sigmask(signal.SIG_SETMASK, old_mask)
        try:
            status = process.wait(timeout=float(seconds) if float(seconds) else None)
            return status if status >= 0 else 128 - status
        except subprocess.TimeoutExpired:
            print("ERROR: Command timed out.", file=sys.stderr)
            return 124
    finally:
        for sig in signals:
            signal.signal(sig, signal.SIG_IGN)
        signal.pthread_sigmask(signal.SIG_SETMASK, old_mask)
        if process is not None:
            stop_group(process)


def patch_launcher(path):
    launcher = Path(path)
    text = launcher.read_text()
    old = 'hostfwd=tcp::"${SSH_PORT}"-:22'
    if text.count(old) != 1:
        raise ValueError("unsupported Flatcar launcher SSH rule; refusing an unverified listener")
    launcher.write_text(text.replace(old, 'hostfwd=tcp:127.0.0.1:"${SSH_PORT}"-:22'))


OS_FILES = ("flatcar_production_qemu_uefi.sh", "flatcar_production_qemu_uefi_efi_code.qcow2",
            "flatcar_production_qemu_uefi_efi_vars.qcow2", "flatcar_production_qemu_uefi_image.img")
OS_ROOT = "https://alpha.release.flatcar-linux.net"
KEY_URL = "https://www.flatcar.org/security/image-signing-key/Flatcar_Image_Signing_Key.asc"
KEY_FINGERPRINT = "F88CFEDEFF29A5B4D9523864E25D9AED0593B34A"


def download(url, path):
    subprocess.run(["curl", "-fLsS", "--proto", "=https", "--proto-redir", "=https",
                    "--retry", "3", "--connect-timeout", "15", "--max-time", "300",
                    "-o", str(path), url], check=True)


def verify_os(bundle, arch):
    bundle = Path(bundle)
    metadata = json.loads((bundle / "release.json").read_text())
    if (not isinstance(metadata, dict) or metadata.get("arch") != arch
            or not isinstance(metadata.get("release"), str)
            or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", metadata["release"])):
        raise ValueError("Invalid Flatcar cache release metadata")
    with tempfile.TemporaryDirectory(prefix=".gpg-", dir=bundle.parent) as keyring:
        gpg = ["gpg", "--no-options", "--homedir", keyring, "--batch", "--no-autostart",
               "--no-auto-key-retrieve", "--no-auto-check-trustdb"]
        subprocess.run([*gpg, "--import", str(bundle / "signing-key.asc")],
                       check=True, stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
        listing = subprocess.run([*gpg, "--with-colons", "--list-keys"],
                                 check=True, text=True, capture_output=True).stdout.splitlines()
        primary = []
        for index, line in enumerate(listing):
            if line.startswith("pub:"):
                primary.append(listing[index + 1].split(":")[9])
        if primary != [KEY_FINGERPRINT]:
            raise ValueError("Unexpected Flatcar signing-key fingerprint")
        for name in OS_FILES:
            result = subprocess.run([*gpg, "--status-fd", "1", "--verify",
                                     str(bundle / (name + ".sig")), str(bundle / name)],
                                    text=True, capture_output=True)
            valid = [line.split() for line in result.stdout.splitlines()
                     if line.startswith("[GNUPG:] VALIDSIG ")]
            if result.returncode or len(valid) != 1 or valid[0][-1] != KEY_FINGERPRINT:
                raise ValueError(f"Flatcar signature verification failed: {name}\n{result.stderr.strip()}")
    boards = re.findall(r"^VM_BOARD='(amd64|arm64)-usr'$", (bundle / OS_FILES[0]).read_text(), re.MULTILINE)
    if boards != [arch]:
        raise ValueError("Signed Flatcar launcher architecture does not match requested architecture")
    return metadata["release"]


def prepare_files(arch, cache, destination):
    cache, destination = Path(cache), Path(destination)
    bundle = cache / "verified"
    release = None
    if bundle.exists():
        try:
            release = verify_os(bundle, arch)
        except (OSError, ValueError, subprocess.CalledProcessError) as error:
            print(f"Flatcar cache rejected; downloading a fresh verified bundle: {error}", flush=True)
    if release is None:
        with tempfile.TemporaryDirectory(prefix=".download-", dir=cache) as temporary:
            stage = Path(temporary)
            download(f"{OS_ROOT}/{arch}-usr/current/version.txt", stage / "version.txt")
            versions = re.findall(r"^FLATCAR_VERSION=([0-9]+\.[0-9]+\.[0-9]+)$",
                                  (stage / "version.txt").read_text(), re.MULTILINE)
            if len(versions) != 1:
                raise ValueError("Invalid Flatcar version.txt")
            release = versions[0]
            print(f"Downloading Flatcar {release} ({arch}) and verifying official signatures", flush=True)
            download(KEY_URL, stage / "signing-key.asc")
            (stage / "release.json").write_text(json.dumps({"arch": arch, "release": release}) + "\n")
            for name in OS_FILES:
                for artifact in (name, name + ".sig"):
                    download(f"{OS_ROOT}/{arch}-usr/{release}/{artifact}", stage / artifact)
            verify_os(stage, arch)
            if bundle.exists():
                shutil.rmtree(bundle)
            os.replace(stage, bundle)
            for name in OS_FILES:
                (cache / name).unlink(missing_ok=True)
    # Verify the actual per-run copies, including the executable launcher.
    with tempfile.TemporaryDirectory(prefix=".download-", dir=cache) as temporary:
        copied = Path(temporary)
        for name in (*OS_FILES, *(name + ".sig" for name in OS_FILES), "signing-key.asc", "release.json"):
            shutil.copyfile(bundle / name, copied / name)
        verify_os(copied, arch)
        for name in OS_FILES:
            shutil.move(str(copied / name), destination / name)
    (destination / OS_FILES[0]).chmod(0o755)
    print(f"Flatcar {release}: all four boot-artifact signatures verified", flush=True)


def prepare(arch, cache, destination):
    """Serialize downloads and copies so concurrent runs never see partial images."""
    Path(cache).mkdir(parents=True, exist_ok=True)
    for sig in (signal.SIGINT, signal.SIGTERM, signal.SIGHUP):
        signal.signal(sig, lambda number, _frame: sys.exit(128 + number))
    with open(Path(cache) / ".lock", "a") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        try:
            return run(600, "-", [sys.executable, str(Path(__file__).resolve()),
                                 "prepare-files", arch, cache, destination])
        finally:
            for pattern in (".download-*", ".gpg-*"):
                for path in Path(cache).glob(pattern):
                    shutil.rmtree(path)


def main():
    mode, *args = sys.argv[1:]
    if mode == "checksum":
        print(checksum(args[0]))
    elif mode == "verify-artifact":
        image, recipe, explicit, required, source = args
        print(verify_artifact(image, recipe, explicit, required == "true", source))
    elif mode == "merged":
        return merged(args[0])
    elif mode == "serve":
        serve(*args)
    elif mode == "run":
        return run(args[0], args[1], args[2:])
    elif mode == "patch-launcher":
        patch_launcher(args[0])
    elif mode == "prepare":
        return prepare(*args)
    elif mode == "prepare-files":
        prepare_files(*args)
    elif mode == "port":
        with socket.socket() as listener:
            listener.bind(("127.0.0.1", 0))
            print(listener.getsockname()[1])
    else:
        raise ValueError("unknown harness operation")
    return 0


if __name__ == "__main__":
    try:
        sys.exit(main())
    except (OSError, ValueError, KeyError, IndexError, subprocess.CalledProcessError) as error:
        print(f"ERROR: {error}", file=sys.stderr)
        sys.exit(1)
