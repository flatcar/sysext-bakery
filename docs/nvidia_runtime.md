# NVIDIA runtime sysext

This sysext ships the NVIDIA runtime environment and related tools.
It does _not_ include the kernel module.
Please refer to the [NVIDIA customisation guide](https://www.flatcar.org/docs/latest/setup/customization/using-nvidia/)
for information and configuration snippets to deploy the kernel module on Flatcar.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.

You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.
Note that the snippet is for the x86-64 version of the NVIDIA runtime version v1.17.5.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/nvidia-runtime for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/nvidia_runtime/nvidia_runtime-v1.17.5-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/nvidia_runtime-v1.17.5-x86-64.raw
    - path: /etc/sysupdate.nvidia_runtime.d/nvidia_runtime.conf
      contents:
        source: https://extensions.flatcar.org/extensions/nvidia_runtime.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/nvidia_runtime/nvidia_runtime-v1.17.5-x86-64.raw
      path: /etc/extensions/nvidia_runtime.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: nvidia_runtime.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nvidia_runtime.raw > /tmp/nvidia_runtime"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C nvidia_runtime update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/nvidia_runtime.raw > /tmp/nvidia_runtime-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/nvidia_runtime /tmp/nvidia_runtime-new; then touch /run/reboot-required; fi"
```
