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

function list_github_releases() {
  local org="$1"
  local project="$2"

  curl -fsSL "https://api.github.com/repos/${org}/${project}/releases" \
    | jq -r 'map_values(select(.prerelease == false)) | .[].tag_name' \
    | sort -Vr
}
# --

function list_github_tags() {
  local org="$1"
  local project="$2"

  curl -fsSL "https://api.github.com/repos/${org}/${project}/tags" \
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
