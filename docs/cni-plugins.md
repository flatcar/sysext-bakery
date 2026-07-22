# CNI plugins sysext

This sysext ships the upstream
[containernetworking/plugins](https://github.com/containernetworking/plugins)
reference CNI plugins (`bridge`, `host-local`, `portmap`, `firewall`,
`loopback`, `macvlan`, `ptp`, `vlan`, `bandwidth`, …) under **`/opt/cni/bin`** —
the default plugin directory searched by Nomad's `cni_path`, and usable by any
CNI consumer (Consul Connect, container runtimes, …).

The binaries are downloaded from the upstream release tarball and their
published `.sha256` is verified during the build. There is no service unit; the
plugins are invoked by whatever CNI runtime is configured on the host.

## Why `/opt/cni/bin`

`/opt/cni/bin` is the de-facto default CNI plugin directory (e.g. Nomad's
`cni_path` default). On Flatcar `/opt` is a read-only sysext overlay, so a
sysext is a natural way to provide these binaries there without a writable-path
workaround — the plugins simply appear at `/opt/cni/bin` once the sysext is
merged, and Nomad's `bridge` network mode works with no extra configuration.

## Usage

Download and merge the sysext at provisioning time using the Butane snippet
below (x86-64 shown; see the release metadata for available versions/arches).

The snippet also enables automated updates via systemd-sysupdate. There is no
service to restart, so a new version is simply staged and the merged sysext is
refreshed in place — CNI consumers pick up the updated binaries on their next
invocation, with no reboot required. You can deactivate updates by changing
`enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/cni-plugins/cni-plugins-v1.9.1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/cni-plugins-v1.9.1-x86-64.raw
    - path: /etc/sysupdate.cni-plugins.d/cni-plugins.conf
      contents:
        source: https://extensions.flatcar.org/extensions/cni-plugins.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - path: /etc/extensions/cni-plugins.raw
      target: /opt/extensions/cni-plugins/cni-plugins-v1.9.1-x86-64.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: cni-plugins.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cni-plugins.raw > /run/cni-plugins"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C cni-plugins update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cni-plugins.raw > /run/cni-plugins-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/cni-plugins /run/cni-plugins-new; then systemd-sysext refresh; fi"
```

Check the metadata releases at
https://github.com/flatcar/sysext-bakery/releases/tag/cni-plugins for a list of
all versions available in the bakery.
