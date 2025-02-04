# Nebula sysext

This sysext ships [Nebula](https://github.com/slackhq/nebula).

## Usage

Refer to the following Butane snippet that enables Nebula v1.9.5 for an x86-64 machine with automated updates using `systemd-sysupdate`.

Note that you will also need to supply a [Nebula config file](https://github.com/slackhq/nebula/blob/master/examples/config.yml) at `/etc/nebula/config.yaml`, as well as necessary key files. You can embed them into the `files` section of your Butane configuration.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/nebula/nebula-v1.9.5-x86-64.raw
      mode: 0644
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/nebula-v1.9.5-x86-64.raw
    - path: /etc/sysupdate.nebula.d/nebula.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/nebula.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/nebula.service
      target: /usr/lib/systemd/system/nebula.service
      overwrite: true
    - target: /opt/extensions/nebula/nebula-v1.9.5-x86-64.raw
      path: /etc/extensions/nebula.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: nebula.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nebula.raw > /tmp/nebula"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C nebula update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nebula.raw > /tmp/nebula-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/nebula /tmp/nebula-new; then touch /run/reboot-required; fi"
```
