# Podman sysext

This sysext ships [podman](https://podman.io/), a daemonless container engine
for developing, managing, and running OCI containers on Linux.

The sysext is built entirely from upstream source inside an ephemeral
Alpine container. Each release statically links the following components
against musl libc so the sysext is self-contained:

- `podman`, `podman-remote`, `rootlessport`, `quadlet`
  ([containers/podman](https://github.com/containers/podman))
- `conmon` ([containers/conmon](https://github.com/containers/conmon))
- `crun` ([containers/crun](https://github.com/containers/crun))
- `runc` ([opencontainers/runc](https://github.com/opencontainers/runc))
- `netavark`, `aardvark-dns`
  ([containers/netavark](https://github.com/containers/netavark),
  [containers/aardvark-dns](https://github.com/containers/aardvark-dns))
- `slirp4netns`
  ([rootless-containers/slirp4netns](https://github.com/rootless-containers/slirp4netns))
- `fuse-overlayfs`
  ([containers/fuse-overlayfs](https://github.com/containers/fuse-overlayfs))

Helper binaries land in `/usr/libexec/podman/` and a default
`/usr/share/containers/containers.conf` points podman at them and selects
`netavark` as the network backend.

The sysext ships a socket-activated `podman.service` to expose the rootful
Podman REST API at `/run/podman/podman.sock`. The socket is enabled on
merge via a `sockets.target` drop-in.

## Building

`./bakery.sh create podman <version>` builds the sysext. The companion
binary versions can be overridden via build flags — see
`./bakery.sh create podman help` for the full list.

## Usage

Download and merge the sysext at provisioning time using the below butane
snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file
at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false`
in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of podman v5.5.2.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/podman for a list of
all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/podman/podman-v5.5.2-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/podman-v5.5.2-x86-64.raw
    - path: /etc/sysupdate.podman.d/podman.conf
      contents:
        source: https://extensions.flatcar.org/extensions/podman.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/podman/podman-v5.5.2-x86-64.raw
      path: /etc/extensions/podman.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: podman.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/podman.raw > /tmp/podman"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C podman update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/podman.raw > /tmp/podman-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/podman /tmp/podman-new; then touch /run/reboot-required; fi"
```
