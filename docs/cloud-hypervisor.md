# Cloud Hypervisor sysext

This sysext ships [Cloud Hypervisor](https://www.cloudhypervisor.org/), a
Virtual Machine Monitor (VMM) optimised for running modern cloud workloads.

The sysext installs the upstream statically-linked `cloud-hypervisor`
binary to `/usr/bin/cloud-hypervisor` and the `ch-remote` control tool to
`/usr/bin/ch-remote`. Cloud Hypervisor is typically invoked by a higher
level orchestrator (for example Kata Containers or Firecracker-compatible
tooling), so this sysext does not ship a service unit.

## Usage

Download and merge the sysext at provisioning time using the below butane
snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file
at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false`
in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of cloud-hypervisor v44.0.

Check out the metadata release at
https://github.com/flatcar/sysext-bakery/releases/tag/cloud-hypervisor for
a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/cloud-hypervisor/cloud-hypervisor-v44.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/cloud-hypervisor-v44.0-x86-64.raw
    - path: /etc/sysupdate.cloud-hypervisor.d/cloud-hypervisor.conf
      contents:
        source: https://extensions.flatcar.org/extensions/cloud-hypervisor.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/cloud-hypervisor/cloud-hypervisor-v44.0-x86-64.raw
      path: /etc/extensions/cloud-hypervisor.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: cloud-hypervisor.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cloud-hypervisor.raw > /tmp/cloud-hypervisor"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C cloud-hypervisor update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cloud-hypervisor.raw > /tmp/cloud-hypervisor-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/cloud-hypervisor /tmp/cloud-hypervisor-new; then touch /run/reboot-required; fi"
```
