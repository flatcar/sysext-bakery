# Vault sysext

This sysext ships [vault](https://github.com/hashicorp/vault).

The sysext includes a service unit file to start vault at boot.
The default configuration can be modified or replaced via a custom Butane config.

# Usage

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates, refresh the merged sysext, and restart `vault.service` — no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of vault 1.20.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/vault for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/vault/vault-1.20.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/vault-1.20.0-x86-64.raw
    - path: /etc/sysupdate.vault.d/vault.conf
      contents:
        source: https://extensions.flatcar.org/extensions/vault.conf
  links:
    - path: /etc/systemd/system/multi-user.target.wants/vault.service
      target: /usr/local/lib/systemd/system/vault.service
      overwrite: true
    - target: /opt/extensions/vault/vault-1.20.0-x86-64.raw
      path: /etc/extensions/vault.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: vault.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/vault.raw > /tmp/vault"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C vault update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/vault.raw > /tmp/vault-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/vault /tmp/vault-new; then systemd-sysext refresh && systemctl restart vault.service; fi"
```
