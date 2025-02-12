# Ollama sysext

This sysext ships [Ollama](https://github.com/ollama/ollama).

The sysext includes a service unit file to start Ollama at boot as well as a basic configuration.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.
Ollma's configuration is customized in terms of where Ollama stores its models, configuration and runtime libraries.
It can be changed via the `HOME`, `OLLAMA_MODELS` and `OLLAMA_RUNNERS_DIR` environment variables.
Please refer to the [Ollama documentation for more information](https://github.com/ollama/ollama/tree/main/docs).

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

The snippet below deploys the x86-64 version of Ollama 0.3.9.
**NOTE** in the default configuration, the Ollama API will be **publicly accessible**.
Please update `OLLAMA_HOST` before deployment if you want to change that.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/ollama/ollama-v0.3.9-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/ollama-v0.3.9-x86-64.raw
    - path: /etc/sysupdate.ollama.d/ollama.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/ollama.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
  links:
    - target: /opt/extensions/ollama/ollama-v0.3.9-x86-64.raw
      path: /etc/extensions/ollama.raw
      hard: false

systemd:
  units:
    - name: ollama.service
      enabled: true
      dropins:
        - name: 10-ollama-env-override.conf
          contents: |
            [Service]
            Environment=HOME="/var/lib/ollama"
            Environment=OLLAMA_MODELS="/var/lib/ollama/models"
            Environment=OLLAMA_RUNNERS_DIR="/var/lib/ollama/runners"
            Environment=OLLAMA_HOST="0.0.0.0:11434"
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: ollama.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/ollama.raw > /tmp/ollama"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C ollama update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/ollama.raw > /tmp/ollama-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/ollama /tmp/ollama-new; then touch /run/reboot-required; fi"
```
