# QEMU sysext

This sysext ships [QEMU](https://www.qemu.org/)'s `qemu-system-x86_64` so a
Flatcar host can run full virtual machines — for example as the backing
hypervisor for Nomad's `qemu` task driver.

QEMU has no upstream static/portable release, so the extension bundles the
`qemu-system-x86_64` binary with its full shared-library closure (including
glibc and the dynamic loader) plus firmware (SeaBIOS, iPXE option ROMs, OVMF),
extracted from a Debian container. A `/usr/bin/qemu-system-x86_64` wrapper runs
the binary through the bundled loader, isolating it from the host's libraries,
and points QEMU at the bundled firmware with `-L`. User-mode (SLIRP) networking
is included, so VMs get NAT egress with no host bridge setup.

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
        source: https://github.com/flatcar/sysext-bakery/releases/download/qemu/qemu.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/qemu/noop.conf
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
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C qemu update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/qemu.raw > /tmp/qemu-old"
            ExecStartPost=/usr/lib/systemd/systemd-sysupdate -C qemu update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/qemu.raw > /tmp/qemu-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/qemu-old /tmp/qemu-new; then touch /run/reboot-required; fi"
```
