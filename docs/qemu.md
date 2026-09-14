# QEMU sysext

This sysext ships [QEMU](https://www.qemu.org/)'s `qemu-system-x86_64` so a
Flatcar host can run full virtual machines — for example as the backing
hypervisor for Nomad's `qemu` task driver.

QEMU has no upstream static/portable release, so the extension bundles the
`qemu-system-x86_64` binary with its full shared-library closure (including
glibc and the dynamic loader) plus firmware (SeaBIOS, iPXE option ROMs, OVMF),
extracted from a Debian container via `tools/flix.sh`. flix resolves the library
closure and patchelf's the binary onto a private loader and rpath, isolating it
from the host's libraries; QEMU finds the bundled firmware through its
compiled-in data directory. User-mode (SLIRP) networking is included, so VMs get
NAT egress with no host bridge setup.

Only `x86-64` is supported for now.

## Usage

Download and merge the sysext at provisioning time using the below butane
snippet. The snippet includes automated updates via systemd-sysupdate.

Note that the snippet is for the x86-64 version of qemu 10.0.11.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/qemu for a list of all
versions available in the bakery.

```yaml
variant: flatcar
version: 1.1.0
storage:
  files:
    - path: /opt/extensions/qemu/qemu-10.0.11-x86-64.raw
      contents:
        source: https://extensions.flatcar.org/extensions/qemu-10.0.11-x86-64.raw
    - path: /etc/sysupdate.qemu.d/qemu.conf
      contents:
        source: https://extensions.flatcar.org/extensions/qemu.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/qemu/qemu-10.0.11-x86-64.raw
      path: /etc/extensions/qemu.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: qemu.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/qemu.raw > /run/qemu"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C qemu update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/qemu.raw > /run/qemu-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/qemu /run/qemu-new; then touch /run/reboot-required; fi"
```
