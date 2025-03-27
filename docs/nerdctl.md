#  Nerdctl sysext

This sysext ships [nerdctl](https://github.com/containerd/nerdctl).
It requires containerd, either built-in or via a [containerd](/docs/containerd.md) or [docker](/docs/docker.md) sysext.

The sysext build can optionally be instructed to include CNI plugins.
If the plugins are not included, `nerdctl` can only operate in `--net host` mode.

# Usage

The example ships nerdctl (version 2.0.4) only; i.e. it uses containerd provided by the OS.
Please refer to the containerd and docker extension documentation referenced above to combine nerdctl with a custom containerd.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/nerdctl for a list of all versions available in the bakery.
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/nerdctl-v2.0.4.raw
      mode: 0420
      contents:
        source: https://extensions.flatcar.org/extensions/nerdctl-v2.0.4.raw
    - path: /etc/sysupdate.nerdctl.d/nerdctl.conf
      contents:
        source: https://extensions.flatcar.org/extensions/nerdctl.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/nerdctl-v2.0.4.raw
      path: /etc/extensions/nerdctl.raw
      hard: false

systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: nerdctl.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nerdctl.raw > /tmp/nerdctl"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C nerdctl update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nerdctl.raw > /tmp/nerdctl-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/nerdctl /tmp/nerdctl-new; then touch /run/reboot-required; fi"
```
