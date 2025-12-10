# Keepalive-Daemon sysext

The Keepalived sysext ships a statically compiled keepalived.

# Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of keepalived v2.3.1. Other architectures are also available.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/keepalived for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/keepalived/keepalived-v2.3.1-x86-64.raw
      mode: 0644
      contents:
    - path: /etc/sysupdate.keepalived.d/keepalived.conf
      contents:
        source: https://extensions.flatcar.org/extensions/keepalived.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
        source: https://extensions.flatcar.org/extensions/keepalived-v2.3.1-x86-64.raw

  links:
    - target: /opt/extensions/keepalived/keepalived-v2.3.1-x86-64.raw
      path: /etc/extensions/keepalived.raw
      hard: false


systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: keepalived.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/keepalived.raw > /tmp/keepalived"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C keepalived update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/keepalived.raw > /tmp/keepalived-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/keepalived /tmp/keepalived-new; then touch /run/reboot-required; fi"
```
