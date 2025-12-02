#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Chrony sysext bakery extension.
#

# Functions in this script will be called by bakery.sh.
# All library functions from lib/ will be available.

# Set to "true" to cause a service units reload on merge, to make systemd aware
#  of new service files shipped by this extension.
# If you want to start your service on merge, ship an `upholds=...` drop-in
#  for `multi-user.target` in the "files/..." directory of this extension.
RELOAD_SERVICES_ON_MERGE="true"

# Fetch and print a list of available stable versions.
# Called by 'bakery.sh list <sysext>.
function list_available_versions() {
  list_gitlab_tags "gitlab.com" "39973492" \
    | grep -v "\-pre"
}

# Download the application shipped with the sysext and populate the sysext root directory.
# This function runs in a subshell inside of a temporary work directory.
# It is safe to download / build directly in "./" as the work directory
#   will be removed after this function returns.
# Called by 'bakery.sh create <sysext>' with:
#   "sysextroot" - First positional argument.
#                    Root directory of the sysext to be created.
#   "arch"       - Second positional argument.
#                    Target architecture of the sysext.
#   "version"    - Third positional argument.
#                    Version number to build.
function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local img_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"
  img_arch="$(arch_transform 'arm64' 'arm64/v8' "$img_arch")"

  local image="docker.io/alpine:3.21"

  announce "Building chrony $version for $arch"

  local user_group="$(id -u):$(id -g)"

  cp "${scriptroot}/chrony.sysext/build.sh" .
  docker run --rm \
    -i \
    -v "$(pwd)":/install_root \
    --platform "linux/${img_arch}" \
    ${image} \
        /install_root/build.sh "${version}" "$user_group"

  cp -aR usr "${sysextroot}"/
}
