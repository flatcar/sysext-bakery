# Wasmcloud sysext

This sysext ships [wasmcloud](https://wasmcloud.com/).

The sysext includes a service unit file to start the `wasmcloud` and `nats` services at boot.
Basic customisation options are discussed in the "Usage" section below.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will **merge the new sysext immediately after successful download**.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note that the snippet is for the x86-64 version of wasmcloud 1.7.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/wasmcloud for a list of all versions available in the bakery.

The following customisations have been made (see comments in the config snippet)

1. Provide a different configuration to setup the nats-server to act as a leaf node to a pre-existing wasmCloud deployment (`/etc/nats-server.conf`).
2. Provide a set of credentials for the nats-server leaf node to connect with (`/etc/nats.creds`).
3. Override the bundled `NATS_CONFIG` environment variable to point it to the newly created configuration (`NATS_CONFIG=/etc/nats-server.conf`).
4. Override the lattice the wasmCloud host is configured to connect (`WASMCLOUD_LATTICE=<redacted>`).

```yaml
variant: flatcar
version: 1.0.0

storage:
  links:
    - target: /opt/extensions/wasmcloud/wasmcloud-v1.7.0-x86-64.raw
      path: /etc/extensions/wasmcloud.raw
      hard: false
  files:
    - path: /opt/extensions/wasmcloud/wasmcloud-v1.7.0-x86-64.raw
      contents:
        source: https://extensions.flatcar.org/extensions/wasmcloud-v1.7.0-x86-64.raw
    - path: /etc/sysupdate.wasmcloud.d/wasmcloud.conf
      contents:
        source: https://extensions.flatcar.org/extensions/wasmcloud.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
      source: https://extensions.flatcar.org/extensions/noop.conf
  #
  # Custom WasmCloud Config
  #
  files:
    - path: /etc/nats-server.conf
      # NATS server leaf node config
      contents:
        inline: |
          jetstream {
            domain: default
          }
          leafnodes {
              remotes = [
                  {
                      url: "tls://connect.cosmonic.sh"
                      credentials: "/etc/nats.creds"
                  }
              ]
          }
    - path: /etc/nats.creds
      # NATS server cretentials. TODO: actually add the credentials.
      contents:
        inline: |
          <redacted>
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmcloud.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmcloud.raw > /tmp/wasmcloud"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmcloud update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/wasmcloud.raw > /tmp/wasmcloud-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/wasmcloud /tmp/wasmcloud-new; then systemd-sysext refresh; fi"

    #
    # Custom WasmCloud Config
    #
    - name: nats.service
      enabled: true
      dropins:
        - name: 10-nats-env-override.conf
          contents: |
            [Service]
            Environment=NATS_CONFIG=/etc/nats-server.conf
    - name: wasmcloud.service
      # Wasmcloud env override. TODO: add lattice.
      enabled: true
      dropins:
        - name: 10-wasmcloud-env-override.conf
          contents: |
            [Service]
            Environment=WASMCLOUD_LATTICE=<redacted>
```

