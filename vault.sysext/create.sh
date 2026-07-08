#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#

RELOAD_SERVICES_ON_MERGE="true"

# The HashiCorp releases API caps ?limit at 20 and returns newest first,
# so walk pages via ?after=<timestamp> until a short page comes back
# (last page) or the safety cap trips. Emit versions as they arrive so
# `--latest true` can abort after the first fetch.
function list_available_versions() {
  local base="https://api.releases.hashicorp.com/v1/releases/vault"
  local after=""
  local max_pages=20
  local curl_opts=(
    -fsSL
    --retry-delay 1 --retry 60 --retry-connrefused
    --retry-max-time 60 --connect-timeout 20
  )

  local page
  for page in $(seq 1 "$max_pages") ; do
    local response
    if [[ -z "$after" ]] ; then
      response="$(curl "${curl_opts[@]}" "${base}?limit=20")"
    else
      response="$(curl "${curl_opts[@]}" -G \
        --data-urlencode "limit=20" \
        --data-urlencode "after=${after}" \
        "${base}")"
    fi

    local count
    count="$(printf '%s' "$response" | jq 'length')"
    [[ "$count" -eq 0 ]] && break

    printf '%s' "$response" | jq -r '.[] | select(.is_prerelease == false)
                                         | select(.license_class == "oss")
                                         | .version'

    [[ "$count" -lt 20 ]] && break

    after="$(printf '%s' "$response" | jq -r '.[-1].timestamp_created')"
  done
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch
  rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"
  curl -fsSLZO --retry-delay 1 --retry 60 \
    --retry-connrefused --retry-max-time 60 --connect-timeout 20 \
    "https://releases.hashicorp.com/vault/${version}/vault_${version}_linux_${rel_arch}.zip"
  # Unzip the binary
  mkdir -p "${sysextroot}/usr/bin"
  unzip -q "vault_${version}_linux_${rel_arch}.zip"
  install -m 0755 vault "${sysextroot}/usr/bin"
}
# --
