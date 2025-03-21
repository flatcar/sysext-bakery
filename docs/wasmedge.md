# Wasmedge sysext

This sysext ships [wasmedge](https://wasmedge.org/).

The wasmedge sysext does not ship a systemd service unit at this point.
In order to run it at boot users would need to add a custom service file in the config below.

# Usage

The wasmedge sysext can be configured by using the following snippet.
The snippet includes automated updates via systemd-sysupdate.
Sysupdate will **merge the new sysext immediately after successful download**.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of wasmedge 0.14.1.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/wasmedge-0.14.1-x86-64.raw
      mode: 0420
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/wasmedge-0.14.1-x86-64.raw
    - path: /etc/sysupdate.wasmedge.d/wasmedge.conf
      contents:
        source: https://extensions.flatcar.org/extensions/wasmedge.conf
  links:
    - target: /opt/extensions/wasmedge-0.14.1-x86-64.raw
      path: /etc/extensions/wasmedge.raw
      hard: false

systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmedge.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmedge.raw > /tmp/wasmedge"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmedge update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmedge.raw > /tmp/wasmedge-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/wasmedge /tmp/wasmedge-new; then systemd-sysext refresh; fi"
```
