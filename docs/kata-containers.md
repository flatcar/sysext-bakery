# Kata Containers sysext

This sysext ships [Kata Containers](https://katacontainers.io/), an OCI
container runtime that runs each pod inside a lightweight virtual machine
for hardware-enforced isolation.

The sysext unpacks the upstream `kata-static` release tarball, which
bundles the Kata runtime, agent, containerd shim, guest kernel, initrd
and a hypervisor (QEMU and Cloud Hypervisor) under `/opt/kata`. Symlinks
in `/usr/bin` expose `kata-runtime`, `containerd-shim-kata-v2` and
`kata-collect-data.sh` on `$PATH` after the sysext is merged.

## Usage

This sysext only ships the Kata binaries and assets. To run pods with
Kata, your container runtime needs to be configured to use it. With
containerd, that means adding a Kata runtime stanza to
`/etc/containerd/config.toml`. containerd discovers `containerd-shim-kata-v2`
on `$PATH` from the `runtime_type`:

```toml
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.kata]
  runtime_type = "io.containerd.kata.v2"
```

Download and merge the sysext at provisioning time using the below butane
snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file
at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false`
in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of kata-containers 3.21.0.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/kata-containers for
a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/kata-containers/kata-containers-3.21.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/kata-containers-3.21.0-x86-64.raw
    - path: /etc/sysupdate.kata-containers.d/kata-containers.conf
      contents:
        source: https://extensions.flatcar.org/extensions/kata-containers.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/kata-containers/kata-containers-3.21.0-x86-64.raw
      path: /etc/extensions/kata-containers.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: kata-containers.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/kata-containers.raw > /tmp/kata-containers"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C kata-containers update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/kata-containers.raw > /tmp/kata-containers-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/kata-containers /tmp/kata-containers-new; then touch /run/reboot-required; fi"
```
