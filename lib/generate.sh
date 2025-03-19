#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions for generating sysext imges from base directories.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

libroot="$(dirname "${BASH_SOURCE[0]}")"
source "${libroot}/helpers.sh"

#
#  ---------------- low level / helper functions ----------------
#

set -euo pipefail

function _check_format() {
  local fmt="$1"

  case "$fmt" in
    squashfs|btrfs|ext4|ext2)
        return 0;;
  esac

  echo "ERROR: unsupported sysext file system format '$fmt'."
  echo "Supported file system formats are: squashfs, btrfs, ext4, or ext2."

  exit 1
}
# --

function _check_basedir() {
  local basedir="$1"
  
  if [[ -z "$basedir" ]] || [[ ! -d "$basedir" ]] ; then
    echo "ERROR: invalid base directory '$basedir'"
    exit 1
  fi

  local fname
  ls -1 "$basedir" | while read fname; do
    case "$fname" in
      ".."|"."|usr|opt) continue;;
    esac

    echo "WARNING: file/directory '$basedir/$fname' not in 'usr/' or 'opt/'."
    echo "         It will NOT be present in the target file system after merge."
    echo "         ALL files must reside either below '${basedir}/usr/' or '${basedir}/opt/'."
    echo

  done

  return 0
}
# --

function _create_metadata() {
  local name="$1"
  local basedir="$2"
  local os="$3"
  local arch="$4"
  local force_reload="$5"

  local metadata_file="${basedir}/usr/lib/extension-release.d/extension-release.${name}"
  announce "Generating metadata in '${metadata_file}'"

  mkdir -p "$(dirname "${metadata_file}")"
  {
    echo "ID=${os}"
    if [[ ${os} != _any ]]; then
      echo "SYSEXT_LEVEL=1.0"
    fi
    echo "ARCHITECTURE=${arch}"
    if [[ ${force_reload} == true ]]; then
      echo "EXTENSION_RELOAD_MANAGER=1"
    fi
  } | tee "${metadata_file}"
  echo
}
# --

function _create_sysupdate() {
  local extname="$1"
  local match_pattern="${2:-${extname}-@v-%a.raw}"
  local target_path="${3:-/opt/extensions/${extname}}"

  sed -e "s/{EXTNAME}/${extname}/g" \
      -e "s/{MATCH_PATTERN}/${match_pattern}/g" \
      -e "s,{TARGET_PATH},${target_path},g" \
      "${libroot}/sysupdate.conf.tmpl" \
    >"${extname}.conf"

  echo "Generated sysupdate configuration '${extname}.conf'"
}
# --

function _generate_sysext() {
  local extname="$1"
  local basedir="$2"
  local format="$3"
  local ext_fs_size="$4"

  local filename="${extname}.raw"
  announce "Creating extension image '${filename}' and generating SHA256SUM"
  case "$format" in
    btrfs)
      mkfs.btrfs --mixed -m single -d single --shrink --rootdir "${basedir}" "${filename}"
      ;;
    ext2|ext4)
      truncate -s "${ext_fs_size}" "${filename}"
      mkfs."${format}" -E root_owner=0:0 -d "${basedir}" "${filename}"
      resize2fs -M "${filename}"
      ;;
    squashfs)
      mksquashfs "${basedir}" "${filename}" -all-root -noappend -xattrs-exclude '^btrfs.'
      ;;

  esac
  sha256sum "${filename}" > "SHA256SUMS.${extname}"
  announce "'${filename}' is now ready"
}
# --

#
#  ---------------- high level functions ----------------
#
function _generate_sysext_options() {
  echo " --name <name>:        Sysext (file) name ('<name>.raw')."
  echo "                       Defaults to 'basename \"\$basedir\"' if not set."
  echo " --os <os>:            OS version supported by the sysext. Either "_any" (the default)"
  echo "                         or a distro release version that must match the target distro's"
  echo "                         ID= field in /etc/os-release."
  echo " --force-reload <true|false>:"
  echo "                       Force the service manager to reload all service files on merge."
  echo "                         Helpful if the sysext ships service units that should be started"
  echo "                         at merge."
  echo " --sysupdate <true|false>:"
  echo "                       Generate a suitable sysupdate .conf file alongside the extension image."
  echo " --format <format>:    Sysext file system format. Defaults to 'squashfs'."
  echo " --ext-fs-size <size>: File system size when using --format ext2|ext4."
  echo "                       Defaults to 1G."
  echo " --epoch <epoch>:      Set SOURCE_DATE_EPOCH (defaults to "0") for reproducible builds."
  echo "                       See https://reproducible-builds.org/docs/source-date-epoch/"
  echo "                       for more information."
}
# --

function _generate_sysext_help() {
  echo " Create a system extension file system image from a base directory."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <basedir>: root base directory of the sysext's directory tree."
  echo "             If --name isn't set (see below), the basename of this directory"
  echo "               will be used as the sysext's name."
  echo "  <arch>   : CPU target architecture. Either 'x86-64' or 'arm64'."
  echo
  echo " Optional arguments:"
  _generate_sysext_options
  echo ""
}
# --

function generate_sysext() {
  local os="$(get_optional_param "os" "_any" "${@}")"
  local reload_services="$(get_optional_param "force-reload" "false" "${@}")"

  local format="$(get_optional_param "format" "squashfs" "${@}")"
  local ext_fs_size="$(get_optional_param "ext-fs-size" "1G" "${@}")"

  SOURCE_DATE_EPOCH="$(get_optional_param "epoch" "0" "${@}")"

  local basedir="$(get_positional_param "1" "${@}")"
  local arch="$(get_positional_param "2" "${@}")"

  if [[ -z ${basedir} ]] || [[ ${basedir} == help ]] ; then
    _generate_sysext_help
    exit
  fi

  # basic sanity
  check_arch "${arch}"
  _check_format "${format}"
  _check_basedir "${basedir}"

  local name="$(get_optional_param "name" "$(cd "$basedir"; basename "$(pwd)")" "${@}")"
  rm -f "${name}.raw"

  export SOURCE_DATE_EPOCH

  _create_metadata "$name" "$basedir" "$os" "$arch" "$reload_services"
  _generate_sysext "$name" "$basedir" "$format" "$ext_fs_size"

  local sysupdate="$(get_optional_param "sysupdate" "false" "${@}")"
  if [[ ${sysupdate} == true ]] ; then
    _create_sysupdate "${name}"
  fi
}
# --
