# Bird sysext

This extension ships [BIRD](https://bird.network.cz/).

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

The bird configuration needs to be added under `/etc/bird/`. This sysext does not ship a default configuration.

Generic configration:
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/bird/bird-3.1.1-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/bird-3.1.1-x86-64.raw
    - path: /etc/sysupdate.bird.d/bird.conf
      contents:
        source: https://extensions.flatcar.org/extensions/bird/bird.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/bird/bird-3.1.1-x86-64.raw
      path: /etc/extensions/bird.raw
      hard: false
    - path: /etc/systemd/system/multi-user.target.wants/bird.service
      target: /usr/lib/systemd/system/bird.service
      overwrite: true
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: bird.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bird.raw > /tmp/bird"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C bird update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/bird.raw > /tmp/bird-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/bird /tmp/bird-new; then touch /run/reboot-required; fi"
```


To add the configuration you can for example add the following to `storage.files`:
```yaml
    - path: /etc/bird/bird.conf
      mode: 0644
      content:
        inline: |
          # This is a basic configuration file, which contains boilerplate options and
          # some basic examples. It allows the BIRD daemon to start but will not cause
          # anything else to happen.
          #
          # Please refer to the BIRD User's Guide documentation, which is also available
          # online at http://bird.network.cz/ in HTML format, for more information on
          # configuring BIRD and adding routing protocols.

          # Configure logging
          log syslog all;

          # The Device protocol is not a real routing protocol. It does not generate any
          # routes and it only serves as a module for getting information about network
          # interfaces from the kernel. It is necessary in almost any configuration.
          protocol device {
          }

          # The direct protocol is not a real routing protocol. It automatically generates
          # direct routes to all network interfaces. Can exist in as many instances as you
          # wish if you want to populate multiple routing tables with direct routes.
          protocol direct {
            disabled;		# Disable by default
            ipv4;			# Connect to default IPv4 table
            ipv6;			# ... and to default IPv6 table
          }

          # The Kernel protocol is not a real routing protocol. Instead of communicating
          # with other routers in the network, it performs synchronization of BIRD
          # routing tables with the OS kernel. One instance per table.
          protocol kernel {
            ipv4 {			# Connect protocol to IPv4 table by channel
                  export all;	# Export to protocol. default is export none
            };
          }

          # Another instance for IPv6, skipping default options
          protocol kernel {
            ipv6 { export all; };
          }

          # Static routes (Again, there can be multiple instances, for different address
          # families and to disable/enable various groups of static routes on the fly).
          protocol static {
            ipv4;			# Again, IPv4 channel with default options
```
