# NetBird sysext

This sysext ships the [NetBird](https://github.com/netbirdio/netbird) client, a WireGuard-based mesh VPN.

The sysext includes a service unit file that starts the NetBird daemon at boot.
The daemon stays idle until the machine is enrolled with `netbird up --setup-key <key>`; the WireGuard interface (`wt0` by default) only appears after enrollment.

## Usage

The snippet below includes automated updates via systemd-sysupdate.
Sysupdate will stage updates, refresh the merged sysext, and restart `netbird.service` — no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of NetBird v0.75.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/netbird for a list of all versions available in the bakery.

The optional `netbird-up.service` unit enrolls the machine on first boot using a [setup key](https://docs.netbird.io/how-to/register-machines-using-setup-keys); replace `<YOUR-SETUP-KEY>` or drop the unit and enroll manually.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/netbird/netbird-v0.75.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/netbird-v0.75.0-x86-64.raw
    - path: /etc/sysupdate.netbird.d/netbird.conf
      contents:
        source: https://extensions.flatcar.org/extensions/netbird.conf
  links:
    - target: /opt/extensions/netbird/netbird-v0.75.0-x86-64.raw
      path: /etc/extensions/netbird.raw
      hard: false
systemd:
  units:
    - name: netbird-up.service
      enabled: true
      contents: |
        [Unit]
        Description=Enroll machine with NetBird
        After=netbird.service
        ConditionPathExists=!/etc/netbird/config.json
        [Service]
        Type=oneshot
        ExecStart=/usr/bin/netbird up --setup-key <YOUR-SETUP-KEY>
        Restart=on-failure
        RestartSec=10
        [Install]
        WantedBy=multi-user.target
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: netbird.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/netbird.raw > /tmp/netbird"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C netbird update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/netbird.raw > /tmp/netbird-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/netbird /tmp/netbird-new; then systemd-sysext refresh && systemctl restart netbird.service; fi"
```
