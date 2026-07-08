# HAProxy sysext

This sysext ships [HAProxy](https://www.haproxy.org/), a reliable
high-performance TCP/HTTP load balancer.

The sysext is built from upstream source inside an ephemeral Alpine
container as a statically linked musl binary with OpenSSL (incl. QUIC
compat for HTTP/3), PCRE2 (JIT), Lua 5.4, zlib, threading, Linux
capabilities, transparent proxy, network namespaces, TCP Fast Open and
the Prometheus exporter enabled. The binary has no runtime library
dependencies on the host and lands at `/usr/bin/haproxy`. Alongside it
the sysext ships:

- `haproxy.service` based on the upstream
  `admin/systemd/haproxy.service.in`, with sandboxing/`ProtectSystem`
  options enabled
- `sysusers.d` entry to create the `haproxy` system user the service
  runs as
- `tmpfiles.d` entry that seeds `/etc/haproxy/haproxy.cfg` from a
  minimal default on first boot, exposing the stats page at
  `127.0.0.1:8404`

## Custom configuration

The sysext ships a default config at `/usr/share/haproxy/haproxy.cfg`.
The `tmpfiles.d` rule uses `C /etc/haproxy/haproxy.cfg` semantics, so
it copies the default in only when `/etc/haproxy/haproxy.cfg` does not
already exist. Any file placed there by Ignition, Terraform,
config-management, or by hand wins — the default is not applied on top
of it and later sysext updates will not overwrite it.

Two common patterns:

- **Provisioning-time config.** Write `/etc/haproxy/haproxy.cfg` from
  the Ignition/butane snippet (as in the [Usage](#usage) example
  below). The seed default is skipped and the service starts on your
  config on first boot.
- **Runtime-managed config.** Leave `/etc/haproxy/haproxy.cfg` off the
  snippet, let the default seed in, then have your config-management
  tool (or a dataplane API) rewrite it and `systemctl reload
  haproxy.service`. The unit's `ExecReload` runs `haproxy -c` first,
  so a syntactically bad rewrite will not take effect.

The unit also honours `EnvironmentFile=-/etc/default/haproxy` and
`EnvironmentFile=-/etc/sysconfig/haproxy` (both optional). Override
`CONFIG` there to point `-f` at a different file, or `EXTRAOPTS` to
add flags without editing the unit.

## Usage

Download and merge the sysext at provisioning time using the below
butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag
file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to
`enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of HAProxy 3.2.5.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/haproxy for a list
of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/haproxy/haproxy-3.2.5-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/haproxy-3.2.5-x86-64.raw
    - path: /etc/sysupdate.haproxy.d/haproxy.conf
      contents:
        source: https://extensions.flatcar.org/extensions/haproxy.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /etc/haproxy/haproxy.cfg
      mode: 0644
      contents:
        inline: |
          global
              log         stdout format raw local0
              user        haproxy
              group       haproxy
              maxconn     4096

          defaults
              log     global
              mode    http
              option  httplog
              timeout connect 5s
              timeout client  50s
              timeout server  50s

          frontend http-in
              bind *:80
              default_backend servers

          backend servers
              server srv1 127.0.0.1:8080 check
  links:
    - target: /opt/extensions/haproxy/haproxy-3.2.5-x86-64.raw
      path: /etc/extensions/haproxy.raw
      hard: false
systemd:
  units:
    - name: haproxy.service
      enabled: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: haproxy.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/haproxy.raw > /run/haproxy-sysext"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C haproxy update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/haproxy.raw > /run/haproxy-sysext-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/haproxy-sysext /run/haproxy-sysext-new; then touch /run/reboot-required; fi"
```
