# HAProxy Data Plane API sysext

This sysext ships the
[HAProxy Data Plane API](https://www.haproxy.com/documentation/dataplaneapi/),
a REST API that manages an HAProxy instance's configuration and runtime
state.

The sysext installs:

- `dataplaneapi` Go binary at `/usr/bin/dataplaneapi`
- `dataplaneapi.service` systemd unit
- `tmpfiles.d` entry that seeds `/etc/dataplaneapi/dataplaneapi.yml`
  from a minimal default on first boot and creates
  `/var/lib/dataplaneapi/{transactions,backups}` state directories

The service is intended to run alongside the [`haproxy` sysext](haproxy.md)
on the same host. The shipped default config points at
`/usr/bin/haproxy`, `/etc/haproxy/haproxy.cfg` and reloads via
`systemctl reload haproxy.service`, matching what the `haproxy` sysext
lays down.

## HAProxy prerequisites

The API refuses requests until a `userlist` matching the one named in
`dataplaneapi.yml` (`userlist: dataplaneapi` by default) is defined in
`/etc/haproxy/haproxy.cfg`. Minimal example:

```
userlist dataplaneapi
    user admin insecure-password change-me
```

Use `password` with a MD5 or SHA-512 crypt hash for real deployments;
`insecure-password` is fine for the initial bring-up smoke test.

## Custom configuration

The `tmpfiles.d` rule uses `C /etc/dataplaneapi/dataplaneapi.yml`
semantics, so the shipped default is only copied in when the file does
not already exist. Provisioning tools that lay down
`/etc/dataplaneapi/dataplaneapi.yml` will not be overwritten by the
sysext or by subsequent sysext updates.

The unit also honours `EnvironmentFile=-/etc/default/dataplaneapi` and
`EnvironmentFile=-/etc/sysconfig/dataplaneapi`. Override `SYSD_OPTIONS`
there to point `-f` at a different file or add flags without editing
the unit.

## Network exposure

The shipped default binds the API to `127.0.0.1:5555`, which is a
deliberately conservative default given the API can rewrite HAProxy
config and shell out to reload it. To expose it on other interfaces,
override `dataplaneapi.host` in your own
`/etc/dataplaneapi/dataplaneapi.yml` and put the port behind an
appropriately restricted network policy (a firewall, an HAProxy
frontend with mTLS, etc.).

## Privileges

The unit runs as `root` because the default `reload_strategy: systemd`
requires the API process to invoke `systemctl reload
haproxy.service`. If you switch to a socket-based strategy (talking to
`/run/haproxy/haproxy-master.sock` directly), drop-in a lower-privilege
`User=`/`Group=` under `/etc/systemd/system/dataplaneapi.service.d/`
and grant that user access to the master socket.

## Usage

Download and merge the sysext at provisioning time using the Butane
snippet below.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag
file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to
`enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of Data Plane API
v3.3.5.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/dataplaneapi for a
list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/dataplaneapi/dataplaneapi-v3.3.5-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/dataplaneapi-v3.3.5-x86-64.raw
    - path: /etc/sysupdate.dataplaneapi.d/dataplaneapi.conf
      contents:
        source: https://extensions.flatcar.org/extensions/dataplaneapi.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/dataplaneapi/dataplaneapi-v3.3.5-x86-64.raw
      path: /etc/extensions/dataplaneapi.raw
      hard: false
systemd:
  units:
    - name: dataplaneapi.service
      enabled: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: dataplaneapi.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/dataplaneapi.raw > /run/dataplaneapi-sysext"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C dataplaneapi update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/dataplaneapi.raw > /run/dataplaneapi-sysext-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/dataplaneapi-sysext /run/dataplaneapi-sysext-new; then touch /run/reboot-required; fi"
```
