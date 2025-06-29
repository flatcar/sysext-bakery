#  Nomad sysext

This sysext ships [nomad](https://github.com/hashicorp/nomad).

The sysext includes a service unit file to start nomad at boot.
Nomad is configured as a server by default.
The default configuration can be modified or replaced via a custom Butane config.

# Usage

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of nomad 1.10.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/nomad for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/nomad/nomad-v1.10.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/nomad-v1.10.0-x86-64.raw
    - path: /etc/sysupdate.nomad.d/nomad.conf
      contents:
        source: https://extensions.flatcar.org/extensions/tailscale.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/nomad.service
      target: /usr/local/lib/systemd/system/nomad.service
      overwrite: true
    - target: /opt/extensions/nomad/nomad-v1.10.0-x86-64.raw
      path: /etc/extensions/nomad.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: nomad.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nomad.raw > /tmp/nomad"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C nomad update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nomad.raw > /tmp/nomad-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/nomad /tmp/nomad-new; then touch /run/reboot-required; fi"
```
