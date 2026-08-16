# Teleport sysext

This sysext ships [Teleport](https://github.com/gravitational/teleport) binaries (`teleport`, `tctl`, `tsh`).

# Usage

Deploy the sysext raw image to `/opt/extensions/teleport/` and link it:

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/teleport/teleport-v18.9.2-x86-64.raw
      mode: 0644
      contents:
        source: https://example.com/teleport-v18.9.2-x86-64.raw
  links:
    - target: /opt/extensions/teleport/teleport-v18.9.2-x86-64.raw
      path: /etc/extensions/teleport.raw
      hard: false
```

After merging, the `teleport`, `tctl`, and `tsh` binaries will be available in `/usr/bin/`.

You must provide your own systemd service unit and Teleport configuration. See the [Teleport documentation](https://goteleport.com/docs/) for details.
