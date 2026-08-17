# Teleport sysext

This sysext ships [Teleport](https://github.com/gravitational/teleport) binaries (`teleport`, `tctl`, `tsh`).

The sysext includes a service unit file to start teleport at boot.
The Teleport configuration must be provided at `/etc/teleport/teleport.yaml` via a custom Butane config.

# Usage

Note that the snippet is for the x86-64 version of Teleport v18.9.2.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/teleport/teleport-v18.9.2-x86-64.raw
      mode: 0644
      contents:
        source: https://example.com/teleport-v18.9.2-x86-64.raw
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
```

See the [Teleport documentation](https://goteleport.com/docs/) for configuration details.
