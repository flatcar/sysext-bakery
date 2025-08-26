# Inspektor Gadget sysext

This sysext ships [Inspektor Gadget](https://www.inspektor-gadget.io/), a collection of tools and framework for data collection and system inspection on Kubernetes clusters and Linux hosts using eBPF.

This sysext includes both the `ig` and `gadgetctl` binaries:
- `ig` - The main inspektor-gadget tool for running gadgets on Linux hosts
- `gadgetctl` - Tool for managing gadgets and interacting with `ig` running in daemon mode

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of Inspektor Gadget v0.43.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/ig for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/ig/ig-v0.43.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/ig-v0.43.0-x86-64.raw
    - path: /etc/sysupdate.ig.d/ig.conf
      contents:
        source: https://extensions.flatcar.org/extensions/ig.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/ig/ig-v0.43.0-x86-64.raw
      path: /etc/extensions/ig.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: ig.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/ig.raw > /tmp/ig"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C ig update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/ig.raw > /tmp/ig-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/ig /tmp/ig-new; then touch /run/reboot-required; fi"
```
