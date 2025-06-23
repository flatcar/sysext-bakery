# Docker-buildx sysext

This sysext ships [docker-buildx](https://github.com/docker/buildx).

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of docker-buildx 0.25.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/docker-buildx for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/docker-buildx/docker-buildx-0.25.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/docker-buildx-0.25.0-x86-64.raw
    - path: /etc/sysupdate.docker-buildx.d/docker-buildx.conf
      contents:
        source: https://extensions.flatcar.org/extensions/docker-buildx.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/docker-buildx/docker-buildx-0.25.0-x86-64.raw
      path: /etc/extensions/docker-buildx.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: docker-buildx.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/docker-buildx.raw > /tmp/docker-buildx"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C docker-buildx update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/docker-buildx.raw > /tmp/docker-buildx-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/docker-buildx /tmp/docker-buildx-new; then touch /run/reboot-required; fi"
```

