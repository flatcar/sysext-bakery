# Falco sysext

This sysext ships [falco](https://falco.org).
It includes the [Falco Modern EBPF](https://github.com/falcosecurity/falco/blob/master/scripts/systemd/falco-modern-bpf.service).
Create systemd drop-ins in the below example config or replace the service to suit your needs if necessary. 

The default falco config and rules files are included.
If you need to ship custom configuration - e.g. SysDig's Falco workshop rules - add the following to your butane config:
```yaml
storage:
  files:
    - path: /etc/falco/falco_rules.local.yaml
      contents:
        source: "https://raw.githubusercontent.com/sysdiglabs/falco-workshop/refs/heads/master/falco_rules.local.yaml"
```

Of course its also possible to use the 
[artifact-follower](https://falco.org/blog/falcoctl-install-manage-rules-plugins/#follow-artifacts) to download falco artifacts automatically.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of falco 0.39.1.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/falco/falco-0.39.1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/falco-0.39.1-x86-64.raw
    - path: /etc/sysupdate.falco.d/falco.conf
      contents:
        source: https://extensions.flatcar.org/extensions/falco.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/falco/falco-0.39.1-x86-64.raw
      path: /etc/extensions/falco.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: falco.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/falco.raw > /tmp/falco"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C falco update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/falco.raw > /tmp/falco-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/falco /tmp/falco-new; then touch /run/reboot-required; fi"
```

