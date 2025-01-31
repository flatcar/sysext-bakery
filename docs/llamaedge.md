#  Llamaedge sysext

This sysext ships [llamaedge](https://github.com/LlamaEdge/LlamaEdge).
It requires wasmedge to run, so we include the wamsedge sysext in the configuration snippets below.

# Usage

Note that the snippet merely provisions llamaedge.
It does not start automatically.

After provisioning you can interact with llamaedge on the instance:
```bash
wasmedge run /usr/lib/wasmedge/wasm/llama-api-server.wasm
```

The llamaedge sysext can be configured by using the following snippet.
The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of wasmedge 0.14.1 and llamaedge 0.14.16.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/wasmedge-0.14.1-x86-64.raw
      mode: 0420
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmaedge-0.14.1-x86-64.raw
    - path: /opt/extensions/llamaedge-0.14.16-x86-64.raw
      mode: 0420
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/llamaedge-0.14.16-x86-64.raw
    - path: /etc/sysupdate.wasmedge.d/wasmedge.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmedge.conf
    - path: /etc/sysupdate.wasmedge.d/llamaedge.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/llamaedge.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - target: /opt/extensions/wasmedge-0.14.1-x86-64.raw
      path: /etc/extensions/wasmedge.raw
      hard: false
    - target: /opt/extensions/llamaedge-0.14.16-x86-64.raw
      path: /etc/extensions/llamaedge.raw
      hard: false

systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmedge.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmedge.raw > /tmp/wasmedge"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmedge update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmedge.raw > /tmp/wasmedge-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/wasmedge /tmp/wasmedge-new; then touch /run/reboot-required; fi"
        - name: llamaedge.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/llamaedge.raw > /tmp/llamaedge"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C llamaedge update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/llamaedge.raw > /tmp/llamaedge-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/llamaedge /tmp/llamaedge-new; then touch /run/reboot-required; fi"
```
