# Consul sysext

This sysext ships [consul](https://github.com/hashicorp/consul).

The sysext includes a service unit file to start consul at boot.
The default configuration can be modified or replaced via a custom Butane config.

# Usage

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of consul 1.21.4.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/consul for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/consul/consul-1.21.4-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/consul-1.21.4-x86-64.raw
    - path: /etc/sysupdate.consul.d/consul.conf
      contents:
        source: https://extensions.flatcar.org/extensions/consul.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/consul.service
      target: /usr/local/lib/systemd/system/consul.service
      overwrite: true
    - target: /opt/extensions/consul/consul-1.21.4-x86-64.raw
      path: /etc/extensions/consul.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: consul.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/consul.raw > /tmp/consul"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C consul update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/consul.raw > /tmp/consul-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/consul /tmp/consul-new; then systemd-sysext refresh && systemctl restart consul.service; fi"
```
