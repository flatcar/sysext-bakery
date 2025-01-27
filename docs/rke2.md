# rke2 sysext

This sysext ships [RKE2](https://docs.rke2.io/),
Rancher's next-generation Kubernetes distribution.

The sysext includes service unit files for both server and agent.
No service is active by default; it is up to the node provisioning configuration to pick which one to start.
See "Usage" below for details.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.
Updates are only supported within the same minor release, e.g. v1.31.2 -> v1.31.3; _never_ across releases (v1.31.x -> v1.32.x).
This is because upstream Kubernetes does not support unattended automated upgrades across minor releases.

Note that the snippet is for the x86-64 version of rke2 v1.31.1.

Generic configuration for both Server (control plane) and Agent (worker):

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /etc/extensions/rke2.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/rke2-v1.31.1+rke2r1-x86-64.raw
    - path: /etc/sysupdate.rke2.d/rke2-v1.31.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/rke2.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - target: /opt/extensions/rke2/rke2-v1.31.3+k3s1-x86-64.raw
      path: /etc/extensions/k3s.raw
      hard: false

systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: rke2.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/rke2.raw > /tmp/rke2"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C rke2-v1.31 update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/rke2.raw > /tmp/rke2-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/rke2 /tmp/rke2-new; then touch /run/reboot-required; fi"
```

For a rke2 server (control plane) node, add to the section
```yaml
storage:
  links:
```
the following:
```yaml
    - path: /etc/systemd/system/multi-user.target.wants/rke2-server.service
      target: /usr/local/lib/systemd/system/rke2-server.service
      overwrite: true
```

For a rke2 agent (worker node), add this instead:
```yaml
    - path: /etc/systemd/system/multi-user.target.wants/rke2-agent.service
      target: /usr/local/lib/systemd/system/rke2-agent.service
      overwrite: true
```

to start either Server or Agent services at boot, respectively.

Note that any configuration you might need (security tokens or config.yaml files) can be deployed in the same fashion, via Butane/Ignition.
