# sysext-bakery: Recipes for baking systemd-sysext images

[Systemd-sysext images](https://www.freedesktop.org/software/systemd/man/systemd-sysext.html) are overlay images for `/usr`, allowing to extend the base OS with custom (static) binaries.
Flatcar Container Linux as an OS without a package manager is a good fit for extension through systemd-sysext.
The tools in this repository help you to create your own sysext images bundeling software to extend your base OS.
The current focus is on Docker and containerd, contributions are welcome for other software.

## Systemd-sysext

The `NAME.raw` sysext images (or `NAME` sysext directories) can be placed under `/etc/extensions/` or `/var/lib/extensions` to be activated on boot by `systemd-sysext.service`.
While systemd-sysext images are not really meant to also include the systemd service, Flatcar ships `ensure-sysext.service` as workaround to automatically load the image's services.
This helper service is bound to `systemd-sysext.service` which activates the sysext images on boot.
Currently it reloads the unit files from disk and reevaluates `multi-user.target`, `sockets.target`, and `timers.target`, making sure your enabled systemd units run.
In the future `systemd-sysext` will only reload the unit files when this is upstream behavior (the current upstream behavior is to do nothing and leave it to the user).
That means you need to use `Upholds=` drop-ins for the target units to start your units.
At runtime executing `systemctl restart systemd-sysext ensure-sysext` will reload the sysext images and start the services.
A manual `systemd-sysext refresh` is not recommended.

The compatibility mechanism of sysext images requires a metadata file in the image under `usr/lib/extension-release.d/extension-release.NAME`.
It needs to contain a matching OS `ID`, and either a matching `VERSION_ID` or `SYSEXT_LEVEL`.
Since the rapid release cycle and automatic updates of Flatcar Container Linux make it hard to rely on particular OS libraries by specifying a dependency of the sysext image to the OS version, it is not recommended to match by `VERSION_ID`.
Instead, Flatcar defined the `SYSEXT_LEVEL` value `1.0` to match for.
With systemd 252 you can also use `ID=_any` and then neither `SYSEXT_LEVEL` nor `VERSION_ID` are needed.
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

The tools here will by default build for Flatcar and create the metadata file `usr/lib/extension-release.d/extension-release.NAME` as follows:

```
ID=flatcar
SYSEXT_LEVEL=1.0
```

This means other distributions will reject to load the sysext image by default.
Use the configuration parameters in the tools to build for your distribution (pass `OS=` to be the OS ID from `/etc/os-release`) or to build for any distribution (pass `OS=_any`).
You can also set the architecture to be arm64 to fetch the right binaries and encode this information in the sysext image metadata.

To add the automatic systemd unit loading to your distribution, store [`ensure-sysext.service`](https://raw.githubusercontent.com/flatcar/init/ccade77b6d568094fb4e4d4cf71b867819551798/systemd/system/ensure-sysext.service) in your systemd folder (e.g., `/etc/systemd/system/`) and enable the units: `systemctl enable --now ensure-sysext.service systemd-sysext.service`.

## Recipes in this repository

The tools normally generate squashfs images not only because of the compression benefits but also because it doesn't need root permissions and loop device mounts.

### Consuming the published images

There is a Github Action to build current recipes and to publish the built images as release artifacts. It's possible to directly consume the latest release from a Butane/Ignition configuration, example:
```yaml
# butane < config.yaml > config.json
# ./flatcar_production_qemu.sh -i ./config.json
variant: flatcar
version: 1.0.0
storage:
  files:
    - path: /opt/extensions/docker/docker-24.0.5-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/docker-24.0.5-x86-64.raw
    - path: /opt/extensions/kubernetes/kubernetes-v1.27.4-x86-64.raw
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/kubernetes-v1.27.4-x86-64.raw
    - path: /etc/systemd/system-generators/torcx-generator
    - path: /etc/sysupdate.d/noop.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/noop.conf
    - path: /etc/sysupdate.docker.d/docker.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/docker.conf
    - path: /etc/sysupdate.kubernetes.d/kubernetes.conf
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/kubernetes.conf
  links:
    - target: /opt/extensions/docker/docker-24.0.5-x86-64.raw
      path: /etc/extensions/docker.raw
      hard: false
    - target: /opt/extensions/kubernetes/kubernetes-v1.27.4-x86-64.raw
      path: /etc/extensions/kubernetes.raw
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
        - name: docker.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C docker update
        - name: kubernetes.conf
          contents: |
            [Service]
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C kubernetes update
        - name: sysext.conf
          contents: |
            [Service]
            ExecStartPost=systemctl restart systemd-sysext
```

This also configures systemd-sysupdate for auto-updates. The `noop.conf` is a workaround for systemd-sysupdate to run without error messages.
Since the configuration sets up a custom Docker version, it also disables Torcx and the future `docker-flatcar` and `containerd-flatcar` extensions to prevent conflicts.

In the [Flatcar docs](https://www.flatcar.org/docs/latest/provisioning/sysext/) you can find an Ignition configuration that explicitly sets the update configurations instead of downloading them.

The updates works by [`systemd-sysupdate`](https://www.freedesktop.org/software/systemd/man/sysupdate.d.html) fetching the `SHA256SUMS` file of the generated artifacts, which holds the list of built images with their respective SHA256 digest.

### Creating a custom Docker sysext image

The Docker releases publish static binaries including containerd and the only missing piece are the systemd units.
To ease the process, the `create_docker_sysext.sh` helper script takes care of downloading the release binaries and adding the systemd unit files, and creates a combined Docker+containerd sysext image:

```
./create_docker_sysext.sh 20.10.13 mydocker
[… writes mydocker.raw into current directory …]
```

Pass the `OS` or `ARCH` environment variables to build for another target than Flatcar amd64, e.g., for any distro with arm64:

```
OS=_any ARCH=arm64 ./create_docker_sysext.sh 20.10.13 mydocker
[… writes mydocker.raw into current directory …]
```

See the above intro section on how to use the resulting sysext image.

You can also limit the sysext image to only Docker (without containerd and runc) or only containerd (no Docker but runc) by passing the environment variables `ONLY_DOCKER=1` or `ONLY_CONTAINERD=1`.
If you build both sysext images that way, you can load both combined and, e.g., only load the Docker sysext image for debugging while using the containerd sysext image by default for Kubernetes.

### Converting a Torcx image

Torcx was a solution for switching between different Docker versions on Flatcar.
In case you have an existing Torcx image you can convert it with the `convert_torcx_image.sh` helper script (Currently only Torcx tar balls are supported and the conversion is done on best effort):

```
./convert_torcx_image.sh TORCXTAR SYSEXTNAME
[… writes SYSEXTNAME.raw into the current directory …]
```

Please make also sure that your don't have a `containerd.service` drop in file under `/etc` that uses Torcx paths.
