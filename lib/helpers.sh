#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library helper functions.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

function get_optional_param() {
  local param="$1"
  local default="$2"
  shift 2

  while [[ $# -gt 0 ]] ; do
    case "$1" in
      --"$param")
          echo "$2"
          return;;
    esac
    shift
  done

  echo "$default"
}
# --

function get_positional_param() {
  local num="$1"
  shift

  local curr=1
  while [[ $# -gt 0 ]] ; do
    case "$1" in
      --*) shift;;
      *) if [[ $num -eq $curr ]] ; then
           echo "$1"
           return
         fi
         : $((curr++))
         ;;
    esac
    shift
  done
}
# --

function get_all_positional_params() {
  while [[ $# -gt 0 ]] ; do
    case "$1" in
      --*) shift ;;
      *) echo "$1" ;;
    esac
    shift
  done
}
# --

function check_arch() {
  local arch="$1"

  case "$arch" in
    x86-64|arm64)
        return 0;;
  esac

  echo "ERROR: unsupported architecture '$arch'."
  echo "Supported architecures are x86-64 and arm64."

  exit 1
}
# --

function arch_transform() {
  local src="$1"
  local target="$2"
  local arch="$3"

  case "$arch" in
    "$src") echo "$target";;
    *) echo "$arch";;
  esac
}
# --

function announce() {
  echo "    ----- ===== ##### $@ ##### ===== -----"
}
# --

function curl_api_wrapper() {
  local url="${@}"

  if [[ -n ${GH_TOKEN:-} ]] ; then
    auth=( "-H" "Authorization: Bearer $GH_TOKEN" )
  fi

  local curl="curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused"
  curl="$curl --retry-max-time 60 --connect-timeout 20"

  # pagination: get number of result pages.
  # See https://docs.github.com/en/rest/using-the-rest-api/using-pagination-in-the-rest-api?apiVersion=2022-11-28
  local pages="$($curl "${auth[@]}" --head "${url}" \
                    | grep -E '^link:' \
                    | sed -r 's/.*<[^<>]+page=([0-9]+)>;[[:space:]]*rel="last".*/\1/')"
  local page
  for page in $(seq 1 $pages); do
    $curl "${auth[@]}" "${url}?page=$page"
  done

}
# --

function list_github_releases() {
  local org="$1"
  local project="$2"

  curl_api_wrapper \
    "https://api.github.com/repos/${org}/${project}/releases" \
    | jq -r 'map_values(select(.prerelease == false)) | .[].tag_name' \
    | sort -Vr
}
# --

function github_release_exists() {
  local org="$1"
  local project="$2"
  local tag="$3"

  curl_api_wrapper \
    "https://api.github.com/repos/${org}/${project}/releases/tags/${tag}" >/dev/null 2>&1
}
# --

function list_gitlab_tags() {
  local instance="$1"
  local projectid="$2"

  local curl="curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused"
  curl="$curl --retry-max-time 60 --connect-timeout 20"

  $curl \
    "https://${instance}/api/v4/projects/${projectid}/repository/tags" \
    | jq -r '.[].name' \
    | sort -Vr
}
# --

function list_github_tags() {
  local org="$1"
  local project="$2"

  curl_api_wrapper \
    "https://api.github.com/repos/${org}/${project}/tags" \
    | jq -r '.[].name' \
    | sort -Vr
}
# --

function extension_name() {
  local extname="${1:-}"
  extname="${extname%%.sysext/}"
  extname="${extname%%.sysext}"

  local folder="${scriptroot}/${extname}.sysext"
  if [[ -d ${folder} ]] ; then
    echo "${extname}"
  fi
}
# --

# Filter the latest version from an extension's version list.
# Must be called with the extension "create.sh" script sourced.
function list_latest_release() {
  list_available_versions | head -n 1
}
# --

# Run a local webserver.
function webserver() {
  local path="$1"
  local port="${2:-12345}"

  cd "${path}"

  exec docker run --rm \
      -p "${port}":80 \
      -v "${PWD}":/usr/share/caddy \
  caddy
}
# --

function transpile() {
  local yamlfile="$1"
  local outfile="$2"

  # We pass the YAML file directory into the container so additional local resources
  #  to be merged into the provisioning JSON can be specified there.
  local yamldir="$(dirname "${yamlfile}")"

  docker run --rm \
      -v "${yamldir}":/files \
      -i quay.io/coreos/butane:latest \
      --files-dir /files  \
    >"${outfile}" <"${yamlfile}"
}
# --
