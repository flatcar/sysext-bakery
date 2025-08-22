#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Extension creation skeleton script for sysext bakery extensions.
#

# Functions in this script will be called by bakery.sh.
# All library functions from lib/ will be available.

# NOTE: If you only ship static files in your sysext (in the files/ subdirectory)
#       just delete create.sh for your sysext.

# Set to "true" to cause a service units reload on merge, to make systemd aware
#  of new service files shipped by this extension.
# If you want to start your service on merge, ship an `upholds=...` drop-in
#  for `multi-user.target` in the "files/..." directory of this extension.
RELOAD_SERVICES_ON_MERGE="true"

# If your extension publishes custom versions other than
# "<extension>-v1.2.3" or "<extension>-1.2.3" please provide a regex match
# pattern. Will be used by "bakery.sh list-bakery <extension>" and
# by the release scripts.
# EXTENSION_VERSION_MATCH_PATTERN='[.v0-9]+'

# If you need to run curl calls to api.github.com consider using
# 'curl_api_wrapper' (from lib/helpers.sh). The wrapper will use GH_TOKEN
# if set to prevent throttling of unauthenticated calls, and handle pagination
# etc.

# Fetch and print a list of available versions.
# Called by 'bakery.sh list <sysext>.
function list_available_versions() {
  # TODO: implement fetching a list of releases from upstream
  #       and print available versions, one version per line.
  #  e.g. using list_github_releases from lib/helpers.sh.      
  
  list_github_releases "inspektor-gadget" "inspektor-gadget"
}
# --

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

  # The release uses different arch identifiers
  local rel_arch="$(arch_transform 'x86-64' 'amd64' "$arch")"

  curl -o ig.tar.gz -fsSL "https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${version}/ig-linux-${rel_arch}-${version}.tar.gz"
  curl -o gadgetctl.tar.gz -fsSL "https://github.com/inspektor-gadget/inspektor-gadget/releases/download/${version}/gadgetctl-linux-${rel_arch}-${version}.tar.gz"

  tar -xf ig.tar.gz
  tar -xf gadgetctl.tar.gz

  mkdir -p "${sysextroot}/usr/bin/"
  mv ig "${sysextroot}/usr/bin/"
  mv gadgetctl "${sysextroot}/usr/bin/"
}
# --
