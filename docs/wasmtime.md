# Wasmtime sysext

This extension ships [wasmtime](https://wasmtime.dev/).

The wasmtime sysext does not ship a systemd service unit at this point.
In order to start WASM workloads at boot, users need to supply custom unit files via Butane / Ignition.

# Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will **merge the new sysext immediately after successful download**.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of wasmtime 24.0.0.

```yaml
variant: flatcar
version: 1.0.0

storage:
  links:
    - target: /opt/extensions/wasmtime/wasmtime-24.0.0-x86-64.raw
      path: /etc/extensions/wasmtime.raw
      hard: false
  files:
    - path: /opt/extensions/wasmtime/wasmtime-24.0.0-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmtime-24.0.0-x86-64.raw
    - path: /etc/sysupdate.wasmtime.d/wasmtime.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmtime.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
      source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
 
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmtime.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmtime.raw > /tmp/wasmtime"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmtime update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmtime.raw > /tmp/wasmtime-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/wasmtime /tmp/wasmtime-new; then systemd-sysext refresh; fi"
```
