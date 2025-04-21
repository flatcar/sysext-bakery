#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Gasket sysext.
#

RELOAD_SERVICES_ON_MERGE="true"

function list_available_versions() {
  # Gasket does not have any tags nor releases.
  # As a replacement, we use the branch names.
  local org="KyleGospo"
  local project="gasket-dkms"
  curl_api_wrapper \
      "https://api.github.com/repos/${org}/${project}/branches" \
      | jq -r '.[].name' \
      | sort -Vr
}

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  # Only shipping static service files
}