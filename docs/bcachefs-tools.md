# bcachefs-tools sysext

This sysext ships the [bcachefs userspace utilities](https://github.com/koverstreet/bcachefs-tools):

- `bcachefs` — the unified CLI (subcommand-based: `bcachefs format`, `bcachefs fsck`, `bcachefs mount`, ...).
- `mkfs.bcachefs`, `fsck.bcachefs`, `mount.bcachefs`, `dump.bcachefs` — argv[0] dispatchers to the unified CLI, so `/usr/bin/mount` automatically picks `mount.bcachefs` up for `-t bcachefs`.

bcachefs is out-of-tree only, so on its own this sysext is not enough to actually use bcachefs — you also need the `bcachefs-kmod` sysext, which ships a prebuilt `bcachefs.ko` for a specific Flatcar release's kernel.

> **Warning — on-disk format stability.** bcachefs is still pre-1.0 from an on-disk-format perspective. Pin a known-good `bcachefs-tools` version against a known-good kernel before putting data you care about on it.

## Usage

Download and merge the sysext at provisioning time using the Butane snippet below. The snippet pins `bcachefs-tools` v1.25.2 for x86-64; substitute the version and arch you want.

See the [bcachefs-tools release page](https://github.com/flatcar/sysext-bakery/releases/tag/bcachefs-tools) for all versions available.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/bcachefs-tools/bcachefs-tools-v1.25.2-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/bcachefs-tools-v1.25.2-x86-64.raw
    - path: /etc/sysupdate.bcachefs-tools.d/bcachefs-tools.conf
      contents:
        source: https://extensions.flatcar.org/extensions/bcachefs-tools.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/bcachefs-tools/bcachefs-tools-v1.25.2-x86-64.raw
      path: /etc/extensions/bcachefs-tools.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: bcachefs-tools.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bcachefs-tools.raw > /tmp/bcachefs-tools"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C bcachefs-tools update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bcachefs-tools.raw > /tmp/bcachefs-tools-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/bcachefs-tools /tmp/bcachefs-tools-new; then touch /run/reboot-required; fi"
```

## Smoke test

After provisioning, verify the tools are merged and the kernel module is available:

```sh
bcachefs version
modprobe bcachefs && grep bcachefs /proc/filesystems
mkfs.bcachefs /dev/<device>
mount -t bcachefs /dev/<device> /mnt/data
```
