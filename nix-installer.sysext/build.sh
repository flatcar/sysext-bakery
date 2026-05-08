#!/bin/ash
# vim: et ts=2 syn=bash

set -euo pipefail


version="$1"
export_user_group="$2"

apk --no-cache add \
  bash \
  coreutils \
  sudo \
  shadow

addgroup nixbld
adduser -D -h /home/nix -G nixbld nix

mkdir -p /nix
chown nix /nix

su -c "/install_src/install --yes" - nix

# Make the Nix profile link relative so this can be installed for any user
set -x
rm -f /home/nix/.nix-profile
ln -sf ./.local/state/nix/profiles/profile /home/nix/.nix-profile
ls -la /home/nix/
set +x

mkdir -p /install_dest/usr/nix
mv /home/nix /install_dest/usr/nix/nixhome
mv /nix /install_dest/usr/nix/nixroot
chown -R "$export_user_group" /install_dest
