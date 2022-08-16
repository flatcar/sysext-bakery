# sysext-bakery: Recipes for baking systemd-sysext images

[Systemd-sysext images](https://www.freedesktop.org/software/systemd/man/systemd-sysext.html) are overlay images for `/usr`, allowing to extend the base OS with custom (static) binaries.
Flatcar Container Linux as an OS without a package manager is a good fit for extension through systemd-sysext.
The tools in this repository help you to create your own sysext images bundeling software to extend your base OS.
The current focus is on Docker and containerd, contributions are welcome for other software.

## Systemd-sysext on Flatcar

The `NAME.raw` sysext images (or `NAME` sysext directories) can be placed under `/etc/extensions/` or `/var/lib/extensions` in Flatcar to be activated on boot.
While systemd-sysext images are not really meant to also include the systemd service, Flatcar ships `ensure-sysext.service` as workaround to automatically load the image's services.
It reloads the unit files from disk and reevaluates `multi-user.target`, `sockets.target`, and `timers.target`, making sure your enabled systemd units run.
This service is bound to `systemd-sysext.service` which activates the sysext images on boot.
At runtime executing `systemctl restart systemd-sysext` will reload the sysext images and start the services.
A manual `systemd-sysext refresh` is not recommended.

The compatibility mechanism of sysext images requires a metadata file in the image under `usr/lib/extension-release.d/extension-release.NAME`.
It has to contain a matching OS `ID`, and either a matching `VERSION` or `SYSEXT_LEVEL`.
Since the rapid release cycle and automatic updates of Flatcar Container Linux make it hard to rely on particular OS libraries by specifying a dependency of the sysext image to the OS version, it is not recommended to match by `VERSION`.
Instead, Flatcar defined the `SYSEXT_LEVEL` value `1.0` to match for.
The sysext image should only include static binaries.

Inside the image, binaries should be placed under `usr/bin/` and systemd units under `usr/lib/systemd/system/`.
To enable systemd units, symlinks should be included in the image itself in the same way as systemd would normally generate them when enabling the units, e.g., `sockets.target.wants/my.socket` → `../my.socket`.

The following Container Linux Config (CLC YAML) can be be transpiled to Ignition JSON and will download a custom Docker+containerd sysext image on first boot.
It also takes care of disabling Torcx and future inbuild Docker and containerd sysext images we plan to ship in Flatcar.
If your sysext image doesn't replace Flatcar's inbuilt Docker/containerd, omit the two `links` entries and the `torcx-generator` entry.

```
storage:
  files:
    - path: /etc/extensions/mydocker.raw
      filesystem: root
      mode: 0644
      contents:
        remote:
          url: https://myserver.net/mydocker.raw
    - path: /etc/systemd/system-generators/torcx-generator
  directories:
    - path: /etc/extensions/docker-flatcar
    - path: /etc/extensions/containerd-flatcar
```

## Systemd-sysext on other distributions

The tools here will by default build for Flatcar and create the metadata file `usr/lib/extension-release.d/extension-release.NAME` as follows:

```
ID=flatcar
SYSEXT_LEVEL=1.0
```

This means other distributions will reject to load the sysext image by default.
Use the configuration parameters in the tools to build for your distribution.

To add the automatic systemd unit loading to your distribution, store [`ensure-sysext.service`](https://raw.githubusercontent.com/flatcar-linux/init/a22b550c7cf689661970a2a23dd457870dd84c97/systemd/system/ensure-sysext.service) in your systemd folder (e.g., `/etc/systemd/system/`) and enable the units: `systemctl enable --now ensure-sysext.service systemd-sysext.service`.

## Recipes in this repository

The tools normally generate squashfs images not only because of the compression benefits but also because it doesn't need root permissions and loop device mounts.

### Creating a custom Docker sysext image

The Docker releases publish static binaries including containerd and the only missing piece are the systemd units.
To ease the process, the `create_docker_sysext.sh` helper script takes care of downloading the release binaries and adding the systemd unit files, and creates a combined Docker+containerd sysext image:

```
./create_docker_sysext.sh 20.10.13 mydocker
[… writes mydocker.raw into current directory …]
```

Pass the `OS` or `ARCH` environment variables to build for another target than Flatcar amd64, e.g., for Fedora arm64:

```
OS=fedora ARCH=aarch64 ./create_docker_sysext.sh 20.10.13 mydocker
[… writes mydocker.raw into current directory …]
```

See the above intro section on how to use the resulting sysext image.

### Converting a Torcx image

Torcx was a solution for switching between different Docker versions on Flatcar.
In case you have an existing Torcx image you can convert it with the `convert_torcx_image.sh` helper script (Currently only Torcx tar balls are supported and the conversion is done on best effort):

```
./convert_torcx_image.sh TORCXTAR SYSEXTNAME
[… writes SYSEXTNAME.raw into the current directory …]
```

Please make also sure that your don't have a `containerd.service` drop in file under `/etc` that uses Torcx paths.
