# Tailscale sysext

This sysext ships [Tailscale](https://tailscale.com/).

Starting with version v1.78.1 the Tailscale sysext includes a mechanism to automatically start the service at boot.
It uses the service's [default configuration](https://github.com/tailscale/tailscale/blob/main/cmd/tailscaled/tailscaled.defaults)
which can be customised or replaced via a custom Butane config.

Older releases of the sysext (1.76 and earlier) did not pre-enable the service.
The unit can be enabled via Butane in order to start tailscale at boot.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of tailscale 1.80.3.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/tailscale for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/tailscale/tailscale-v1.80.3-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/tailscale-v1.80.3-x86-64.raw
    - path: /etc/sysupdate.tailscale.d/tailscale.conf
      contents:
        source: https://extensions.flatcar.org/extensions/tailscale.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/tailscaled.service
      target: /usr/local/lib/systemd/system/tailscaled.service
      overwrite: true
    - target: /opt/extensions/tailscale/tailscale-v1.80.3-x86-64.raw
      path: /etc/extensions/tailscale.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: tailscale.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/tailscale.raw > /tmp/tailscale"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C tailscale update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/tailscale.raw > /tmp/tailscale-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/tailscale /tmp/tailscale-new; then touch /run/reboot-required; fi"
```
