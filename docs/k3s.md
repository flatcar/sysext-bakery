# K3s sysext

This extension ships [k3s](https://k3s.io/).

The k3s sysext can be configured as an agent or a server.
This is determined by the systemd service unit started at boot, so the sysext does not include a default service unit.
Instead, we symlink the respective unit file in the butane config.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.
Updates are only supported within the same minor release, e.g. v1.31.2 -> v1.31.3; _never_ across releases (v1.31.x -> v1.32.x).
This is because upstream Kubernetes does not support unattended automated upgrades across minor releases.

Note that the snippet is for the x86-64 version of k3s v1.31.3 w/ k3s1.

Any specific configuration required would need to be added to the below configuration,
e.g. by providing a token for an agent or server to join or creating a `config.yaml` file.

Generic configuration for both Server (control plane) and Agent (worker):
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/k3s/k3s-v1.31.3+k3s1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/k3s-v1.31.3+k3s1-x86-64.raw
    - path: /etc/sysupdate.k3s.d/k3s-v1.31.conf
      contents:
        source: https://extensions.flatcar.org/extensions/k3s.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/k3s/k3s-v1.31.3+k3s1-x86-64.raw
      path: /etc/extensions/k3s.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: k3s.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/k3s.raw > /tmp/k3s"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C k3s-v1.31 update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/k3s.raw > /tmp/k3s-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/k3s /tmp/k3s-new; then touch /run/reboot-required; fi"
```

For the *server* node, add to the section
```yaml
storage:
  links:
```
the following:
```yaml
    - path: /etc/systemd/system/multi-user.target.wants/k3s.service
      target: /usr/local/lib/systemd/system/k3s.service
      overwrite: true
```

For a k3s agent (worker node) add this instead:
```yaml
    - path: /etc/systemd/system/multi-user.target.wants/k3s-agent.service
      target: /usr/local/lib/systemd/system/k3s-agent.service
      overwrite: true
```
