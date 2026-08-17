# Teleport sysext

This sysext ships [Teleport](https://github.com/gravitational/teleport) binaries (`teleport`, `tctl`, `tsh`).

The sysext includes a service unit file to start teleport at boot.
The Teleport configuration must be provided at `/etc/teleport/teleport.yaml` via a custom Butane config.

# Usage

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates, refresh the merged sysext, and restart `teleport.service` — no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of Teleport v18.9.2.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/teleport/teleport-v18.9.2-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/teleport-v18.9.2-x86-64.raw
    - path: /etc/sysupdate.teleport.d/teleport.conf
      contents:
        source: https://extensions.flatcar.org/extensions/teleport.conf
    - path: /etc/teleport/teleport.yaml
      mode: 0640
      contents:
        source: data:text/plain;charset=utf-8,<url-encoded-config>
  links:
    - target: /opt/extensions/teleport/teleport-v18.9.2-x86-64.raw
      path: /etc/extensions/teleport.raw
      hard: false
    - path: /etc/systemd/system/multi-user.target.wants/teleport.service
      target: /usr/lib/systemd/system/teleport.service
      overwrite: true
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: teleport.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/teleport.raw > /tmp/teleport"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C teleport update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/teleport.raw > /tmp/teleport-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/teleport /tmp/teleport-new; then systemd-sysext refresh && systemctl restart teleport.service; fi"
```

The `teleport.conf` sysupdate transfer config should contain:

```ini
[Transfer]
Verify=false

[Source]
Type=url-file
Path=https://extensions.flatcar.org/extensions/teleport/
MatchPattern=teleport-@v-%a.raw

[Target]
InstancesMax=3
Type=regular-file
Path=/opt/extensions/teleport
CurrentSymlink=/etc/extensions/teleport.raw
```

See the [Teleport documentation](https://goteleport.com/docs/) for configuration details.
