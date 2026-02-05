# Scx sysext

This sysext ships [sched-ext schedulers](https://github.com/sched-ext/scx).

Sched-ext is a Linux kernel feature that enables implementing and loading custom process schedulers using BPF.
The sysext includes several schedulers such as `scx_bpfland`, `scx_lavd`, `scx_rusty`, and others.

The sysext includes a service unit file to start a sched-ext scheduler at boot as well as a default configuration.
The service will only start if the kernel supports sched_ext (i.e., `/sys/kernel/sched_ext` exists).

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The default scheduler is `scx_bpfland`. You can change the scheduler and its flags by creating `/etc/default/scx` with your preferred configuration.
Available schedulers include:
- `scx_bpfland` - vruntime-based scheduler (default)
- `scx_lavd` - latency-aware virtual deadline scheduler
- `scx_rusty` - multi-domain BPF + user space hybrid scheduler
- `scx_rustland` - BPF + user space rust scheduler
- `scx_simple` - simple scheduler for demonstration purposes

Run `scx_<name> --help` for scheduler-specific options.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of scx v1.0.19.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/scx for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/scx/scx-v1.0.19-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/scx-v1.0.19-x86-64.raw
    - path: /etc/sysupdate.scx.d/scx.conf
      contents:
        source: https://extensions.flatcar.org/extensions/scx.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/scx/scx-v1.0.19-x86-64.raw
      path: /etc/extensions/scx.raw
      hard: false
systemd:
  units:
    - name: scx.service
      enabled: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: scx.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/scx.raw > /tmp/scx"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C scx update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/scx.raw > /tmp/scx-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/scx /tmp/scx-new; then touch /run/reboot-required; fi"
```

## Configuration

To customize the scheduler, create `/etc/default/scx` with your settings:

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /etc/default/scx
      mode: 0644
      contents:
        inline: |
          SCX_SCHEDULER_OVERRIDE=scx_lavd
          SCX_FLAGS_OVERRIDE=-a
```

Then restart the service with `systemctl restart scx.service`.
