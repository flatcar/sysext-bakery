# Chrony sysext

This extension ships [Chrony](https://chrony-project.org/).

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Generic configration:
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/chrony/chrony-4.8-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/chrony-4.8-x86-64.raw
    - path: /etc/sysupdate.chrony.d/chrony.conf
      contents:
        source: https://extensions.flatcar.org/extensions/chrony/chrony.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /etc/chrony/chrony.conf
      mode: 0644
      contents:
        inline: |
          server 0.flatcar.pool.ntp.org iburst
          server 1.flatcar.pool.ntp.org iburst
          server 2.flatcar.pool.ntp.org iburst
          server 3.flatcar.pool.ntp.org iburst
          driftfile /var/lib/chrony/drift
          makestep 1.0 3
          rtcsync
  links:
    - target: /opt/extensions/chrony/chrony-4.8-x86-64.raw
      path: /etc/extensions/chrony.raw
      hard: false
    - path: /etc/systemd/system/multi-user.target.wants/chrony.service
      target: /usr/lib/systemd/system/chrony.service
      overwrite: true
systemd:
  units:
    - name: systemd-timesyncd.service
      mask: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: chrony.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/chrony.raw > /tmp/chrony"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C chrony update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/chrony.raw > /tmp/chrony-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/chrony /tmp/chrony-new; then touch /run/reboot-required; fi"
```
