# blackbox_exporter sysext

This sysext ships the [Prometheus blackbox_exporter](https://github.com/prometheus/blackbox_exporter).

The sysext includes a service unit file to start blackbox_exporter at boot.
By default the exporter listens on `:9115` and reads its probe configuration from `/etc/blackbox_exporter/blackbox.yml` (seeded with the upstream default).
Extra command line flags can be set in `/etc/blackbox_exporter/blackbox_exporter.env` via the `BLACKBOX_EXPORTER_OPTS` variable, or the configuration can be replaced via a custom Butane config.

## Usage

The snippet includes automated updates via systemd-sysupdate.
When a new version is released, sysupdate stages it, refreshes the merged sysext, and restarts `blackbox_exporter.service` (see the `systemd-sysupdate.service` drop-in below).
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of blackbox_exporter 0.28.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/blackbox_exporter for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/blackbox_exporter/blackbox_exporter-0.28.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/blackbox_exporter-0.28.0-x86-64.raw
    - path: /etc/sysupdate.blackbox_exporter.d/blackbox_exporter.conf
      contents:
        source: https://extensions.flatcar.org/extensions/blackbox_exporter.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/blackbox_exporter.service
      target: /usr/lib/systemd/system/blackbox_exporter.service
      overwrite: true
    - target: /opt/extensions/blackbox_exporter/blackbox_exporter-0.28.0-x86-64.raw
      path: /etc/extensions/blackbox_exporter.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: blackbox_exporter.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/blackbox_exporter.raw > /run/blackbox_exporter"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C blackbox_exporter update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/blackbox_exporter.raw > /run/blackbox_exporter-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/blackbox_exporter /run/blackbox_exporter-new; then systemd-sysext refresh && systemctl restart blackbox_exporter.service; fi"
```
