# Coder sysext

This sysext ships [Coder](https://coder.com/), an open-source platform
for self-hosted developer workspaces.

The sysext installs:

- `coder` Go binary at `/usr/bin/coder`
- `coder.service` and `coder-workspace-proxy.service` units, taken
  unmodified from the upstream Coder Debian package
- `sysusers.d` entry to create the `coder` system user the units run as
- `tmpfiles.d` entry that creates empty `0600 root:root` env files at
  `/etc/coder.d/coder.env` and `/etc/coder.d/coder-workspace-proxy.env`
  on first boot

The units carry `ConditionFileNotEmpty` on their env files, so
`coder.service` only starts once `/etc/coder.d/coder.env` has been
populated with at least `CODER_ACCESS_URL` and `CODER_PG_CONNECTION_URL`
(same for the workspace-proxy unit).

## Usage

Download and merge the sysext at provisioning time using the below butane
snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file
at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false`
in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of Coder v2.34.4.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/coder for a list of
all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/coder/coder-v2.34.4-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/coder-v2.34.4-x86-64.raw
    - path: /etc/sysupdate.coder.d/coder.conf
      contents:
        source: https://extensions.flatcar.org/extensions/coder.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /etc/coder.d/coder.env
      mode: 0600
      contents:
        inline: |
          CODER_ACCESS_URL=https://coder.example.com
          CODER_HTTP_ADDRESS=0.0.0.0:3000
          CODER_PG_CONNECTION_URL=postgres://coder:coder@db.example.com/coder?sslmode=disable
  links:
    - target: /opt/extensions/coder/coder-v2.34.4-x86-64.raw
      path: /etc/extensions/coder.raw
      hard: false
systemd:
  units:
    - name: coder.service
      enabled: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: coder.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/coder.raw > /run/coder"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C coder update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/coder.raw > /run/coder-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/coder /run/coder-new; then touch /run/reboot-required; fi"
```
