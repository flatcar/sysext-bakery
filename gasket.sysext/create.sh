#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Gasket sysext.
#

RELOAD_SERVICES_ON_MERGE="true"
ORG="KyleGospo"
PROJECT="gasket-dkms"

function list_available_versions() {
  # Gasket does not have any tags nor releases.
  # As a replacement, we use the branch names.
  curl_api_wrapper \
      "https://api.github.com/repos/${ORG}/${PROJECT}/branches" \
      | jq -r '.[].name' \
      | sort -Vr
}

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  mkdir -p "${sysextroot}/usr/share/flatcar"
    cat <<EOF >"${sysextroot}/usr/share/flatcar/gasket-metadata"
GASKET_REPOSITORY=https://github.com/${ORG}/${PROJECT}.git
GASKET_BRANCH=${version}
EOF

  chmod +x "${sysextroot}/usr/lib/gasket/bin/install-gasket"
  chmod +x "${sysextroot}/usr/lib/gasket/bin/setup-gasket"
}