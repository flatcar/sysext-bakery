# CoreDNS sysext

This sysext ships [CoreDNS](https://coredns.io/), the pluggable DNS server, as the static release binary published by the CoreDNS project.

The image contains:

- the `coredns` binary at `/usr/bin/coredns`
- a `coredns.service` unit that runs CoreDNS as an unprivileged `coredns` user with `CAP_NET_BIND_SERVICE`, so it can bind port 53 without root
- a `sysusers.d` entry that creates that `coredns` system user
- a commented example configuration at `/usr/share/doc/coredns/Corefile.example`

Everything the image ships lives under `/usr`. A hierarchy becomes a read-only overlay as soon as one merged image ships it, so an extension that shipped an `/opt` path would hide files a node placed there at install time. This one never does that.

## Configuration

The extension ships no `Corefile`, and it cannot: a sysext merges `/usr` and `/opt`, never `/etc`. The unit reads `/etc/coredns/Corefile`, which is the common convention. Write that file with Ignition, with config management, or by hand. Start from `/usr/share/doc/coredns/Corefile.example`. CoreDNS never reads the example itself.

CoreDNS exits when an address named in a `bind` directive is not up yet. That happens on a node that binds a link-local address on an interface `systemd-networkd` brings up during boot. The unit therefore sets `Restart=on-failure` with `RestartSec=2s`, and disables start rate limiting with `StartLimitIntervalSec=0`, so the service recovers on its own once the address appears.

`systemctl reload coredns` sends `SIGUSR1`, which makes CoreDNS re-read the `Corefile` without dropping queries.

## Service ordering

The shipped unit orders itself after `network-online.target` and nothing else, because what CoreDNS must start before is a site decision. Add your own ordering with a drop-in rather than replacing the unit:

```yaml
systemd:
  units:
    - name: coredns.service
      enabled: true
      dropins:
        - name: 10-local-ordering.conf
          contents: |
            [Unit]
            Wants=sys-devices-virtual-net-nodelocal0.device
            After=sys-devices-virtual-net-nodelocal0.device
            Before=consul.service
```

The extension does not start CoreDNS by itself. It ships no `multi-user.target.upholds` drop-in, so a node that merges the image before its `Corefile` exists does not get a failing service. Enable the unit when the config is in place, as the snippet below does.

The extension also does not touch `systemd-resolved`. Whether CoreDNS replaces the stub resolver is up to you.

## Usage

Download and merge the sysext at provisioning time using the below Butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates, refresh the merged sysext, and restart `coredns.service` — no reboot is required.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of CoreDNS v1.14.7.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/coredns for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/coredns/coredns-v1.14.7-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/coredns-v1.14.7-x86-64.raw
    - path: /etc/sysupdate.coredns.d/coredns.conf
      contents:
        source: https://extensions.flatcar.org/extensions/coredns.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
    - path: /etc/coredns/Corefile
      mode: 0644
      contents:
        inline: |
          .:53 {
              errors
              health
              ready
              forward . 9.9.9.9 1.1.1.1
              cache 30
              loop
              reload
          }
  links:
    - target: /opt/extensions/coredns/coredns-v1.14.7-x86-64.raw
      path: /etc/extensions/coredns.raw
      hard: false
systemd:
  units:
    - name: coredns.service
      enabled: true
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: coredns.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/coredns.raw > /run/coredns-sysext"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C coredns update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/coredns.raw > /run/coredns-sysext-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /run/coredns-sysext /run/coredns-sysext-new; then systemd-sysext refresh && systemctl restart coredns.service; fi"
```

## Testing a built image

`coredns.sysext/test.sh` checks a locally built image:

```bash
./bakery.sh create coredns v1.14.7
./coredns.sysext/test.sh coredns.raw
```

It asserts the binary is present and executable, that `coredns -version` runs when the image architecture matches the host, and that the image contains no path outside `/usr`.
