#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Main bakery script.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail

rundir="$(pwd)"
scriptroot="$(dirname "$(readlink -f "$0")")"
source "${scriptroot}/lib/libbakery.sh"

function usage() {
  echo
  echo "$0 <command> - run <command> on the sysext bakery."
  echo
  echo "Command is one of:"
  echo "  list [--plain true]           - Print a table of all sysexts available to build."
  echo "                                  If --plain is true, just print the extensions w/o table formatting."
  echo "  list <sysext> [--latest true] - List available releases of the project shipped by <sysext>."
  echo "                                  If --latest is true, list only the project's latest release(s)."
  echo "  list-bakery <sysext>          - List all Bakery release versions of <sysext>."
  echo "  create <sysext>               - Create the specified system extension."
  echo "  create <sysext> help          - List sysext specific parameters. Rarely used."
  echo
  echo "Use '$0 <command> help' to print help for a specific command."
  echo
}
# --

function _create_sysext_help() {
  echo
  echo "Create a sysext image."
  echo
  echo "Usage: create [options] <sysextname> <version>"
  echo "Positional (mandatory) arguments:"
  echo " <sysextname>:    Name of the extension image to build. Mandatory."
  echo "                    Use the 'list' command to get a list."
  echo " <version>:       Release version of the app/tool to be included in the sysext."
  echo "                  Use '$0 list <sysext>' to list all available versions."
  echo
  echo "Optional arguments:"
  echo " --arch <arch>:  Architecture supported by the sysext."
  echo "                    Either x86-64 (the default)  or arm64."
  echo " --bakery <url>: URL for the bakery."
  echo "                    Default is: extensions.flatcar.org"
  _generate_sysext_options
  if [[ $(type -t populate_sysext_root_options ) == function ]] ; then
    echo "Sysext specific optional parameters:"
    populate_sysext_root_options
  fi
  echo
}
# --

function _copy_static_files() {
  local extname="${1%%.sysext/}"
  local destdir="$2"

  local srcdir="${scriptroot}/${extname}.sysext/files"

  if [[ ! -d "${srcdir}" ]] ; then
    echo "No static files directory for '$extname'; continuing (no '${srcdir}')."
    return
  fi

  function _cpy() {
    local src="$1"
    local dst="$2"
    if [[ ! -d "$src" ]] ; then
      return
    fi

    mkdir -p "${dst}"
    cp -vR "${src}/"* "${dst}"
  }

  _cpy "${srcdir}/usr" "${destdir}/usr"
  _cpy "${srcdir}/opt" "${destdir}/opt"
}
# --

function create_sysext() {
  local extname="$(extension_name "$(get_positional_param "1" "${@}")")"

  if [[ -z ${extname} ]] || [[ ${extname} == help ]] ; then
    _create_sysext_help
    return
  fi

  local createscript="${scriptroot}/${extname}.sysext/create.sh"
  if [[ ! -f "${createscript}" ]] ; then
    echo "ERROR: Extension create implementation not found at '${createscript}'."
    return 1
  fi

  # Overwritten by extension's create.sh
  RELOAD_SERVICES_ON_MERGE="false"
  function populate_sysext_root() {
      announce "Nothing to do, static files only."
  }
  source "${createscript}"

  local arch="$(get_optional_param 'arch' 'x86-64' "${@}")"
  check_arch "$arch"

  local version="$(get_positional_param "2" "${@}")"
  if [[ -z ${version} ]] ; then
    echo "ERROR: missing mandatory <version> parameter"
    _create_sysext_help
    return 1
  fi

  if [[ ${version} == help ]] ; then
    _create_sysext_help
    return 1
  fi

  local workdir="$(mktemp -d)"
  local sysextroot_tmp="$(mktemp -d)"
  trap "rm -rf '${workdir}' '${sysextroot_tmp}'" EXIT
  local sysextroot="${sysextroot_tmp}/${extname}"
  mkdir -p "${sysextroot}"

  announce "Copying static files"
  _copy_static_files "$extname" "$sysextroot"

  announce "Populating extension root"
  # Do this in a subshell to safely change directories w/o confusing us
  (
    cd "${workdir}"
    populate_sysext_root "$sysextroot" "$arch" "$version" "${@}"
  )

  announce "Generating extension file system image"
  local force_reload=""
  if [[ ${RELOAD_SERVICES_ON_MERGE} == true ]] ; then
      force_reload="--force-reload true"
  fi
  generate_sysext "$sysextroot" "$arch" "${@}" $force_reload
}
# --

case "${1:-}" in
  list|list-bakery|create|test)
    cmd="${1}"
    shift
    "${cmd}"_sysext "${@}"
    ;;
  *) usage;
  ;;
esac
