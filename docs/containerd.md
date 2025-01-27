# Containerd sysext

This sysext ships a custom [containerd](https://github.com/containerd/containerd).
It can be used to diverge from the containerd included in Flatcar's OS image, e.g. to upgrade or downgrade manually, or to test a newer version than what's included in the stock OS image.

The sysext includes a service unit file to start containerd at boot as well as a basic `containerd.toml` configuration.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.
It deactivates the default containerd included in the Flatcar OS image by masking the respective sysext.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of containerd 2.0.0.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/containerd/containerd-2.0.0-x86-64.raw
      mode: 0644
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/containerd-2.0.0-x86-64.raw
    - path: /etc/sysupdate.containerd.d/containerd.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/containerd.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - target: /opt/extensions/containerd/containerd-2.0.0-x86-64.raw
      path: /etc/extensions/containerd.raw
      hard: false
    - path: /etc/extensions/containerd-flatcar.raw
      target: /dev/null
      overwrite: true
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: containerd.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/containerd.raw > /tmp/containerd"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C containerd update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/containerd.raw > /tmp/containerd-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/containerd /tmp/containerd-new; then touch /run/reboot-required; fi"
```
