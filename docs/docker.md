# Docker sysext

This sysext ships a custom [docker](https://docker.com)
The docker sysext comes with containerd and runc as bundled by upstream in https://download.docker.com/linux/static/stable/x86_64/.
It can be used to diverge from the docker included in Flatcar's OS image, e.g. to upgrade or downgrade manually, or to test a newer version than what's included in the stock OS image.

The sysext includes a service unit file to start containerd at boot and the docker daemon via socket activation, as well as basic configuration.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.
It deactivates the default containerd and docker included in the Flatcar OS image by masking the respective sysexts.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of docker 28.0.4.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/docker for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/docker/docker-28.0.4-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/docker-28.0.4-x86-64.raw
    - path: /etc/sysupdate.docker.d/docker.conf
      contents:
        source: https://extensions.flatcar.org/extensions/docker.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/docker/docker-28.0.4-x86-64.raw
      path: /etc/extensions/docker.raw
      hard: false
    - path: /etc/extensions/docker-flatcar.raw
      target: /dev/null
      overwrite: true
    - path: /etc/extensions/containerd-flatcar.raw
      target: /dev/null
      overwrite: true
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: docker.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/docker.raw > /tmp/docker"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C docker update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/docker.raw > /tmp/docker-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/docker /tmp/docker-new; then touch /run/reboot-required; fi"
```

