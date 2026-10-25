# Uncloud sysext

This sysext ships [Uncloud](https://github.com/psviderski/uncloud), a tool that deploys and runs containers on a cluster of Docker hosts, without a control plane.

The sysext includes the Uncloud machine daemon (`uncloudd`), the `uc` command line tool, and the `uncloud.socket` and `uncloud.service` units.
The daemon starts at boot and uses the Docker included in Flatcar.
The sysext also creates the `uncloud` system user and group.

## Usage

Download and merge the sysext at provisioning time using the below butane snippet.

The snippet includes automated updates via systemd-sysupdate.
Sysupdate will stage updates and request a reboot by creating a flag file at `/run/reboot-required`.
You can deactivate updates by changing `enabled: true` to `enabled: false` in `systemd-sysupdate.timer`.

Note: the snippet is for the x86-64 version of Uncloud v0.21.0.

Check out the metadata release at https://github.com/flatcar/sysext-bakery/releases/tag/uncloud for a list of all versions available in the bakery.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/uncloud/uncloud-v0.21.0-x86-64.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/uncloud-v0.21.0-x86-64.raw
    - path: /etc/sysupdate.uncloud.d/uncloud.conf
      contents:
        source: https://extensions.flatcar.org/extensions/uncloud.conf
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://extensions.flatcar.org/extensions/noop.conf
  links:
    - target: /opt/extensions/uncloud/uncloud-v0.21.0-x86-64.raw
      path: /etc/extensions/uncloud.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: uncloud.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/uncloud.raw > /tmp/uncloud"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C uncloud update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/uncloud.raw > /tmp/uncloud-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/uncloud /tmp/uncloud-new; then touch /run/reboot-required; fi"
```

## Create a cluster

By default, `uc machine init` and `uc machine add` run the Uncloud install script on the machine over SSH.
The sysext already installs everything, so pass `--no-install` to skip that step:

```sh
uc machine init core@<flatcar-ip> --no-install
uc machine add core@<flatcar-ip-2> --no-install
```

`uc` connects to the Uncloud API socket (`/run/uncloud/api/uncloud.sock`) through SSH, so the SSH user must be a member of the `uncloud` group.
The sysext adds the default `core` user to that group.
To use another SSH user, add it to the group after systemd-sysext merges the sysext, eg. `sudo gpasswd --add deploy uncloud`.

## Docker configuration

`uc image push` needs Docker to use the [containerd image store](https://docs.docker.com/engine/storage/containerd/).
`uc deploy` needs it too when it pushes a locally built image.
Docker 29 and newer use it by default on new installs, eg. Flatcar Beta 4820.1.0 ships Docker 29.8.0.
Older Docker releases do not, eg. Flatcar Stable 4757.2.2 ships Docker 28.2.2.
Check your machine with:

```sh
docker info | grep driver-type
```

The command must print `driver-type: io.containerd.snapshotter.v1`.
If it prints nothing, enable the containerd image store with the below butane snippet:

```yaml
storage:
  files:
    - path: /etc/docker/daemon.json
      mode: 0644
      contents:
        inline: |
          {
            "features": {
              "containerd-snapshotter": true
            }
          }
```
