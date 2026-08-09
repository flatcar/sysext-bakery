---
title: Btop sysext
---

# Btop sysext

This sysext ships [btop](https://github.com/aristocratos/btop), a modern,
colourful resource monitor for the terminal that shows usage and stats for
CPU, memory, disks, network, and running processes, with mouse support and
customisable themes.

Btop does not run as a persistent service, so no systemd service unit is
shipped or needs to be restarted on update. Running `systemd-sysext refresh`
(or a reboot) is enough to activate a new version.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate. Sysupdate will stage
updates and request a reboot by creating a flag file at `/run/reboot-required`. You
can deactivate updates by changing `enabled: true` to `enabled: false` in
`systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of btop 1.4.0.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/btop for a list of all
versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/btop/btop-1.4.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/btop-1.4.0-x86-64.raw
    - path: /etc/sysupdate.btop.d/btop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/btop.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/btop/btop-1.4.0-x86-64.raw
      path: /etc/extensions/btop.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: btop.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/btop.raw > /tmp/btop"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C btop update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/btop.raw > /tmp/btop-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/btop /tmp/btop-new; then systemd-sysext refresh; fi"
```
