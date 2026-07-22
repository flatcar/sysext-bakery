# node_exporter sysext

This sysext ships the [Prometheus node_exporter](https://github.com/prometheus/node_exporter).

The sysext includes a service unit file to start node_exporter at boot.
By default the exporter listens on `:9100`.
Extra command line flags can be set in `/etc/node_exporter/node_exporter.env` via the `NODE_EXPORTER_OPTS` variable, or the configuration can be replaced via a custom Butane config.

## Usage

The snippet includes automated updates via systemd-sysupdate.
When a new version is released, sysupdate stages it, refreshes the merged sysext, and restarts `node_exporter.service` (see the `systemd-sysupdate.service` drop-in below).
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of node_exporter 1.12.1.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/node_exporter for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/node_exporter/node_exporter-1.12.1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/node_exporter-1.12.1-x86-64.raw
    - path: /etc/sysupdate.node_exporter.d/node_exporter.conf
      contents:
        source: https://extensions.flatcar.org/extensions/node_exporter.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/node_exporter.service
      target: /usr/lib/systemd/system/node_exporter.service
      overwrite: true
    - target: /opt/extensions/node_exporter/node_exporter-1.12.1-x86-64.raw
      path: /etc/extensions/node_exporter.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: node_exporter.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/node_exporter.raw > /run/node_exporter"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C node_exporter update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/node_exporter.raw > /run/node_exporter-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/node_exporter /run/node_exporter-new; then systemd-sysext refresh && systemctl restart node_exporter.service; fi"
```
