# CRI-O sysext

This sysext ships [cri-o](https://github.com/cri-o/cri-o).

The sysext includes a service unit file to start cri-o at boot as well as a basic configuration.

To use Kubernetes with cri-o in flatcar, you will need to pass the criSocket to kubeadm, like e.g.
```
kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version v1.29.2 --cri-socket=unix:///var/run/crio/crio.sock
```

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of cri-o v1.32.2.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/crio for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/crio/crio-v1.32.2-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/crio-v1.32.2-x86-64.raw
    - path: /etc/sysupdate.crio.d/crio.conf
      contents:
        source: https://extensions.flatcar.org/extensions/crio.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/crio/crio-v1.32.2-x86-64.raw
      path: /etc/extensions/crio.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: crio.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/crio.raw > /tmp/crio"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C crio update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/crio.raw > /tmp/crio-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/crio /tmp/crio-new; then touch /run/reboot-required; fi"
```
