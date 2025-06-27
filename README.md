<div style="text-align: center">

[![Flatcar OS](https://img.shields.io/badge/Flatcar-Website-blue?logo=data:image/svg+xml;base64,PD94bWwgdmVyc2lvbj0iMS4wIiBlbmNvZGluZz0idXRmLTgiPz4NCjwhLS0gR2VuZXJhdG9yOiBBZG9iZSBJbGx1c3RyYXRvciAyNi4wLjMsIFNWRyBFeHBvcnQgUGx1Zy1JbiAuIFNWRyBWZXJzaW9uOiA2LjAwIEJ1aWxkIDApICAtLT4NCjxzdmcgdmVyc2lvbj0iMS4wIiBpZD0ia2F0bWFuXzEiIHhtbG5zPSJodHRwOi8vd3d3LnczLm9yZy8yMDAwL3N2ZyIgeG1sbnM6eGxpbms9Imh0dHA6Ly93d3cudzMub3JnLzE5OTkveGxpbmsiIHg9IjBweCIgeT0iMHB4Ig0KCSB2aWV3Qm94PSIwIDAgODAwIDYwMCIgc3R5bGU9ImVuYWJsZS1iYWNrZ3JvdW5kOm5ldyAwIDAgODAwIDYwMDsiIHhtbDpzcGFjZT0icHJlc2VydmUiPg0KPHN0eWxlIHR5cGU9InRleHQvY3NzIj4NCgkuc3Qwe2ZpbGw6IzA5QkFDODt9DQo8L3N0eWxlPg0KPHBhdGggY2xhc3M9InN0MCIgZD0iTTQ0MCwxODIuOGgtMTUuOXYxNS45SDQ0MFYxODIuOHoiLz4NCjxwYXRoIGNsYXNzPSJzdDAiIGQ9Ik00MDAuNSwzMTcuOWgtMzEuOXYxNS45aDMxLjlWMzE3Ljl6Ii8+DQo8cGF0aCBjbGFzcz0ic3QwIiBkPSJNNTQzLjgsMzE3LjlINTEydjE1LjloMzEuOVYzMTcuOXoiLz4NCjxwYXRoIGNsYXNzPSJzdDAiIGQ9Ik02NTUuMiw0MjAuOXYtOTUuNGgtMTUuOXY5NS40aC0xNS45VjI2MmgtMzEuOVYxMzQuOEgyMDkuNFYyNjJoLTMxLjl2MTU5aC0xNS45di05NS40aC0xNnY5NS40aC0xNS45djMxLjINCgloMzEuOXYxNS44aDQ3Ljh2LTE1LjhoMTUuOXYxNS44SDI3M3YtMTUuOGgyNTQuOHYxNS44aDQ3Ljh2LTE1LjhoMTUuOXYxNS44aDQ3Ljh2LTE1LjhoMzEuOXYtMzEuMkg2NTUuMnogTTQ4Ny44LDE1MWg3OS42djMxLjgNCgloLTIzLjZ2NjMuNkg1MTJ2LTYzLjZoLTI0LjJMNDg3LjgsMTUxTDQ4Ny44LDE1MXogTTIzMywyMTQuNlYxNTFoNjMuN3YyMy41aC0zMS45djE1LjhoMzEuOXYyNC4yaC0zMS45djMxLjhIMjMzVjIxNC42eiBNMzA1LDMxNy45DQoJdjE1LjhoLTQ3Ljh2MzEuOEgzMDV2NDcuN2gtOTUuNVYyODYuMUgzMDVMMzA1LDMxNy45eiBNMzEyLjYsMjQ2LjRWMTUxaDMxLjl2NjMuNmgzMS45djMxLjhMMzEyLjYsMjQ2LjRMMzEyLjYsMjQ2LjRMMzEyLjYsMjQ2LjR6DQoJIE00NDguMywzMTcuOXY5NS40aC00Ny44di00Ny43aC0zMS45djQ3LjdoLTQ3LjhWMzAyaDE1Ljl2LTE1LjhoOTUuNVYzMDJoMTUuOUw0NDguMywzMTcuOXogTTQ0MCwyNDYuNHYtMzEuOGgtMTUuOXYzMS44aC0zMS45DQoJdi03OS41aDE1Ljl2LTE1LjhoNDcuOHYxNS44aDE1Ljl2NzkuNUg0NDB6IE01OTEuNiwzMTcuOXY0Ny43aC0xNS45djE1LjhoMTUuOXYzMS44aC00Ny44di0zMS43SDUyOHYtMTUuOGgtMTUuOXY0Ny43aC00Ny44VjI4Ni4xDQoJaDEyNy4zVjMxNy45eiIvPg0KPC9zdmc+DQo=)](https://www.flatcar.org/)
[![Matrix](https://img.shields.io/badge/Matrix-Chat%20with%20us!-green?logo=matrix)](https://app.element.io/#/room/#flatcar:matrix.org)
[![Slack](https://img.shields.io/badge/Slack-Chat%20with%20us!-4A154B?logo=slack)](https://kubernetes.slack.com/archives/C03GQ8B5XNJ)
[![Twitter Follow](https://img.shields.io/twitter/follow/flatcar?style=social)](https://x.com/flatcar)
[![Mastodon Follow](https://img.shields.io/badge/Mastodon-Follow-6364FF?logo=mastodon)](https://hachyderm.io/@flatcar)
[![Bluesky](https://img.shields.io/badge/Bluesky-Follow-0285FF?logo=bluesky)](https://bsky.app/profile/flatcar.org)

</div>

# The Flatcar Sysext Bakery

[![Extension Builds Status](https://github.com/flatcar/sysext-bakery/actions/workflows/release.yaml/badge.svg)](https://github.com/flatcar/sysext-bakery/actions/workflows/release.yaml)

For information on using extensions available through the bakery please refer to https://extensions.flatcar.org.

This document covers developer information, i.e. improving existing extensions, developing new extensions, and self-hosting your own bakery.

## Working with the Bakery

There is no strict need for building extensions yourself; most extensions are hosted in this repo as Github releases.
Check out https://extensions.flatcar.org for more information like guides and configuration snippets on using these extensions.

### Build sysexts

If you want to build yourself, the following packages are required:

- `curl`
- `docker`
- `git`
- `jq`
- `squashfs-tools` (or `erofs-utils` if the sysexts are built with `erofs` format instead of default `squashfs`)
- `xz-utils`
- [`yq`](https://github.com/mikefarah/yq/releases/latest/)

First, clone the repository.
The `bakery.sh` script is used to interact with individual extension build scripts.
Try
```sh
./bakery.sh help
```
to get command line help.

List all extensions available to build:
```sh
./bakery.sh list
```

To fetch all versions that can be built for a specific extension, run:
```sh
./bakery.sh list <extension>
```
, e.g.
```sh
./bakery.sh list kubernetes
```
This fetches version information directly from the corresponding release server.


To build e.g. an extension shipping Kubernetes release v1.29.8, run:

```sh
./bakery.sh create kubernetes v1.29.8
```

This creates `kubernetes.raw` for x86-64 targets along with `SHA256SUMS.kubernetes` to be
 used in combination with systemd-sysupdate.

Speaking of sysupdate, you can generate a matching `sysupdate.conf` via
```sh
./bakery.sh create kubernetes v1.29.8 --sysupdate true
```

To build for arm64 targets, use
```sh
./bakery.sh create kubernetes v1.29.8 --arch arm64
```

Check out
```sh
./bakery.sh create help
```
to see all options available for building extensions.

Some extensions, e.g. Docker, supply additional command line parameters.
Use
```sh
./bakery.sh create <extension> help
```
to display these; e.g.
```sh
./bakery.sh create docker help
```

### Build all sysext images in this repository

This builds `x86-64` and `arm64` versions of **all** sysext images listed in `release_build_versions.txt`.
This takes some time.

```sh
./release_build.sh
```

# Adding new Extensions

We're always interested in adding more extensions here, and to serve them to all Flatcar users.
Adding extensions should be fairly easy.
The bakery offers library functions for most boilerplate tasks.
Extension builds just need to implement core logic functions to populate a directory tree with files to be shipped.

To add an extension:
1. Copy the extension skeleton directory
  ```sh
  cp -R _skel.sysext <my-extension-name>.sysext
  ```
2.  Put static files like configurations, systemd units etc. in the `files/` sub-directory.
   The files will end up in the extension image at the same paths they were placed below `files`, e.g..
   `files/usr/lib/systemd/system/myservice.service` will be `/usr/lib/systemd/system/myservice.service`
   in the extension image.
   If you want your service to start automatically when the sysext is merged, consider shipping
    a drop-in to `usr/lib/systemd/system/multi-user.target.d` that adds `Upholds=<your-service>.service`
    to the  `[Unit]` section.
3. Implement the `populate_sysext_root` and `list_available_versions` function stubs in `create.sh`.
   - `list_available_versions` prints a list of (upstream) available versions to build.
      Check out e.g. the `list_github_releases` function in `lib/helpers.sh` for inspiration.
      (this function, and all other functions in `lib/`, are available when `create.sh` runs).
      This function plays a key role for the bakery release automation; implement it to benefit from automated releases of new versions.
   - `populate_sysext_root` populates the system extension root directory (available via `$sysextroot`).
      This function runs in a temporary directory; stuff can be downloaded / built in `./` and then moved to `$sysextroot`.
      The temporary directory will be removed when the extension build is complete (or when it errors out); no need to clean up manually.
4. Add `docs/<my-extension-name>.md` with documentation and example configuration for the new extension, and reference the new file from the list of extensions in `docs/_index.md`.
5. Optionally add the new extension name to [release_build_versions.txt](https://github.com/flatcar/sysext-bakery/blob/main/release_build_versions.txt) to automatically build it when new upstream versions are released.
6. File a PR.

Done!

Have a look at other extension builds for inspiration;
* [k3s](/k3s.sysext/create.sh) and [falco](/falco.sysext/create.sh) are fairly simple and straightforward ones.
* [containerd](/containerd.sysext/) ships an `Upholds=...` drop-in.
* [docker](/docker.sysext/create.sh) is quite complex and even features its own command line build option.
* [keepalived](/keepalived.sysext/create.sh) is rather unusual in that it spawns an ephemeral Alpine docker container
  to statically compile keepalived (via a [build script](/keepalived.sysext/build.sh) mounted into the container).

# Test sysexts in a local Flatcar qemu instance

A complementary helper script for interactive local testing is provided in [`tools/testing`](tools/testing).
The script aims to automate all boiler plating such as downloading OS images, generating configuration to install the extension, and serving the extension to the qemu instance.

# Hosting your own bakery

Just fork the Bakery, rename
[`.env.example`](.env.example)
to `.env` and update the variables to their new home. Now you can start building and publishing!

Note: By default `.env` is in .gitignore to prevent any sensitive information from being uploaded and `.env` could be extended in the future. One can run the following to push it to git:
```sh
git add --force .env
```

In general, the extension images can be consumed straight from the respective GitHub releases download sections.
However, making systemd-sysupdate work requires extra steps - see below.

## Releases structure in the bakery

Releases in the bakery are structured to ease consumption by both ignition and systemd-sysupdate.
The bakery hosts extensions' individual releases, a per-extension metadata release, and a global metadata release for all extensions.

* **Individual releases**:
  The actual extension image, in one specific version.
  Each individual release in the Bakery serves one extension in one specific version; e.g. `docker-24.0.1` or `kubernetes-1.22.0`.
  Release artefacts include extension images for x86-64 and arm64, a SHA256SUMS file for both, and a sysupdate configuration.
  * These releases are named `<extension>-<version>`.
* **Extension Metadata releases**:
  Version information metadata for all versions of one specific extension.
  Extension metadata releases ship a `SHA256SUMS` file that includes all versions of one specific extension.
  These can be seen as "inventory list" of versions available and are consumed by sysupdate.
  They also ship sysupdate configuration files to serve as a well-defined source URI for ignition configuration.
  * These releases are named `<extension>`.
  The metadata is updated automatically each time a new extension / extension version is published.
* **Global Metadata release**:
  Version information metadata for all extensions.
  Global metadata releases ship one single SHA256SUMS file with all extensions' versions.
  This release can be seen as the global inventory of the whole Bakery.
  * The release is named `SHA256SUMS`.


## Making systemd-sysupdate work with GitHub releases

`systemd-sysupdate` uses a `SHA256SUMS` index file to learn about new releases.
It expects _all_ sysexts listed in that file to be available in the same path, e.g.:
* `.../SHA256SUMS`
* `.../kubernetes-v1.32.0-x86-64.raw`
* `.../kubernetes-v1.32.0-arm64.raw`
* `.../kubernetes-v1.32.1-x86-64.raw`
* `.../kubernetes-v1.32.1-arm64.raw`

GitHub however publishes releases in URLs that include the release tag:
* `.../releases/download/kubernetes-v1.32.0/kubernetes-v1.32.0-x86-64.raw`
* `.../releases/download/kubernetes-v1.32.0/kubernetes-v1.32.0-arm64.raw`
* `.../releases/download/kubernetes-v1.32.1/kubernetes-v1.32.1-x86-64.raw`
* `.../releases/download/kubernetes-v1.32.1/kubernetes-v1.32.1-x86-64.raw`

To benefit from GitHub releases hosting, we work around that with a small web service that rewrites URLs
following a static match pattern.
Simplified, this looks like:
* `.../SHA256SUMS` => `/releases/SHA256SUMS/SHA256SUMS` - index file
* `.../<extension>-<version>-<arch>.raw` => `/releases/<extension>-<version>/<extension>-<version>-<arch>.raw` -
  The actual extension image.
* `.../<extension>.conf` => `/releases/<extension>/<extension>.conf` - sysupdate configuration for that extension

Lastly, for extensions that do not support unattended in-place updates across major releases (like Kubernetes, rke2, etc.)
we support an additional `<release>` sub-path in the source URL to select a specific release and not have it deduced from the filename:
* `.../<release>/<extension>.conf` => `/releases/<release>/<extension>.conf`

This requires self-hosting, but is low traffic and low CPU load, as the only task this service has is to re-write HTTP URLs.
Usually the smallest instance type of your favourite hoster suffices.
Flatcar uses https://extensions.flatcar.org.

A suitable deployment configuration are available in [`tools/http-url-rewrite-server`](tools/http-url-rewrite-server).
The [`Caddyfile`](tools/http-url-rewrite-server/Caddyfile) contains comments on all redirect patterns.


# Specialised tools for specialised / exotic extension builds

## Flix and Flatwrap

The Flix and Flatwrap tools can be used to ship dynamically linked binaries w/o interfering with the host system.
Both should be called from `populate_sysext_root()` via `${scriptroot}/tools/flix.sh` and `${scriptroot}/tools/flatwrap.sh`, respectively.

Both convert a root folder into a systemd-sysext image.
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

Releases are built automatically by the `release-checker` github action.
Builds are based on [`release_build_versions.txt`](release_build_versions.txt) and a new release will be created for:
 - All sysext versions listed there that are not yet hosted on the bakery, i.e. not in
 - All latest versions sysexts that have `latest` listed in [`release_build_versions.txt`](release_build_versions.txt) 
   and have a new version available that is not yet hosted on the Bakery.

The action runs on a timer (default: once per day) but can also be triggered manually.

## What happens in a release build?

To scan for new releases:
1. The release build script reads extensions and versions from `release_build_versions.txt`.
  a. For `latest`, it acquires the latest upstream release using `bakery.sh list <extension> --latest true`.
2. It checks (via `./bakery.sh list-bakery <sysext>`) whether a respective Bakery release exists.
  a. If a respective bakery release exists, the action stops.
  b. If there is no Bakery release of the desired version, a new release build is dispatched.

A new release build is started.
1. Artefacts are genreated using `./bakery.sh create <extension> <version> --sysupdate true`
   a. x86-64 and arm64 sysexts
   b. `<extension>.conf` sysupdate
   c. `SHA256SUMS` for extension images
2. A new tag is created and pushed, to serve as release tag.
3. A new release `<extension>-<version>` is generated, containing:
   a. Extension images
   b. sysupdate files
   c. SHA256SUMS
4. The extension metadata update job is dispatched.

The bakery's metadata releases are updated.
1. The metadata release `.../<extension>/` will be re-generated from
   a. all releases' sysupdate files of this extension
   b. concatenated `SHA256SUMS` of all released versions
2. The global metadata release in `.../SHA256SUMS/SHA256SUMS` will be re-generated.
   This is done by downloading all `SHA256SUMS` files of all `.../<extension>/` metadata releases and merging them.
