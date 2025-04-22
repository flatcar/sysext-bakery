---
nav_order: 1
title: Overview
---

<div style="text-align: center" markdown="1">

[![Flatcar OS](https://img.shields.io/badge/Flatcar-Website-blue?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAyNi4wLjMsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjxzdmcgdmVyc2lvbj0iMS4wIiBpZD0ia2F0bWFuXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB2aWV3Qm94PSIwIDAgODAwIDYwMCIgc3R5bGU9ImVuYWJsZS1iYWNrZ3JvdW5kOm5ldyAwIDAgODAwIDYwMDsiIHhtbDpzcGFjZT0icHJlc2VydmUiPg0KPHN0eWxlIHR5cGU9InRleHQvY3NzIj4NCgkuc3Qwe2ZpbGw6IzA5QkFDODt9DQo8L3N0eWxlPg0KPHBhdGggY2xhc3M9InN0MCIgZD0iTTQ0MCwxODIuOGgtMTUuOXYxNS45SDQ0MFYxODIuOHoiLz4NCjxwYXRoIGNsYXNzPSJzdDAiIGQ9Ik00MDAuNSwzMTcuOWgtMzEuOXYxNS45aDMxLjlWMzE3Ljl6Ii8+DQo8cGF0aCBjbGFzcz0ic3QwIiBkPSJNNTQzLjgsMzE3LjlINTEydjE1LjloMzEuOVYzMTcuOXoiLz4NCjxwYXRoIGNsYXNzPSJzdDAiIGQ9Ik02NTUuMiw0MjAuOXYtOTUuNGgtMTUuOXY5NS40aC0xNS45VjI2MmgtMzEuOVYxMzQuOEgyMDkuNFYyNjJoLTMxLjl2MTU5aC0xNS45di05NS40aC0xNnY5NS40aC0xNS45djMxLjINCgloMzEuOXYxNS44aDQ3Ljh2LTE1LjhoMTUuOXYxNS44SDI3M3YtMTUuOGgyNTQuOHYxNS44aDQ3Ljh2LTE1LjhoMTUuOXYxNS44aDQ3Ljh2LTE1LjhoMzEuOXYtMzEuMkg2NTUuMnogTTQ4Ny44LDE1MWg3OS42djMxLjgNCgloLTIzLjZ2NjMuNkg1MTJ2LTYzLjZoLTI0LjJMNDg3LjgsMTUxTDQ4Ny44LDE1MXogTTIzMywyMTQuNlYxNTFoNjMuN3YyMy41aC0zMS45djE1LjhoMzEuOXYyNC4yaC0zMS45djMxLjhIMjMzVjIxNC42eiBNMzA1LDMxNy45DQoJdjE1LjhoLTQ3Ljh2MzEuOEgzMDV2NDcuN2gtOTUuNVYyODYuMUgzMDVMMzA1LDMxNy45eiBNMzEyLjYsMjQ2LjRWMTUxaDMxLjl2NjMuNmgzMS45djMxLjhMMzEyLjYsMjQ2LjRMMzEyLjYsMjQ2LjRMMzEyLjYsMjQ2LjR6DQoJIE00NDguMywzMTcuOXY5NS40aC00Ny44di00Ny43aC0zMS45djQ3LjdoLTQ3LjhWMzAyaDE1Ljl2LTE1LjhoOTUuNVYzMDJoMTUuOUw0NDguMywzMTcuOXogTTQ0MCwyNDYuNHYtMzEuOGgtMTUuOXYzMS44aC0zMS45DQoJdi03OS41aDE1Ljl2LTE1LjhoNDcuOHYxNS44aDE1Ljl2NzkuNUg0NDB6IE01OTEuNiwzMTcuOXY0Ny43aC0xNS45djE1LjhoMTUuOXYzMS44aC00Ny44di0zMS43SDUyOHYtMTUuOGgtMTUuOXY0Ny43aC00Ny44VjI4Ni4xDQoJaDEyNy4zVjMxNy45eiIvPg0KPC9zdmc+DQo=)](https://www.flatcar.org/)
[![Matrix](https://img.shields.io/badge/Matrix-Chat%20with%20us!-green?logo=matrix)](https://app.element.io/#/room/#flatcar:matrix.org)
[![Slack](https://img.shields.io/badge/Slack-Chat%20with%20us!-4A154B?logo=slack)](https://kubernetes.slack.com/archives/C03GQ8B5XNJ)
[![Twitter Follow](https://img.shields.io/twitter/follow/flatcar?style=social)](https://x.com/flatcar)
[![Mastodon Follow](https://img.shields.io/badge/Mastodon-Follow-6364FF?logo=mastodon)](https://hachyderm.io/@flatcar)
[![Bluesky](https://img.shields.io/badge/Bluesky-Follow-0285FF?logo=bluesky)](https://bsky.app/profile/flatcar.org)

</div>

# Ready-to use System Extensions for Flatcar (and other distros)

The Sysext Bakery serves 3 main functions:

1. Serve ready-to-use system extensions for consumption by users in their deployments.
   - The extensions can be consumed via a corresponding Butane/Ignition configuration.
   - Sysupdate configurations are provided too, so extensions can be made to auto-update when new versions are released in the bakery repo.
   - Check the "available extensions" section below for details and config snippets for individual extensions.
   - New versions of extensions are built automatically when the extension's upstream publishes a new release.
2. Provide a go-to point for the community to add new extensions to Flatcar and make them available to everyone.
   - Automated daily update checks and release builds ensure extensions are available for the latest upstream releases.
   - A simple versioning mechanism ensures older releases remain available.
3. Serve as an example to users for creating their own sysexts and operate sysext repositories (either from scratch or as a fork of this repo) to serve customised extensions.
   - Using Github for building and releasing allows for git-ops style releases.
   - For our developer information please check out https://github.com/flatcar/sysext-bakery/.


## What's a sysext and how does it extend Flatcar?

Systemd-sysext, introduced with systemd release 248 in 2021, allows extending the base OS filesystem to add new features and new functionality.
These system extensions are shipped as self-contained immutable file system images.

Extension images follow the UAPI group's [Extension Image specification](https://uapi-group.org/specifications/specs/extension_image/).
Images ship directory trees under `/usr` and (optionally) `/opt` that only contain the binaries and config files required for the respective feature that's being added.
The images also usually contain service unit definitions in `/usr/lib/systemd/system/` to start at boot as needed.
Images also contain lightweight metadata with compatibility information for e.g. CPU architecture and distribution release requirements.

Extension images are "merged" into the base OS file system at boot via an overlayfs mount.
Contents of extension images appear right in the base OS file system.

Extension images hosted here are _self-contained_, i.e. do not have any dependencies on the host operating system.
All extensions can be operated and updated independently of the host OS version.

Extensions can be consumed either at provisioning time using Ignition, or baked into the OS image.
See _Baking sysexts into Flatcar OS images_ below for more information.

If you want to build extensions in this repository yourself and/or want to add an extension, see _"Working with the Bakery_ further below.

## What extensions are available?

The following table lists all extensions built and released in this repository.
"build script" instead of "released" denotes extensions that can be built with this repo but aren't hosted here.
Check out documentation on specific extensions at the navigation menu on the left for detailed usage instructions and configuration examples.

|    Extension     | Availability | Versions available |
| ---------------- | ------------ | ------------- |
| `cilium`         |  released    | [cilium versions](https://github.com/flatcar/sysext-bakery/releases/tag/cilium) |
| `crio`           |  released    | [crio versions](https://github.com/flatcar/sysext-bakery/releases/tag/crio) |
| `docker`         |  released    | [docker versions](https://github.com/flatcar/sysext-bakery/releases/tag/docker) |
| `docker-compose` |  released    | [docker-compose versions](https://github.com/flatcar/sysext-bakery/releases/tag/docker-compose) |
| `falco`          |  released    | [falco versions](https://github.com/flatcar/sysext-bakery/releases/tag/falco) |
| `k3s`            |  released    | [k3s versions](https://github.com/flatcar/sysext-bakery/releases/tag/k3s) |
| `keepalived`     |  released    | [keepalived versions](https://github.com/flatcar/sysext-bakery/releases/tag/keepalived) |
| `kubernetes`     |  released    | [kubernetes versions](https://github.com/flatcar/sysext-bakery/releases/tag/kubernetes) |
| `nerdctl`        |  released    | [nerdctl versions](https://github.com/flatcar/sysext-bakery/releases/tag/nerdctl) |
| `nvidia-runtime` |  released    | [nvidia-runtime versions](https://github.com/flatcar/sysext-bakery/releases/tag/nvidia-runtime) |
| `ollama`         |  released    | [ollama versions](https://github.com/flatcar/sysext-bakery/releases/tag/ollama) |
| `rke2`           |  released    | [rke2 versions](https://github.com/flatcar/sysext-bakery/releases/tag/rke2) |
| `tailscale`      |  released    | [tailscale versions](https://github.com/flatcar/sysext-bakery/releases/tag/tailscale) |
| `wasmcloud`      |  released    | [wasmcloud versions](https://github.com/flatcar/sysext-bakery/releases/tag/wasmcloud) |
| `wasmedge`       |  released    | [wasmedge versions](https://github.com/flatcar/sysext-bakery/releases/tag/wasmedge) |
| `wasmtime`       |  released    | [wasmtime versions](https://github.com/flatcar/sysext-bakery/releases/tag/wasmtime) |

A full list of all extensions and versions available can be found in our bakery [global metadata release](https://github.com/flatcar/sysext-bakery/releases/tag/SHA256SUMS).

## How do I use sysexts?

Simply consume the extensions you need via Ignition, or use [`bake_flatcar_image.sh`](bake_flatcar_image.sh) to create an OS image with the sysext(s) of your choice included.

**BEFORE YOU CONTINUE:**
If you already know what extension(s) you want to use please refer to the individual extensions' documentation at the navigation menu on the left.
The documentation below is a generic walk-through for sysext usage on Flatcar.
The goal of this walk-through is to provide a comprehensive overview of all the steps and details involved.
If you just want to use an extension, please check out the extension documentation directly.

The simplest way to consume a sysext `EXTNAME` is to configure Ignition to download and install it from this repo at provisioning time.
```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /etc/extensions/EXTNAME.raw
      mode: 0644
      contents:
        source: https://extensions.flatcar.org/extensions/EXTNAME.raw
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
        source: https://extensions.flatcar.org/extensions/EXTNAME-3.13.5-x86-64.raw
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
Path=https://extensions.flatcar.org/extensions/EXTNAME
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
        source: https://extensions.flatcar.org/extensions/EXTNAME-3.13.5-x86-64.raw
    - path: /etc/sysupdate.EXTNAME.d/EXTNAME.conf
      contents:
        inline: |
          [Transfer]
          Verify=false

          [Source]
          Type=url-file
          Path=https://extensions.flatcar.org/extensions/EXTNAME
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

### Where are bakery extension images hosted?

Bakery extension images are hosted directly on the GitHub repository.
We provide https://extensions.flatcar.org as a convenience wrapper - it will redirect to the respective extension release on GitHub.
For a deep dive, please refer to the [Bakery developer documentation](https://github.com/flatcar/sysext-bakery?tab=readme-ov-file#releases-structure-in-the-bakery).
for details on the redirect wrappper's interaction with systemd-sysupdate.
While understanding the redirect wrapper might be interesting for curious developers, it's not a requirement for using extension images.

## Baking sysexts into Flatcar OS images

Using the `tools/bake_flatcar_image.sh` script, custom Flatcar OS images can be created which include one or more sysexts.
The script will download a Flatcar OS release image, insert the desired sysexts, and optionally create a vendor (public / private cloud or bare metal) image.

**NOTE:** The script requires sudo access at certain points to manage loopback mounts for the OS image partitions and will then prompt for a password.

For example, if you have just built the Kubernetes sysext and want to embed it into the OS image, run
```bash
./tools/bake_flatcar_image.sh kubernetes:kubernetes.raw
```

By default, the script operates with local sysexts (and optionally sysupdate configurations if present).
However, the `--fetch` option may be specified to fetch the sysext `.raw` file and sysupdate config from the latest Bakery release.
For our Kubernetes example we need to specify a version and architecture because Bakery releases include semver in the extension file name.
```bash
./tools/bake_flatcar_image.sh --fetch kubernetes:kubernetes-v1.31.4-x86-64.raw
```

If you want to produce an image for a specific vendor (e.g. AWS or Azure), instruct `bake_flatcar_image.sh` to do so:
```bash
./tools/bake_flatcar_image.sh --vendor azure kubernetes:kubernetes.raw
```
This build will take a little longer as `bake_flatcar_image.sh` will now use the Flatcar SDK container to build an image for that vendor.
The script supports all vendors and clouds natively supported by Flatcar; you can get a full list via the `--help` flag.

Sysexts can be added to the root partition (the default) or the OEM partition of the OS image.
Read more about Flatcar's OS image disk layout here: https://www.flatcar.org/docs/latest/reference/developer-guides/sdk-disk-partitions/

Refer to `./tools/bake_flatcar_image.sh --help` for more information.

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
