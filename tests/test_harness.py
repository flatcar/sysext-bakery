#!/usr/bin/env python3
"""Run with python3 tests/test_harness.py; no VM or third-party packages needed."""

import json
import os
import pathlib
import signal
import socket
import subprocess
import tempfile
import time
import unittest
import urllib.error
import urllib.request

ROOT = pathlib.Path(__file__).resolve().parents[1]
HELPER = ROOT / "lib/test_harness.py"


def bash(script):
    with tempfile.TemporaryDirectory() as workspace:
        return subprocess.run(
            ["bash", "-c", f'source lib/test.sh; _harness_workdir="{workspace}"; ' + script],
            cwd=ROOT, text=True, capture_output=True, timeout=15,
        )


class HarnessChecks(unittest.TestCase):
    def test_active_service_does_not_prove_requested_merge(self):
        result = bash('''
          scriptroot="$PWD"
          _test_ssh() {
            case "$3" in
              *is-active*) return 0;;
              *sha256sum*) echo "unused  image.raw";;
              *status*json*) echo '[{"hierarchy":"/usr","extensions":["unrelated"]}]';;
              *) return 1;;
            esac
          }
          _run_sysext_checks unused 2222 /dev/null unused
        ''')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertIn("not confirmed merged", result.stdout)

    def test_comment_only_hook_is_not_reported_as_passed(self):
        result = bash('''
          scriptroot="$PWD"
          _test_ssh() {
            case "$3" in
              *is-active*) return 0;;
              *sha256sum*) python3 lib/test_harness.py checksum /dev/null;;
              *status*json*) echo '[{"hierarchy":"/usr","extensions":["scx"]}]';;
              *) cat >/dev/null; return 0;;
            esac
          }
          _run_sysext_checks unused 2222 scx.raw "$(python3 lib/test_harness.py checksum /dev/null)"
          _run_sysext_hook unused 2222 scx.raw 2
        ''')
        self.assertIn("SKIPPED", result.stdout)
        self.assertNotIn("Custom test passed", result.stdout)

    def test_term_is_not_success(self):
        result = bash('trap "_cleanup_harness 143" TERM; kill -TERM $$')
        self.assertNotEqual(result.returncode, 0, result.stdout)
        self.assertNotIn("PASS", result.stdout)

    def test_status_requires_exact_image_membership(self):
        for rows, expected in [
            ([{"hierarchy": "/usr", "extensions": ["one", "two"]}], 0),
            ([{"hierarchy": "/opt", "extensions": ["one"]}], 0),
            ([{"hierarchy": "/usr", "extensions": ["one-other"]}], 1),
            ([{"hierarchy": "/usr", "extensions": None}], 1),
            ([{"hierarchy": "/opt", "extensions": "none"},
              {"hierarchy": "/usr", "extensions": ["one"]}], 0),
            ([{"hierarchy": "/usr", "extensions": "one"}], 1),
            ([], 1), ({}, 1),
        ]:
            with self.subTest(rows=rows):
                result = subprocess.run(["python3", str(HELPER), "merged", "one"],
                                        input=json.dumps(rows), text=True, capture_output=True)
                self.assertEqual(result.returncode, expected)

    def test_checksum_mismatch_fails(self):
        result = bash('''
          _test_ssh() { echo 'different  file.raw'; }
          _run_sysext_checks unused 2222 one.raw expected
        ''')
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("checksum mismatch", result.stdout)

    def test_recipe_resolution_and_hook_detection(self):
        result = bash('''
          scriptroot="$PWD"
          [[ "$(_test_recipe docker-buildx-v0.20.1-x86-64)" == docker-buildx ]]
          [[ "$(_test_recipe wasmtime-37.0.0-arm64)" == wasmtime ]]
          [[ "$(_test_recipe wasmtime-custom)" == '' ]]
          [[ "$(_test_recipe wasmtime)" == wasmtime ]]
          ! _test_has_commands scx.sysext/test.sh
          ! _test_has_commands wasmtime.sysext/test.sh
          ! _test_has_commands does-not-exist
        ''')
        self.assertEqual(result.returncode, 0, result.stderr)

    def test_launcher_patch_changes_only_one_ssh_rule(self):
        with tempfile.TemporaryDirectory() as temp:
            path = pathlib.Path(temp) / "launcher"
            original = 'hostfwd=tcp::"${SSH_PORT}"-:22'
            path.write_text(original)
            result = subprocess.run(["python3", str(HELPER), "patch-launcher", str(path)], capture_output=True)
            self.assertEqual(result.returncode, 0)
            self.assertEqual(path.read_text(), 'hostfwd=tcp:127.0.0.1:"${SSH_PORT}"-:22')
            result = subprocess.run(["python3", str(HELPER), "patch-launcher", str(path)], capture_output=True)
            self.assertNotEqual(result.returncode, 0)

    def test_only_artifacts_are_served(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            (root / "one.raw").write_bytes(b"image")
            (root / "id_ed25519").write_bytes(b"secret")
            (root / "boot.json").write_bytes(b"config")
            (root / "link.raw").symlink_to(root / "id_ed25519")
            port_file = root / "port"
            process = subprocess.Popen(["python3", str(HELPER), "serve", temp, str(port_file)],
                                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
            try:
                wait_for(lambda: port_file.exists())
                port = int(port_file.read_text())
                base = f"http://127.0.0.1:{port}"
                with urllib.request.urlopen(base + "/one.raw") as response:
                    self.assertEqual(response.read(), b"image")
                (root / "later.raw").write_bytes(b"unlisted")
                for path in ["/", "/id_ed25519", "/boot.json", "/link.raw", "/later.raw",
                             "/../id_ed25519", "/%2e%2e/id_ed25519", "/%2fone.raw"]:
                    with self.subTest(path=path), self.assertRaises(urllib.error.HTTPError) as error:
                        urllib.request.urlopen(base + path)
                    self.assertEqual(error.exception.code, 404)
            finally:
                process.terminate()
                process.wait(timeout=5)
            with socket.socket() as listener:
                listener.setsockopt(socket.SOL_SOCKET, socket.SO_REUSEADDR, 1)
                listener.bind(("127.0.0.1", port))

    def test_timeout_and_signals_clean_descendants(self):
        for sig in [None, signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
            with self.subTest(signal=sig), tempfile.TemporaryDirectory() as temp:
                root = pathlib.Path(temp)
                child_file, ready = root / "child", root / "ready"
                command = f"sleep 300 & echo $! > '{child_file}'; wait"
                process = subprocess.Popen(["python3", str(HELPER), "run", "1" if sig is None else "0",
                                            str(ready), "bash", "-c", command],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
                try:
                    wait_for(lambda: child_file.exists() and ready.exists())
                    child = int(child_file.read_text())
                    if sig:
                        process.send_signal(sig)
                    process.communicate(timeout=8)
                    self.assertEqual(process.returncode, 128 + sig if sig else 124)
                    self.assertFalse(running(child), f"child {child} survived")
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.communicate(timeout=8)

    def test_invalid_arguments_fail_before_creating_workspace(self):
        for args in ["", "--arch invalid one.raw", "--port 0 one.raw", "--port 99999 one.raw",
                     "--timeout 0 one.raw", "--test-timeout nope one.raw", "--timeout",
                     "--keep-vm maybe one.raw", "--require-checksums maybe one.raw",
                     "--checksums", "--checksums '' one.raw", "--unknown value", "missing.raw"]:
            with self.subTest(args=args):
                result = bash('mktemp() { echo UNEXPECTED_WORKSPACE; return 1; }; test_sysext ' + args)
                self.assertNotEqual(result.returncode, 0)
                self.assertNotIn("UNEXPECTED_WORKSPACE", result.stdout)

    def test_aliases_duplicate_names_and_space_in_directory(self):
        with tempfile.TemporaryDirectory(prefix="harness tests ") as temp:
            root = pathlib.Path(temp)
            (root / "one.raw").write_text("image")
            result = bash(f'''cd '{temp}';
              test_sysext one.raw '{temp}/one.raw'
            ''')
            self.assertNotEqual(result.returncode, 0)
            self.assertIn("Duplicate image basename", result.stdout)
            for alias in ["one", "one.sysext", "one.raw"]:
                result = bash(f'''cd '{temp}';
                  command() {{ return 1; }}
                  test_sysext {alias}
                ''')
                self.assertIn("Missing prerequisite", result.stdout)
                self.assertNotIn("Expected an existing", result.stdout)

    def test_preserved_failure_has_no_keys_or_vm_files(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp) / "run"
            for directory in ["identity", "artifacts", "vm"]:
                (root / directory).mkdir(parents=True)
                (root / directory / "private").write_text("secret")
            (root / "qemu.log").write_text("diagnostic")
            result = bash(f'''_harness_workdir='{root}'; _harness_keep_vm=true;
                              _cleanup_harness 143''')
            self.assertEqual(result.returncode, 143)
            self.assertEqual(list(root.iterdir()), [root / "qemu.log"])

    def test_cleanup_failure_cannot_report_pass(self):
        result = bash('''
          _harness_complete=true
          _harness_coverage=checked
          rm() { return 1; }
          _cleanup_harness 0
        ''')
        self.assertNotEqual(result.returncode, 0)
        self.assertNotIn("PASS", result.stdout)
        self.assertIn("Cleanup did not complete", result.stdout)

    def test_recipe_hook_success_failure_and_timeout(self):
        for hook, succeeds in [("echo checked\n", True), ("false\necho UNREACHABLE\n", False),
                               ("sleep 30\n", False)]:
            with self.subTest(hook=hook), tempfile.TemporaryDirectory() as temp:
                root = pathlib.Path(temp)
                (root / "one.sysext").mkdir()
                (root / "one.sysext/test.sh").write_text(hook)
                result = bash(f'''
                  scriptroot='{root}'
                  _test_ssh() {{ _test_run "$4" bash -euo pipefail -s; }}
                  _run_sysext_hook unused 2222 one.raw 1
                ''')
                self.assertEqual(result.returncode == 0, succeeds, result.stdout + result.stderr)
                self.assertNotIn("UNREACHABLE", result.stdout)

    def test_cancelling_foreground_work_cleans_its_children(self):
        for sig in [signal.SIGINT, signal.SIGTERM, signal.SIGHUP]:
            with self.subTest(signal=sig), tempfile.TemporaryDirectory() as temp:
                root = pathlib.Path(temp)
                child_file = root / "child"
                process = subprocess.Popen(["bash", "-c", f'''
                  source lib/test.sh
                  trap '_cleanup_harness 130' INT
                  trap '_cleanup_harness 143' TERM
                  trap '_cleanup_harness 129' HUP
                  _test_run 300 bash -c 'sleep 300 & echo $! > "{child_file}"; wait'
                '''], cwd=ROOT, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
                try:
                    wait_for(lambda: child_file.exists())
                    child = int(child_file.read_text())
                    process.send_signal(sig)
                    stdout, stderr = process.communicate(timeout=10)
                    self.assertEqual(process.returncode, 128 + sig, stdout + stderr)
                    self.assertNotIn("PASS", stdout)
                    self.assertFalse(running(child))
                finally:
                    if process.poll() is None:
                        process.terminate()
                        process.communicate(timeout=10)

    def test_server_failure_does_not_publish_readiness(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            result = subprocess.run(["python3", str(HELPER), "serve", str(root / "missing"),
                                     str(root / "ready")], capture_output=True)
            self.assertNotEqual(result.returncode, 0)
            self.assertFalse((root / "ready").exists())

    def test_cleanup_handles_child_not_yet_recorded(self):
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            ready = root / "ready"
            result = bash(f'''
              python3 "${{_test_helper}}" run 0 '{ready}' sleep 300 >/dev/null 2>&1 &
              while [[ ! -s '{ready}' ]]; do sleep 0.02; done
              _cleanup_harness 143
            ''')
            child = int(ready.read_text())
            try:
                self.assertEqual(result.returncode, 143)
                self.assertFalse(running(child))
            finally:
                if running(child):
                    os.killpg(child, signal.SIGKILL)

    def test_cancellation_while_waiting_for_cache_lock(self):
        import fcntl
        with tempfile.TemporaryDirectory() as temp:
            root = pathlib.Path(temp)
            with (root / ".lock").open("w") as lock:
                fcntl.flock(lock, fcntl.LOCK_EX)
                process = subprocess.Popen(["python3", str(HELPER), "prepare", "amd64", temp, temp],
                                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
                try:
                    time.sleep(0.2)
                    process.terminate()
                    process.wait(timeout=5)
                    self.assertEqual(process.returncode, 143)
                finally:
                    if process.poll() is None:
                        process.kill()
                        process.wait()


def wait_for(predicate):
    deadline = time.monotonic() + 5
    while not predicate():
        if time.monotonic() > deadline:
            raise AssertionError("process readiness timed out")
        time.sleep(0.02)


def running(pid):
    # A terminated orphan can briefly remain a zombie awaiting the host's init.
    stat = pathlib.Path(f"/proc/{pid}/stat")
    if stat.exists():
        return stat.read_text().split(")", 1)[1].split()[0] != "Z"
    try:
        os.kill(pid, 0)
        return True
    except ProcessLookupError:
        return False


if __name__ == "__main__":
    unittest.main()
