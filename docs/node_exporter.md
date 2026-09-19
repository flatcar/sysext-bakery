# Prometheus Node Exporter sysext

This sysext ships [Prometheus Node Exporter](https://github.com/prometheus/node_exporter).

The sysext includes a service unit file to start node-exporter at boot.
The default configuration can be modified or replaced via a custom Butane config.

# Usage

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates, refresh the merged sysext, and restart `node-exporter.service` — no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of node-exporter 1.12.1.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/node-exporter for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/node-exporter/node-exporter-v1.12.1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/node-exporter-v1.12.1-x86-64.raw
    - path: /etc/sysupdate.node-exporter.d/node-exporter.transfer
      contents:
        source: https://extensions.flatcar.org/extensions/node-exporter.transfer
  links:
    - path: /etc/systemd/system/multi-user.target.wants/node-exporter.service
      target: /usr/lib/systemd/system/node-exporter.service
      overwrite: true
    - target: /opt/extensions/node-exporter/node-exporter-v1.12.1-x86-64.raw
      path: /etc/extensions/node-exporter.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: node-exporter.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/node-exporter.raw > /tmp/node-exporter"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C node-exporter update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/node-exporter.raw > /tmp/node-exporter-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/node-exporter /tmp/node-exporter-new; then systemd-sysext refresh && systemctl restart node-exporter.service; fi"
```
