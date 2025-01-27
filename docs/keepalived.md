# Keepalive-Daemon sysext

For the keepalive-daemon extension only the build script is provided.
The Bakery does not regularly build this extension nor host ready-to-use sysexts for download at this time.
We recommend to build, and either self-host the extension or to bake it right into a Flatcar OS image.

The build process will build a statically compiled keepalived in a transient Alpine docker image, export the resulting binary, and build a sysext.

# Usage

Review the keepalived releases and pick a release version: https://github.com/acassen/keepalived
The example below uses keepalived v2.3.1.

Clone the bakery repo and build the sysext.
```bash
git clone https://github.com/flatcar/sysext-bakery.git
cd sysext-bakery
./create_keepalived_sysext.sh v2.3.1 keepalived
```

This will produce `keepalived.raw` in the local directory.

You may now bake it into a Flatcar image - say, the latest Stable release.
**NOTE** this requires `sudo` access at one point and might prompt you for a password.
`sudo` is required to loopback-mount the image's root partition for installing the sysext.
```bash
./bake_flatcar_image.sh keepalived:keepalived.raw
```

If you want to produce an image for a specific vendor (e.g. AWS or Azure), instruct `bake_flatcar_image.sh` to do so:
```bash
./bake_flatcar_image.sh --vendor azure keepalived:keepalived.raw
```
This build will take a little longer as `bake_flatcar_image.sh` will now use the Flatcar SDK container to build an image for that vendor.

### Self-host and consume at provisioning time

Alternatively to baking keepalived into an OS image, users may as well host the sysext on a HTTP[S] endpoint and consume to at provisioning time.

Assuming we hosted the sysext at https://sysexts.me/, here's a simple Butane config to consume the sysext:

```yaml
variant: flatcar
version: 1.0.0

storage:
  files:
    - path: /opt/extensions/keepalived/keepalived.raw
      mode: 0644
      contents:
        source: https://sysexts.me/keepalived.raw
  links:
    - target: /opt/extensions/keepalived/keepalived.raw
      path: /etc/extensions/keepalived.raw
      hard: false
```
