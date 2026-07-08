# bcachefs-kmod sysext

This sysext ships a prebuilt `bcachefs.ko` — the [bcachefs](https://bcachefs.org/) filesystem kernel module — for a **specific Flatcar release's kernel**. It is the companion to the [`bcachefs-tools`](bcachefs-tools.md) userspace sysext.

bcachefs was mainlined in Linux 6.7 and subsequently [removed from mainline in Linux 6.18](https://lwn.net/Articles/1040120/) (September 2025). Kent Overstreet now ships it as an out-of-tree DKMS module maintained inside [`koverstreet/bcachefs-tools`](https://github.com/koverstreet/bcachefs-tools) under `dkms/`. That makes this sysext **required** on every Flatcar release if you want to actually use bcachefs — the `bcachefs-tools` sysext alone only gives you the userspace utilities, not a working filesystem.

The current DKMS harness requires **Linux ≥ 6.16** (`BUILD_EXCLUSIVE_KERNEL_MIN` in `dkms.conf.in`). Older Flatcar releases (e.g., anything still on the 6.6 LTS kernel) can't be targeted.

Only `--arch x86-64` is supported today: the `flatcar-sdk-all` container is amd64-only, and driving the SDK's board machinery to cross-compile an arm64 module hasn't been wired up yet.

> **Warning — on-disk format stability.** bcachefs is still pre-1.0. Pin a known-good `bcachefs-tools` version against a known-good kernel before putting data you care about on it.

## Two-axis versioning

Unlike other bakery sysexts, a single build of `bcachefs-kmod` is pinned to **two** dimensions:

1. The **bcachefs revision** (a `koverstreet/bcachefs-tools` tag such as `v1.25.2`).
2. The **Flatcar release** whose kernel the `.ko` is built against (e.g. `4230.2.0`).

Because the resulting `.ko` will only load on the exact matching kernel, this sysext is **not part of the bakery's automated release matrix and is not eligible for `systemd-sysupdate` auto-updates.** Sysext filenames encode both axes:

```
bcachefs-kmod-<bcachefs-tag>-flatcar-<release>-<arch>.raw
```

A kernel bump on the host (any Flatcar upgrade) requires rebuilding the sysext against the new release.

## Building

Build against a specific Flatcar release:

```sh
./bakery.sh create bcachefs-kmod v1.25.2 --flatcar-release 4230.2.0
```

Or track a channel's current tip:

```sh
./bakery.sh create bcachefs-kmod v1.25.2 --flatcar-release stable
./bakery.sh create bcachefs-kmod v1.25.2 --flatcar-release lts
```

`--flatcar-release` accepts either a release version (e.g. `4230.2.0`) or a channel name (`alpha`, `beta`, `stable`, `lts`) — channel names resolve to that channel's current release at build time.

Under the hood the build:

1. Pulls Flatcar's own SDK container `ghcr.io/flatcar/flatcar-sdk-all:<flatcar-release>`, which ships the exact kernel source Flatcar was built with.
2. `emerge`s `sys-kernel/coreos-modules` inside the SDK; that pulls `coreos-sources` as a dependency, drops Flatcar's kernel source at `/usr/src/linux-<kver>-flatcar`, and runs `modules_prepare` so the tree is build-usable.
3. Clones `koverstreet/bcachefs-tools` at the requested tag and runs its `dkms/Makefile` (`make -C .../dkms KDIR=/usr/src/linux`), the same harness Arch, Debian/Ubuntu, and NixOS drive.
4. Installs the resulting `bcachefs.ko` to `/usr/lib/modules/<kver>-flatcar/updates/` with `depmod` metadata and a `modules-load.d` entry so the module loads on boot.

## Usage

Provision the sysext with a Butane snippet. The example pins `bcachefs-tools` v1.25.2 built against Flatcar 4230.2.0, x86-64. Substitute values to match your host.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/bcachefs-kmod/bcachefs-kmod-v1.25.2-flatcar-4230.2.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/bcachefs-kmod-v1.25.2-flatcar-4230.2.0-x86-64.raw
  links:
    - target: /opt/extensions/bcachefs-kmod/bcachefs-kmod-v1.25.2-flatcar-4230.2.0-x86-64.raw
      path: /etc/extensions/bcachefs-kmod.raw
      hard: false
```

Note the absence of `systemd-sysupdate` wiring — see above.

Typically you will provision `bcachefs-kmod` together with `bcachefs-tools`. See [`bcachefs-tools`](bcachefs-tools.md) for the userspace side.

## Smoke test

After provisioning, verify the module is loaded and the filesystem is available:

```sh
uname -r                              # confirm the host kernel matches
modprobe bcachefs
grep bcachefs /proc/filesystems
bcachefs version
```

If `modprobe` fails with `Exec format error` or `unknown symbol`, the sysext was built against a different Flatcar release than the one running on the host. Rebuild against the release reported by `/etc/os-release`.
