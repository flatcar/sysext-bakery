# Ready-to use System Extensions for Flatcar (and other distros)

The Sysext Bakery serves 3 main functions:

1. Serve ready-to-use system extensions for consumption by users in their deployments via our [Releases](https://github.com/flatcar/sysext-bakery/releases/tag/latest).
   - The extensions can be consumed directly from releases of this repository via a corresponding Butane/Ignition configuration.
   - Sysupdate configurations are provided too, so extensions can be made to auto-update when new versions are released in the bakery repo.
   - Check the "available extensions" section below for details and config snippets for individual extensions.
2. Provide a go-to point for the community to add new extensions to Flatcar and make them available to everyone.
   - Regular release builds of the Flatcar maintainers team ensure extensions remain up to date.
   - A simple versioning mechanism ensures older releases remain available.
3. Serve as an example to users for creating their own sysexts and operate sysext repositories (either from scratch or as a fork of this repo) to serve customised extensions.
   - Using Github for building and releasing allows for git-ops style releases.


## What's a sysext and how does it extend Flatcar?

Systemd-sysext, introduced with systemd release 248 in 2021, allows extending the base OS filesystem to add new features and new functionality.
These system extensions are shipped as self-contained immutable file system images.

Extension images follow the UAPI group's [Extension Image specification](https://uapi-group.org/specifications/specs/extension_image/).
Images ship directory trees under `/usr` and (optionally) `/opt` that only contain the binaries and config files required for the respective feature that's being added.
The images also usually contain service unit definitions in `/usr/lib/systemd/system/` to start at boot as needed, and lightweight metadata

Extension images are "merged" into the base OS file system at boot via an overlayfs mount.
Contents of extension images appear right in the base OS file system.

Extension images hosted here are _self-contained_, i.e. do not have any dependencies on the host operating system.
All extensions can be operated and updated independently of the host OS version.

Extensions can be consumed either at provisioning time using Ignition, or baked into the OS image.
See _Baking sysexts into Flatcar OS images_ below for more information.


## What extensions are available?

The following table lists all extensions built and released in this repository.
"build script" instead of "released" denotes extensions that can be built with this repo but aren't hosted here.
Check out the README files of specific extensions for detailed usage instructions and configuration examples.

|    Extension     | Availability | Documentation |
| ---------------- | ------------ | ------------- |
| `crio`           |  released    | [crio.md](docs/crio.md) |
| `docker`         |  released    | [docker.md](docs/docker.md) |
| `docker_compose` |  released    | [docker_compose.md](docs/docker_compose.md) |
| `falco`          |  released    | [falco.md](docs/falco.md) |
| `k3s`            |  released    | [k3s.md](docs/k3s.md) |
| `keepalived`     | build script | [keepalived.md](docs/keepalived.md) |
| `kubernetes`     |  released    | [kubernetes.md](docs/kubernetes.md) |
| `nvidia-runtime` |  released    | [nvidia-runtime.md](docs/nvidia-runtime.md) |
| `ollama`         |  released    | [ollama.md](docs/ollama.md) |
| `rke2`           |  released    | [rke2.md](docs/rke2.md) |
| `tailscale`      |  released    | [tailscale.md](docs/tailscale.md) |
| `wasmcloud`      |  released    | [wasmcloud.md](docs/wasmcloud.md) |
| `wasmedge`       |  released    | [wasmedge.md](docs/wasmedge.md) |
| `wasmtime`       |  released    | [wasmtime.md](docs/wasmtime.md) |


## How do I use sysexts?

Simply consume the extensions you need via Ignition, or use [`bake_flatcar_image.sh`](bake_flatcar_image.sh) to create an OS image with the sysext(s) of your choice included.

**BEFORE YOU CONTINUE:**
If you already know what extension(s) you want to use please refer to the individual extensions' readme files referenced above for ready-to-use configuration snippets (including sysupdate configuration).
The documentation below is a generic walk-through for sysext usage on Flatcar.
The goal of this walk-through is to provide a comprehensive overview of all the steps and details involved.
If you just want to use an extension, please check out the individual readmes above.

The simplest way to consume a sysext `EXTNAME` is to configure Ignition to download and install it from this repo at provisioning time.
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /etc/extensions/EXTNAME.raw
      mode: 0644
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/EXTNAME.raw
```
That's it!

### Try it locally

A more flexible approach is to store extensions in a custom path in `/opt` and sym-link into `/etc/extensions`.
This allows us to store versioned sysexts (via semver filenames) and manage sysexts via symlinks.
With this approach, we can store multiple versions of an extension for in-place upgrades and for roll-backs.
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/EXTNAME/EXTNAME-3.13.5-x86-64.raw
      mode: 0644
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/EXTNAME-3.13.5-x86-64.raw
  links:
    - target: /opt/extensions/EXTNAME/EXTNAME-3.13.5-x86-64.raw
      path: /etc/extensions/EXTNAME.raw
      hard: false
```

## Extension auto-updates

Using the flexible (symlink) approach above we can instruct `systemd-sysupdate` to poll the bakery for updates.
This is done by running the sysupdate service on a schedule, triggered by a timer unit.
The default cadence for sysupdate to run on Flatcar is set to one hour, and can be changed via drop-ins for the `systemd-sysupdate.timer` unit.

Sysupdate matches semantic versioning patterns in sysext filenames to learn whether an update is available.
If a version newer than currently installed becomes available, sysupdate will download the update and store the extension image next to the one currently used.
Sysupdate will then re-create the symlink to point to the new sysext.

At this point, the update will have been _staged_ but not activated.

`/etc/sysupdate.EXTNAME.d/EXTNAME.conf` sysupdate configuration.
The pattern `@v-%a` signifies the semver part of the extension's file name.
`InstancesMax=3` tells sysupdate to keep a maximum of 3 versions of the extension (for roll-back).
```ini
[Transfer]
Verify=false

[Source]
Type=url-file
Path=https://github.com/flatcar/sysext-bakery/releases/latest/download/
MatchPattern=EXTNAME-@v-%a.raw

[Target]
InstancesMax=3
Type=regular-file
Path=/opt/extensions/EXTNAME/
CurrentSymlink=/etc/extensions/EXTNAME.raw
```
The config file will be used in conjunction with `systemd-sysupdate -C EXTNAME update` to perform an update check.
We'll automate the check and wire it up to a timer unit in the next step.

**NOTE**: As mentioned, `systemd-sysupdate` will only _stage_ an update, not _activate_ it.
To activate an update, we need to either run `systemd-sysext refresh` or reboot the instance.
Either action might be more feasible depending on what is shipped with the extension.
For simple extensions like docker, crio, or wasm, it might suffice to stop the corresponding service, apply the update, and restart the service.
For complex workloads like Kubernetes it is probably more feasible to request a node reboot.

We will now add a drop-in for the sysupdate service to have it check for `EXTNAME` updates on a schedule.
The drop-in will run sysupdate and detect whether the symlink changed.
This goes to `/etc/systemd/system/systemd-sysupdate.service.d/EXTNAME.conf`
```ini
[Service]
ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/EXTNAME.raw > /tmp/EXTNAME"
ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C EXTNAME update
ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/EXTNAME.raw > /tmp/EXTNAME-new"
ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/EXTNAME /tmp/EXTNAME-new; then <SERVICE REFRESH ACTION HERE>; fi"
```

For simple services, we might just activate the update directly and restart the service:
```ini
...
ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/EXTNAME /tmp/EXTNAME-new; then systemd-sysext refresh; systemctl restart EXTNAME.service; fi"
...
```

For more complex services like Kubernetes, we might tell a reboot manager like e.g. kured or FLUO to safely reboot the node:
```ini
...
ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/EXTNAME /tmp/EXTNAME-new; then touch /run/reboot-required; fi"
...
```

## Putting it all together

Here is a full-featured Butane configuration snippet for `EXTNAME` with sysupdate included.

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/EXTNAME/EXTNAME-3.13.5-x86-64.raw
      mode: 0644
      contents:
        source: https://github.com/flatcar/sysext-bakery/releases/download/latest/EXTNAME-3.13.5-x86-64.raw
    - path: /etc/sysupdate.EXTNAME.d/EXTNAME.conf
      contents:
        inline: |
          [Transfer]
          Verify=false

          [Source]
          Type=url-file
          Path=https://github.com/flatcar/sysext-bakery/releases/latest/download/
          MatchPattern=EXTNAME-@v-%a.raw

          [Target]
          InstancesMax=3
          Type=regular-file
          Path=/opt/extensions/EXTNAME/
          CurrentSymlink=/etc/extensions/EXTNAME.raw
    - path: /etc/sysupdate.d/noop.conf
      contents:
        inline: |
          [Source]
          Type=regular-file
          Path=/
          MatchPattern=invalid@v.raw
          [Target]
          Type=regular-file
          Path=/
  links:
    - target: /opt/extensions/EXTNAME/EXTNAME-3.13.5-x86-64.raw
      path: /etc/extensions/EXTNAME.raw
      hard: false
systemd:
  units:
    - name: systemd-sysupdate.timer
      enabled: true
    - name: systemd-sysupdate.service
      dropins:
        - name: EXTNAME.conf
          contents: |
            [Service]
            ExecStartPre=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/EXTNAME.raw > /tmp/EXTNAME"
            ExecStartPre=/usr/lib/systemd/systemd-sysupdate -C EXTNAME update
            ExecStartPost=/usr/bin/sh -c "readlink --canonicalize /etc/extensions/EXTNAME.raw > /tmp/EXTNAME-new"
            ExecStartPost=/usr/bin/sh -c "if ! cmp --silent /tmp/EXTNAME /tmp/EXTNAME-new; then <SERVICE REFRESH ACTION HERE>; fi"
```

Note that this snippet inlines all of the sysupdate configuration for documentation purposes.
Most extensions published in the Bakery ship sysupdate configuration as part of the releases, so these can be downloaded by Ignition instead of being inlined.
(And consequently, that's what most of the configuration examples of individual extensions do).
Check out the respective extensions' readme for details.

Also, we include a dummy `noop.conf` for systemd-sysupdate to work around a spurious error message.

## Baking sysexts into Flatcar OS images

Using the `bake_flatcar_image.sh` script, custom Flatcar OS images can be created which include one or more sysexts.
The script will download a Flatcar OS release image, insert the desired sysexts, and optionally create a vendor (public / private cloud or bare metal) image.

**NOTE:** The script requires sudo access at certain points to manage loopback mounts for the OS image partitions and will then prompt for a password.

For example, if you have just built the Kubernetes sysext and want to embed it into the OS image, run
```bash
./bake_flatcar_image.sh kubernetes:kubernetes.raw
```

By default, the script operates with local sysexts (and optionally sysupdate configurations if present).
However, the `--fetch` option may be specified to fetch the sysext `.raw` file and sysupdate config from the latest Bakery release.
For our Kubernetes example we need to specify a version and architecture because Bakery releases include semver in the extension file name.
```bash
./bake_flatcar_image.sh --fetch kubernetes:kubernetes-v1.31.4-x86-64.raw
```

If you want to produce an image for a specific vendor (e.g. AWS or Azure), instruct `bake_flatcar_image.sh` to do so:
```bash
./bake_flatcar_image.sh --vendor azure kubernetes:kubernetes.raw
```
This build will take a little longer as `bake_flatcar_image.sh` will now use the Flatcar SDK container to build an image for that vendor.
The script supports all vendors and clouds natively supported by Flatcar; you can get a full list via the `--help` flag.

Sysexts can be added to the root partition (the default) or the OEM partition of the OS image.
Read more about Flatcar's OS image disk layout here: https://www.flatcar.org/docs/latest/reference/developer-guides/sdk-disk-partitions/

Refer to `./bake_flatcar_image.sh --help` for more information.

### Try it locally with the QEMU vendor

Baking sysexts into the OS image provides an entirely self-contained way to test sysexts locally, in a live Flatcar VM.
First, we use the `qemu_uefi` vendor to build an OS image that contains the sysext we want to test.
We'll continue to use the kubernetes example from above.

```bash
./bake_flatcar_image.sh --vendor qemu_uefo kubernetes:kubernetes.raw
```

This will produce the OS image, `flatcar_production_qemu_uefi_image.img.bz2`, with kubernetes baked in, as well as a few other artifacts.
The OS image is compressed for efficiency reasons; we uncompress it so we can use it locally.
```bash
bunzip2 flatcar_production_qemu_uefi_image.img.bz2
```

Now we can boot the image locally and check for Kubernetes being present.
We'll use qemu's the console output (`-nographic`) and we'll not modify the base image (`-snapshot`) so we can mess around without remorse:
```bash
./flatcar_production_qemu_uefi.sh -nographic -snapshot
...
... [Flatcar is booting] ...
...
core@localhost ~ $
```

We can now check for Kubernetes e.g. via
```bash
core@localhost ~ $ kubelet --version
Kubernetes v1.31.4
core@localhost ~ $
```

Further testing can now be done directly, on a live instance.


## Building sysext images

There is no strict need for building extensions yourself; most extensions are hosted in this repo as a Github release.
The release is generated via a [Github action](.github/workflows/release.yaml) each time a new version tag is pushed.
If you still want to build yourself, the following packages are required:

- `curl`
- `jq`
- `squashfs-tools`
- `xz-utils`
- `gawk`
- [`yq`](https://github.com/mikefarah/yq/releases/latest/)


### Build individual sysext image

To build the Kubernetes sysext for example, use:

```sh
./create_kubernetes_sysext.sh v1.29.8 kubernetes
```

Afterwards, you can test the sysext image with:

```sh
sudo cp kubernetes.raw /etc/extensions/kubernetes.raw
sudo systemd-sysext refresh
kubeadm version
```

### Build all sysext images in this repository

This builds `x86-64` and `arm64` versions of **all** sysext images listed in `release_build_versions.txt`.
This takes some time.

```sh
./release_build.sh
```

# Adding new Extensions

We're always interested in adding more extensions here, and to serve them to all Flatcar users.
Check out existing build scripts for inspiration.
E.g. [create_ollama_sysext.sh](https://github.com/flatcar/sysext-bakery/blob/main/create_ollama_sysext.sh) is a pretty simple though full-featured one.

Create a new script `create_EXTNAME_sysext.sh` which
1. Creates a subdirectory `EXTNAME` which will later be used to generate the sysext file system from.
2. Download a release of the application you want to ship and store them in suitable subdirectories below `EXTNAME/`.
   Make sure the application is self-contained **and** doesn't ship any system libraries like glibc etc. If you need such a library in a sysext, please consult the Flix/Flatwrap instructions below.
   - binaries go to `EXTNAME/usr/bin`
   - libraries go to `EXTNAME/usr/lib`
   - other files go to any path below `EXTNAME/usr/` as appropriate.
3. If applicable, create service unit(s) for the application in `EXTNAME/usr/lib/systemd/system/`.
4. Call `bake.sh EXTNAME` to generate `EXTNAME.raw` from the subdirectory we populated in steps 1. to 3.
   A number of environment variables control metadata generated by `bake.sh`
   - `ARCH` - CPU architecture. Either `arm64` or `x86-64`.
   - `RELOAD` - set this to "1" if your sysext includes service units (step 3. above).
     This will instruct the service manager to reload its configuration after merge, so the new service files will be picked up.

- Add the extension build script to the repo , add a corresponding markdown file with usage instructions and config snippets to `docs/`.
- Optionally add the new extension name to [release_build_versions.txt](https://github.com/flatcar/sysext-bakery/blob/main/release_build_versions.txt) to automatically build sysexts with new bakery releases.
- Add the sysext to the list of available extensions in this README.
- File a PR.
Done!


## Flix and Flatwrap

The Flix and Flatwrap tools both convert a root folder into a systemd-sysext image.
You have to specify which files should be made available to the host.

The Flix tool rewrites specified binaries to use a custom library path.
You also have to specify needed resource folders and you can specify systemd units, too.

Flatwrap, on the other hand, uses lightweight namespace isolation to create a private root for the sysext contents.

These tools can be used to safely ship library dependencies of OS libraries (like e.g. glibc) in a custom path.
The custom path ("sysroot") avoids clashes with Flatcar's native OS libraries.

Flix example:

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

# For maintainers: how do I trigger a new release?

CI can be kicked-off by overriding the `latest` tag. The `latest` release artifacts will be updated consequently here: https://github.com/flatcar/sysext-bakery/releases/tag/latest
```
git checkout main
git pull --ff-only
git tag -d latest
git tag -as latest
git push origin --force latest
```
