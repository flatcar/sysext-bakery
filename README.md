# sysext-bakery: Recipes for baking systemd-sysext images

[Systemd-sysext images](https://www.freedesktop.org/software/systemd/man/systemd-sysext.html) are overlay images for `/usr`, allowing to extend the base OS with custom (static) binaries.
Flatcar Container Linux as an OS without a package manager is a good fit for extension through systemd-sysext.
The tools in this repository help you to create your own sysext images bundeling software to extend your base OS.
The current focus is on Docker and containerd, contributions are welcome for other software.
See the section at the end on how to bundle any software with the Flix and Flatwrap tools.

## Systemd-sysext

The `NAME.raw` sysext images (or `NAME` sysext directories) can be placed under `/etc/extensions/` or `/var/lib/extensions` to be activated on boot by `systemd-sysext.service`.
Images can specify to require systemd to do a daemon reload (needs systemd 255, Flatcar ships `ensure-sysext.service` as workaround to automatically load the image's services).

A current limitation of `systemd-sysext` is that you need to use `TARGET.upholds` symlinks (supported from systemd 254, similar to `.wants`) or `Upholds=` drop-ins for the target units to start your units.
For current versions of Flatcar (systemd 252) you need to use `systemctl restart systemd-sysext ensure-sysext` to reload the sysext images and start the services and a manual `systemd-sysext refresh` is not recommended.

The compatibility mechanism of sysext images requires a metadata file in the image under `usr/lib/extension-release.d/extension-release.NAME`.
It needs to contain a matching OS `ID`, and either a matching `VERSION_ID` or `SYSEXT_LEVEL`. Here you can also set `EXTENSION_RELOAD_MANAGER=1` for a systemd daemon reload.
Since the rapid release cycle and automatic updates of Flatcar Container Linux make it hard to rely on particular OS libraries by specifying a dependency of the sysext image to the OS version, it is not recommended to match by `VERSION_ID`.
Instead, Flatcar defined the `SYSEXT_LEVEL` value `1.0` to match for.
You can also use `ID=_any` and then neither `SYSEXT_LEVEL` nor `VERSION_ID` are needed.
The sysext image should only include static binaries.

Inside the image, binaries should be placed under `usr/bin/` and systemd units under `usr/lib/systemd/system/`.
While placing symlinks in the image itself to enable the units in the same way as systemd would normally do (like `sockets.target.wants/my.socket` → `../my.socket`) is still currently supported, this is not a recommended practice.
The recommended way is to ship drop-ins for the target units that start your unit.
The drop-in file should use the `Upholds=` property in the `[Unit]` section.
For example, for starting `docker.socket` we would use a drop-in for `sockets.target` placed in `usr/lib/systemd/system/sockets.target.d/10-docker-socket.conf` with the following contents:

```
[Unit]
Upholds=docker.socket
```

This can be done also for services, so for `docker.service` started by `multi-user.target`, the drop-in would reside in `usr/lib/systemd/system/multi-user.target.d/10-docker-service.conf` and it would have a `Upholds=docker.service` line instead.


The following Butane Config (YAML) can be be transpiled to Ignition JSON and will download a custom Docker+containerd sysext image on first boot.
It also takes care of disabling Torcx and future inbuild Docker and containerd sysext images we plan to ship in Flatcar.
If your sysext image doesn't replace Flatcar's inbuilt Docker/containerd, omit the two `links` entries and the `torcx-generator` entry.

```
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /etc/extensions/mydocker.raw
      contents:
        source: https://myserver.net/mydocker.raw
    - path: /etc/systemd/system-generators/torcx-generator
  links:
    - path: /etc/extensions/docker-flatcar.raw
      target: /dev/null
      overwrite: true
    - path: /etc/extensions/containerd-flatcar.raw
      target: /dev/null
      overwrite: true
```

## Systemd-sysext on other distributions

The tools here will by default build for any OS and create the metadata file `usr/lib/extension-release.d/extension-release.NAME` as follows:

```
ID=_any
# Depending on the image, e.g., for Docker systemd units, there is also:
# EXTENSION_RELOAD_MANAGER=1
```

Use the configuration parameters in the tools to build for your distribution (pass `OS=` to be the OS ID from `/etc/os-release`) or to build for any distribution (pass `OS=_any`).
You can also set the architecture to be arm64 to fetch the right binaries and encode this information in the sysext image metadata.

## Recipes in this repository

The tools normally generate squashfs images not only because of the compression benefits but also because it doesn't need root permissions and loop device mounts.

### Available Extensions

The following table shows which build recipes exist and for which the GitHub Release publishes updatable images.
While the goal is to automate the release pipeline to detect latest versions and have weekly releases, currently the release trigger is manual and all version updates except Kubernetes are also manual.
For extensions that are not part of the GitHub Release or which you want to customize, you can build your own images and host them elsewhere - the easiest is to fork this repo and modify the `release_build_versions.txt` file and create a new `latest` tag.

| Extension | Availability |
| --- | --- |
| `kubernetes` | released |
| `docker` | released (includes containerd) |
| `docker_compose` | released |
| `wasmtime` | released |
| `wasmcloud` | released |
| `tailscale` | released |
| `crio` | released |
| `k3s` | released |
| `rke2` | released |
| `keepalived` | build script |


### Consuming the published images

There is a Github Action to build current recipes and to publish the built images as release artifacts. It's possible to directly consume the latest release from a Butane/Ignition configuration, example:
```yaml
# butane < config.yaml > config.json
# ./flatcar_production_qemu.sh -i ./config.json
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /opt/extensions/wasmtime/wasmtime-17.0.1-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmtime-17.0.1-x86-64.raw
    - path: /opt/extensions/docker/docker-24.0.9-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/docker-24.0.9-x86-64.raw
    - path: /etc/systemd/system-generators/torcx-generator
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
    - path: /etc/sysupdate.wasmtime.d/wasmtime.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmtime.conf
    - path: /etc/sysupdate.docker.d/docker.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/docker.conf
  links:
    - target: /opt/extensions/wasmtime/wasmtime-17.0.1-x86-64.raw
      path: /etc/extensions/wasmtime.raw
      hard: false
    - target: /opt/extensions/docker/docker-24.0.9-x86-64.raw
      path: /etc/extensions/docker.raw
      hard: false
    - path: /etc/extensions/docker-flatcar.raw
      target: /dev/null
      overwrite: true
    - path: /etc/extensions/containerd-flatcar.raw
      target: /dev/null
      overwrite: true
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmtime.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmtime update
        - name: docker.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C docker update
        - name: sysext.conf
          contents: |
            [Service]
            ExecStartPost=systemctl restart systemd-sysext
```

This also configures systemd-sysupdate for auto-updates. The `noop.conf` is a workaround for systemd-sysupdate to run without error messages.
Since the configuration sets up a custom Docker version, it also disables Torcx and the future `docker-flatcar` and `containerd-flatcar` extensions to prevent conflicts.

Here a template for a single extension where you have to replace `NAME`, `VERSION`, and `ARCH`:

```yaml
# butane < config.yaml > config.json
# ./flatcar_production_qemu.sh -i ./config.json
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /opt/extensions/NAME/NAME-VERSION-ARCH.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/NAME-VERSION-ARCH.raw
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
    - path: /etc/sysupdate.NAME.d/NAME.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/NAME.conf
  links:
    - target: /opt/extensions/NAME/NAME-VERSION-ARCH.raw
      path: /etc/extensions/NAME.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: NAME.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C NAME update
        - name: sysext.conf
          contents: |
            [Service]
            ExecStartPost=systemctl restart systemd-sysext
```

In the [Flatcar docs](https://www.flatcar.org/docs/latest/provisioning/sysext/) you can find an Ignition configuration that explicitly sets the update configurations instead of downloading them.

The updates works by [`systemd-sysupdate`](https://www.freedesktop.org/software/systemd/man/sysupdate.d.html) fetching the `SHA256SUMS` file of the generated artifacts, which holds the list of built images with their respective SHA256 digest.

#### Kubernetes

The [Flatcar Kubernetes docs](https://www.flatcar.org/docs/latest/container-runtimes/getting-started-with-kubernetes/) show how to use the extension provided here for controllers and workers.

#### wasmcloud

For another example of how you can further customize the recipes provided in this repository, the following recipe uses the image built with `create_wasmcloud_sysext.sh`:
```yaml
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /opt/extensions/wasmcloud/wasmcloud-1.0.0-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmcloud-1.0.0-x86-64.raw
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
    - path: /etc/sysupdate.wasmcloud.d/wasmcloud.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/wasmcloud.conf
    - path: /etc/nats-server.conf
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
      contents:
        inline: |
          <redacted>
  links:
    - target: /opt/extensions/wasmcloud/wasmcloud-1.0.0-x86-64.raw
      path: /etc/extensions/wasmcloud.raw
      hard: false
systemd:
  units:
    - name: nats.service
      enabled: true
      dropins:
        - name: 10-nats-env-override.conf
          contents: |
            [Service]
            Environment=NATS_CONFIG=/etc/nats-server.conf
    - name: wasmcloud.service
      enabled: true
      dropins:
        - name: 10-wasmcloud-env-override.conf
          contents: |
            [Service]
            Environment=WASMCLOUD_LATTICE=<redacted>
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: wasmcloud.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C wasmcloud update
        - name: sysext.conf
          contents: |
            [Service]
            ExecStartPost=systemctl restart systemd-sysext
```

This example uses Butane/Ignition configuration do the following customizations beyond simply including the image:

1. Provide a different configuration to setup the nats-server to act as a leaf node to a pre-existing wasmCloud deployment (`/etc/nats-server.conf`).
2. Provide a set of credentials for the nats-server leaf node to connect with (`/etc/nats.creds`).
3. Override the bundled `NATS_CONFIG` environment variable to point it to the newly created configuration (`NATS_CONFIG=/etc/nats-server.conf`).
4. Override the lattice the wasmCloud host is configured to connect (`WASMCLOUD_LATTICE=<redacted>`).

#### k3s

The k3s sysext can be configured by using the following snippet, in case you
want this to be a k3s server (controlplane):

```yaml
variant: flatcar
version: 1.0.0
storage:
  files:
    # filename needs to be k3s.raw
    - path: /etc/extensions/k3s.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/k3s-v1.29.2+k3s1-x86-64.raw
  links:
    - path: /etc/systemd/system/multi-user.target.wants/k3s.service
      target: /usr/local/lib/systemd/system/k3s.service
      overwrite: true
```

Please note that this way you will not get automatic updates via
`systemd-sysupdate`.

For a k3s agent (worker node) you would use something like this snippet:

```yaml
variant: flatcar
version: 1.0.0
storage:
  files:
    # filename needs to be k3s.raw
    - path: /etc/extensions/k3s.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/k3s-v1.29.2+k3s1-x86-64.raw
  links:
    - path: /etc/systemd/system/multi-user.target.wants/k3s-agent.service
      target: /usr/local/lib/systemd/system/k3s-agent.service
      overwrite: true
```

Of course, any configuration you need should be prepared before starting the
services, like providing a token for an agent or server to join or creating a
`config.yaml` file.

#### rke2

The rke2 sysext can be configured by using the following snippet, in case you
want this to be a rke2 server (controlplane):

```yaml
variant: flatcar
version: 1.0.0
storage:
  links:
    # filename needs to be rke2.raw
    - path: /etc/extensions/rke2.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/rke2-v1.29.2+rke2r1-x86-64.raw
    - path: /etc/systemd/system/multi-user.target.wants/rke2-server.service
      target: /usr/local/lib/systemd/system/rke2-server.service
      overwrite: true
```

Please note that this way you will not get automatic updates via
`systemd-sysupdate`.

For a rke2 agent (worker node) you would use something like this snippet:

```yaml
variant: flatcar
version: 1.0.0
storage:
  links:
    # filename needs to be rke2.raw
    - path: /etc/extensions/rke2.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/rke2-v1.29.2+rke2r1-x86-64.raw
    - path: /etc/systemd/system/multi-user.target.wants/rke2-agent.service
      target: /usr/local/lib/systemd/system/rke2-agent.service
      overwrite: true
```

Of course, any configuration you need should be prepared before starting the
services, like providing a token for an agent or server to join or creating a
`config.yaml` file.

#### Tailscale

The Tailscale sysext ships a service unit but doesn't pre-enable it.
You can use this Butane snippet to enable it:

```
variant: flatcar
version: 1.0.0
storage:
  links:
    - path: /etc/systemd/system/multi-user.target.wants/tailscaled.service
      target: /usr/local/lib/systemd/system/tailscaled.service
      overwrite: true
```

### Creating a custom Docker sysext image

The Docker releases publish static binaries including containerd and the only missing piece are the systemd units.
To ease the process, the `create_docker_sysext.sh` helper script takes care of downloading the release binaries and adding the systemd unit files, and creates a combined Docker+containerd sysext image:

```
./create_docker_sysext.sh 24.0.9 mydocker
[… writes mydocker.raw into current directory …]
```

Pass the `OS` or `ARCH` environment variables to build for another target than Flatcar amd64, e.g., for any distro with arm64:

```
OS=_any ARCH=arm64 ./create_docker_sysext.sh 24.0.9 mydocker
[… writes mydocker.raw into current directory …]
```

See the above intro section on how to use the resulting sysext image.

You can also limit the sysext image to only Docker (without containerd and runc) or only containerd (no Docker but runc) by passing the environment variables `ONLY_DOCKER=1` or `ONLY_CONTAINERD=1`.
If you build both sysext images that way, you can load both combined and, e.g., only load the Docker sysext image for debugging while using the containerd sysext image by default for Kubernetes.

### Baking sysexts into Flatcar OS images

Using the `bake_flatcar_image.sh` script, custom Flatcar OS images can be created which include one or more sysexts.
The script will download a Flatcar OS release image, insert the desired sysexts, and optionally create a vendor (public / private cloud or bare metal) image.

By default, the script operates with local sysexts (and optionally sysupdate configurations if present).
However, the `--fetch` option may be specified to fetch the sysext `.raw` file and sysupdate config from the latest Bakery release.

Sysexts can be added to the root partition or the OEM partition of the OS image (root is preferred).
Read more about Flatcar's OS image disk layout here: https://www.flatcar.org/docs/latest/reference/developer-guides/sdk-disk-partitions/

The script requires sudo access at certain points to manage loopback mounts for the OS image partitions and will then prompt for a password.

Refer to `./bake_flatcar_image.sh --help` for more information.

Example usage:
```
./bake_flatcar_image.sh --fetch --vendor qemu_uefi wasmtime:wasmtime-17.0.1-x86-64.raw
```

Example usage with local sysext:
```
ls -1
  myext-1.0.1-x86-64.raw
  myext.conf
./bake_flatcar_image.sh --fetch --vendor qemu_uefi myext:myext-1.0.1-x86-64.raw
```

The script supports all vendors and clouds natively supported by Flatcar.

### Flix and Flatwrap

The Flix and Flatwrap tools both convert a given chroot folder into a systemd-sysext image.
You have to specify which files should be made available to the host.

The Flix tool rewrites specified binaries to use a custom library path.
You also have to specify needed resource folders and you can specify systemd units, too.

Here examples with Flix:

```
CMD="apk -U add b3sum" ./oci-rootfs.sh alpine:latest /var/tmp/alpine-b3sum
./flix.sh /var/tmp/alpine-b3sum/ b3sum /usr/bin/b3sum /bin/busybox:/usr/bin/busybox
# got b3sum.raw

CMD="apt-get update && apt install -y nginx" ./oci-rootfs.sh debian /var/tmp/debian-nginx
./flix.sh /var/tmp/debian-nginx/ nginx /usr/sbin/nginx /usr/sbin/start-stop-daemon /usr/lib/systemd/system/nginx.service
# got nginx.raw

# Note: Enablement of nginx.service with Butane would happen as in the k3s example
# but you can also pre-enable the service inside the extension.
# Here a non-production nginx test config if you want to try the above:
$ cat /etc/nginx/nginx.conf
user root;
pid /run/nginx.pid;

events {
}

http {
  access_log /dev/null;
  proxy_temp_path /tmp;
  client_body_temp_path /tmp;
  fastcgi_temp_path /tmp;
  uwsgi_temp_path /tmp;
  scgi_temp_path /tmp;
  server {
        server_name   localhost;
        listen        127.0.0.1:80;
  }
}
```

The Flatwrap tool generates entry point wrappers for a chroot with `unshare` or `bwrap`.
You can specify systemd units, too. By default `/etc`, `/var`, and `/home` are mapped from the host but that is configurable (see `--help`).

Here examples with Flatwrap:

```
CMD="apk -U add b3sum" ./oci-rootfs.sh alpine:latest /var/tmp/alpine-b3sum
./flatwrap.sh /var/tmp/alpine-b3sum b3sum /usr/bin/b3sum /bin/busybox:/usr/bin/busybox
# got b3sum.raw

CMD="apk -U add htop" ./oci-rootfs.sh alpine:latest /var/tmp/alpine-htop
# Use ETCMAP=chroot because alpine's htop needs alpine's /etc/terminfo
ETCMAP=chroot ./flatwrap.sh /var/tmp/alpine-htop htop /usr/bin/htop
# got htop.raw

CMD="apt-get update && apt install -y nginx" ./oci-rootfs.sh debian /var/tmp/debian-nginx
./flatwrap.sh /var/tmp/debian-nginx/ nginx /usr/sbin/nginx /usr/sbin/start-stop-daemon /usr/lib/systemd/system/nginx.service
# got nginx.raw

# Note: Enablement of nginx.service with Butane would happen as in the k3s example
# but you can also pre-enable the service inside the extension.
# (The "non-production" nginx test config above can be used here, too, stored on the host's /etc.)
```

### Converting a Torcx image

Torcx was a solution for switching between different Docker versions on Flatcar.
In case you have an existing Torcx image you can convert it with the `convert_torcx_image.sh` helper script (Currently only Torcx tar balls are supported and the conversion is done on best effort):

```
./convert_torcx_image.sh TORCXTAR SYSEXTNAME
[… writes SYSEXTNAME.raw into the current directory …]
```

Please make also sure that your don't have a `containerd.service` drop in file under `/etc` that uses Torcx paths.

## For maintainers: how to release?

CI can be kicked-off by overriding the `latest` tag. The `latest` release artifacts will be updated consequently here: https://github.com/flatcar/sysext-bakery/releases/tag/latest
```
git checkout main
git pull --ff-only
git tag -d latest
git tag -as latest
git push origin --force latest
```
