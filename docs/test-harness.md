# Testing extension images

Build an image, then test it in a disposable Flatcar QEMU guest:

```sh
./bakery.sh create wasmtime v37.0.0
./bakery.sh test wasmtime
./bakery.sh test /path/to/wasmtime.raw /path/to/tailscale.raw
```

`test` takes existing image files or names resolving to `<name>.raw`; it does
not build images or accept a positional version. Directories may contain
spaces. Image basenames must contain only letters, digits, `.`, `_`, `+`, and
`-`, start with a letter or digit, and end in `.raw`. Duplicate basenames are
rejected because they would overwrite the same provisioned image.

## Coverage and recipe hooks

Before starting runtime resources, the harness verifies its private copy of
each extension against recorded SHA-256 checksums. It looks beside the source
image for `SHA256SUMS`, `SHA256SUMS.<recipe>`, and `SHA256SUMS.<image-stem>`
(duplicates in this list are ignored). Bakery generates the recipe file during
image creation and publishes `SHA256SUMS` with releases. Download that manifest
alongside released images; the harness does not download extension images or
their manifests automatically.

```sh
./bakery.sh test wasmtime --require-checksums true
./bakery.sh test one.raw two.raw --checksums /path/to/SHA256SUMS
```

`--checksums <file>` exclusively selects one manifest and requires an entry
for every requested image. Otherwise, `--require-checksums true` requires a
matching record in the automatically discovered files. The default is `false`:
an image without a matching record uses a local digest and explicitly reports
**No recorded checksum; delivery verification only**. This flexible default
is provisional pending maintainer feedback. Missing records never conceal
malformed/unreadable manifests, duplicate matching entries, conflicting hashes,
or image corruption: those failures stop the run.

Manifest records use the usual `sha256sum` text or binary format. Blank lines
and `#` comments are permitted. Matching uses the exact image basename,
including for Bakery records with directory prefixes; those recorded paths
are never opened. Two matching records in one file are ambiguous and rejected.
An unsigned checksum manifest establishes agreement with its recorded digest,
not authenticated publisher provenance.

The harness compares each guest image's SHA-256 with the retained expected digest,
checks `systemd-sysext.service`, and confirms each requested extension is
listed in a merged `/usr` or `/opt` hierarchy. An active service alone does
not establish that an image merged. Every image must pass these checks before
any recipe hook runs.

If `<recipe>.sysext/test.sh` contains commands, the harness streams it to
`bash -euo pipefail -s` over SSH. Hooks run sequentially as the guest's `core`
user; use noninteractive guest `sudo` when a check requires privileges. They
must be self-contained: host build functions and files are not transferred.
Any failure or timeout fails the run. A hook may intentionally change shell
options; its author is responsible for making failed checks exit nonzero.

Exact recipe names and Bakery filenames such as
`wasmtime-v37.0.0-x86-64.raw` resolve to the matching recipe. Unrecognized
filenames receive generic checks without a recipe hook. The harness does not
source recipe build scripts or guess executables from image names.

Missing, empty, and comment-only hooks are explicitly **SKIPPED**. A successful
run with skipped hooks states **merge-only coverage**: it does not establish
binary compatibility, service health, application workflows, or absence of
file collisions. A command-bearing hook returning zero is reported as a
passed recipe hook; the harness cannot determine whether its assertions are
sufficient. This foundation adds no application-specific recipe tests.

## Options and host requirements

```sh
./bakery.sh test wasmtime --arch amd64 --timeout 120 --test-timeout 60
./bakery.sh test wasmtime --port 22222 --keep-vm true
./bakery.sh test help
```

The default architecture is `amd64` (`x86-64` is an alias); `arm64` is also
accepted. Native KVM is recommended on Linux. Software emulation may require
a longer boot timeout. Real VM verification currently covers amd64 on Linux;
macOS and arm64 are not claimed as verified.

Prerequisites are Bash, Python 3, OpenSSH clients, `curl`, GnuPG (`gpg`), Docker with access to
its daemon, and the matching QEMU emulator. The harness does not invoke host
`sudo`. Image building has its own prerequisites listed in the main README.

Both HTTP and SSH listeners bind to loopback. HTTP obtains a bound ephemeral
port; SSH allocation is a probe followed by a QEMU bind, with up to three
attempts on an identified bind failure. Explicit occupied SSH ports fail.
The default SSH readiness deadline and per-hook timeout are each 90 seconds.
Configuration conversion and image preparation also have bounded execution.

Flatcar images are cached under `.cache/sysext-test/<arch>/verified/` in the
working directory. On a cold cache, the harness resolves alpha `current` once
using `version.txt`, then downloads the launcher, firmware code, firmware
variables, and disk image with their detached `.sig` files from the numbered
release. Every artifact must pass GPG verification before cache publication
and use. The signed launcher's architecture must also match the requested one.

The public key comes from Flatcar's [official verification workflow](https://www.flatcar.org/docs/latest/updates-releases/releases/verify-images/).
Its primary fingerprint must be
`F88CFEDEFF29A5B4D9523864E25D9AED0593B34A`, as recorded in
[Flatcar's installer](https://github.com/flatcar/init/blob/flatcar-master/bin/flatcar-install).
Valid signing subkeys under that primary key are accepted. Verification uses
an isolated temporary keyring, without modifying your personal GPG settings
or starting an agent. A changed primary key requires a reviewed code update;
missing/invalid signatures never fall back to unsigned boot files.

Downloads and copies are locked for concurrent runs. Cached signatures are
rechecked on every use, and per-run copies are checked before the temporary
launcher is patched for loopback SSH. Legacy unsigned caches are replaced.
A rejected cache triggers one fresh download attempt; an invalid replacement
fails. Interrupted preparation removes task-owned staging directories.
Verified cache bundles persist intentionally and can be deleted when no longer
needed. Warm runs reuse the cached release and public key without network
access; delete the cache to refresh the release and key. Guest disk changes
are temporary snapshots.

Only requested `.raw` artifacts are served. Credentials and Ignition configs
are outside the HTTP directory. SSH ignores personal client configuration and
does not update personal known-host files. Private keys are deleted on all
handled exits. With `--keep-vm true`, failures retain diagnostic logs and small
status files, but no credentials, provisioned images, or VM disks. Despite the
legacy option name, it preserves diagnostics rather than a running VM.

PASS appears only after checks and cleanup finish. Failures exit nonzero;
INT, TERM, and HUP exit with 130, 143, and 129. Cleanup stops the launcher,
QEMU descendants, command descendants, HTTP server, and any named Butane
container. Uncatchable termination such as SIGKILL or host power loss cannot
run shell cleanup.

## Verifying harness changes

Run the focused regression suite without a VM or third-party Python packages:

```sh
python3 tests/test_harness.py
python3 tests/test_checksums.py
```

On a disposable Linux amd64/KVM host, run the real CLI suite:

```sh
SYSEXT_VM_WORKDIR=/path/to/scratch python3 tests/test_vm_harness.py
```

The checksum suite exercises signed-artifact verification with temporary test
keys when GPG is available; those cases skip when it is absent. Run it on the
Linux test host for complete verification. The real suite also needs
`mksquashfs`, outbound downloads, and enough memory
for two 2 GiB guests. It builds temporary fixture images and hooks, tests
individual and combined merges, failures, timeouts, cancellation, occupied
ports, and concurrent runs. It removes temporary recipe directories and
keeps fixture images, cached OS files, and logs under the supplied scratch
directory for inspection. `logs/results.json` records exit codes and timings.

Static ELF audits, application-specific recipe suites, collision detection,
and CI/release integration remain separate follow-up work.
