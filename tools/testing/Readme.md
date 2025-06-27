# Testing

Helper script for testing sysexts.
The script can be used to test an extension interactively on a Flatcar qemu instance.
If no Flatcar image is found locally, the script will download it from https://stable.release.flatcar-linux.net/amd64-usr/current/.

Usage:
```
./test.sh <path-to-sysext-file>
```

It will:
- Start a webserver (caddy, via docker) in the directory the sysext resides in
- Creates a ignition config (from `test.yaml.tmpl`) that installs the sysext
- Start a Flatcar, and drops to a shell (via TTY).

Users can then run commands to validate the extension.
