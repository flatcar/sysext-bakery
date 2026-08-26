# CNI plugins sysext

This sysext ships the upstream
[containernetworking/plugins](https://github.com/containernetworking/plugins)
reference CNI plugins (`bridge`, `host-local`, `portmap`, `firewall`,
`loopback`, `macvlan`, `ptp`, `vlan`, `bandwidth`, …) under
**`/usr/libexec/cni`**, for use by any CNI consumer (Nomad, Consul Connect,
container runtimes, …).

The binaries are downloaded from the upstream release tarball and their
published `.sha256` is verified during the build. There is no service unit; the
plugins are invoked by whatever CNI runtime is configured on the host.

## Why `/usr/libexec/cni` and not `/opt/cni/bin`

`/opt/cni/bin` is the de-facto upstream default, but on Flatcar `/opt` is
expected to be writable and shipping a sysext into it would silently turn it
read-only. The plugins therefore go under `/usr`, which is already read-only on
Flatcar, so no expectation is violated. This matches `nerdctl.sysext`, which
puts its optional bundled copy in the same place.

Consumers that default to `/opt/cni/bin` need to be pointed at the new path.
For Nomad, set `cni_path` in the client block:

```hcl
client {
  cni_path = "/usr/libexec/cni"
}
```

containerd takes it as `bin_dir` in the CNI section of `config.toml`, and
CRI-O as `plugin_dirs` in `crio.network`.

If you would rather keep the upstream default working unchanged, create the
symlink yourself at provisioning time — `/opt` stays writable, so this does not
need a sysext:

```yaml
storage:
  links:
    - path: /opt/cni/bin
      target: /usr/libexec/cni
      hard: false
```

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
