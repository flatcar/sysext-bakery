# Cilium sysext

This sysext ships the [Cilium CLI](https://github.com/cilium/cilium-cli).

This sysext includes a service unit file to start cilium at boot.

## Usage

Download and merge the sysext at provisioning time using the below butane
snippet.  Additional install flags can be passed to cilium using the
CILIUM_INSTALL_ARGS environment variable.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

```yaml
variant: flatcar
version: 1.1.0

storage:
  files:
    - path: /opt/extensions/cilium/cilium-v0.18.2-x86-64.raw
      contents:
        source: https://extensions.flatcar.org/extensions/cilium-v0.18.2-x86-64.raw
    - path: /etc/sysupdate.cilium.d/cilium.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/clium.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - target: /opt/extensions/cilium/cilium-v0.18.2-x86-64.raw
      path: /etc/extensions/cilium.raw
      hard: false

systemd:
  units:
    - name: cilium.service
      enabled: true
      dropins:
        - name: 10-cilium-env-override.conf
          contents: |
            [Service]
            Environment=CILIUM_INSTALL_ARGS="--set kubeProxyReplacement=true --namespace=kube-system"
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: cilium.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cilium.raw > /tmp/cilium"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C cilium update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/cilium.raw > /tmp/cilium-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/cilium /tmp/cilium-new; then touch /run/reboot-required; fi"
```
