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
  list_github_releases "fosrl" "cli"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  mkdir -p "${sysextroot}/usr/local/bin"

  arch="$(arch_transform 'x86-64' 'amd64' "${arch}")"

  binary_url="https://github.com/fosrl/cli/releases/download/${version}/pangolin-cli_linux_${arch}"
  echo "Downloading ${binary_url}"
  curl --fail --silent --show-error --location \
    --output "${sysextroot}/usr/local/bin/pangolin" "${binary_url}"

  chmod +x "${sysextroot}/usr/local/bin/pangolin"
}
# --
