---
title: Tilde sysext
---

# Tilde sysext

This sysext ships [tilde](https://os.ghalkes.nl/tilde.html), an intuitive text
editor for the console/terminal. It provides shortcuts familiar from GUI
environments like Gnome, KDE, and Windows — e.g. Control-C to copy, Control-V
to paste, and Meta-F to open the File menu.

Tilde does not run as a persistent service, so no systemd service unit is
shipped or needs to be restarted on update. Running `systemd-sysext refresh`
(or a reboot) is enough to activate a new version.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate. Sysupdate will stage
updates and request a reboot by creating a flag file at `/run/reboot-required`. You
can deactivate updates by changing `enabled: true` to `enabled: false` in
`systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of tilde 1.1.2.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/tilde for a list of all
versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/tilde/tilde-1.1.2-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/tilde-1.1.2-x86-64.raw
    - path: /etc/sysupdate.tilde.d/tilde.conf
      contents:
        source: https://extensions.flatcar.org/extensions/tilde.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/tilde/tilde-1.1.2-x86-64.raw
      path: /etc/extensions/tilde.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: tilde.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/tilde.raw > /tmp/tilde"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C tilde update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/tilde.raw > /tmp/tilde-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/tilde /tmp/tilde-new; then systemd-sysext refresh; fi"
```
