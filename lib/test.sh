#!/bin/bash
# vim: et ts=2 syn=bash
#
# Bakery library functions for testing sysexts in a local Flatcar qemu instance.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail

libroot="$(dirname "${BASH_SOURCE[0]}")"
source "${libroot}/helpers.sh"


_flatcar_image_files=( flatcar_production_qemu_uefi.sh
                       flatcar_production_qemu_uefi_efi_code.qcow2
                       flatcar_production_qemu_uefi_efi_vars.qcow2
                       flatcar_production_qemu_uefi_image.img )

# --

function _need_os_image_download() {
  local f="" download="false"

  for f in "${_flatcar_image_files[@]}"; do
    if [[ ! -e $f ]] ; then
      download="true"
    fi
  done

  $download
}
# --

function _download_os_image() {
  local arch="${1:-amd64}"

  rm -f "${_flatcar_image_files[@]}"
  curl -fL --retry-delay 1 --retry 60 --retry-connrefused --remote-name-all --parallel \
    "${_flatcar_image_files[@]/#/https://stable.release.flatcar-linux.net/${arch}-usr/current/}"

  chmod 755 flatcar_production_qemu_uefi.sh
}
# --

function _transpile_template() {
  local extension="$1"
  local name="$2"
  local tmplfile="$3"
  local outfile="$4"

  local yaml="config.yaml"

  sed -e "s/%EXTENSION_FILE%/${extension}/g" \
      -e "s/%EXTENSION_NAME%/${name}/g" \
        "${tmplfile}" > "${yaml}"

  docker run --rm \
      -v "${PWD}":/files \
      -i quay.io/coreos/butane:latest \
      --files-dir /files  \
    >"${outfile}" <"${yaml}"
}
# --

function _populate_workdir() {
  local workdir="$1"
  local extension="$2"
  local extension_file="$(basename "${extension}")"
  local extension_name="$(get_optional_param "name" "${extension}" "${@}")"

  local arch="$(get_optional_param "arch" "amd64" "${@}")"
  local template="$(get_optional_param "template" "${libroot}/test.yaml.tmpl" "${@}")"
  local template_file="$(basename "${template}")"
 
  if _need_os_image_download; then
    echo "No OS images found in current directory, downloading..."
    _download_os_image "${arch}"
  fi 

  cp "${_flatcar_image_files[@]}" \
        "${extension}" \
        "${template}" \
     "${workdir}/" 

  _transpile_template "${extension_file}" "${extension_name}" \
                      "${workdir}/${template_file}" \
                      "${workdir}/test.json"
}
# --

function _flatcar_vm() {
  local cfg="$1"
  local ports="${2:-}"

  if [[ -n $ports ]] ; then
    # flatcar script wants "-f host:vm [-f host2:vm2 ...]"
    ports="-f ${ports//,/ -f }"
  fi

  # Convert all exits to returns so we can safely source it
  sed -i 's/\<exit\>/return /g' \
        "flatcar_production_qemu_uefi.sh"

  set -- "-i ${cfg}" $ports "-snapshot" "-nographic"
  source ./flatcar_production_qemu_uefi.sh
}
# --

function _read_until() {
  local match="$1"

  while read line; do
    echo "VM:  $line"
    if [[ $line == *"${match}"* ]] ; then
      echo " -- MATCH FOUND: '${match}'"
      break
    fi
  done
}
# --

# Check if a systemd unit is active
function check_unit() {
  true
}
# --

# Check if a command returns a pre-defined output
function check_command() {
  true
}
# --

#
#  ---------------- high level functions ----------------
#
function _test_help() {
  echo "Run tests for a system extension image in a local Flatcar VM."
  echo
  echo "This command runs all tests included with the sysext directory ('<name>.sysext/test.sh')"
  echo "locally, in a Flatcar VM. The latest stable OS image will be downloaded if no Flatcar image is"
  echo "present locally."
  echo
  echo "The extension image to be tested must exist locally (e.g. as a result of 'bakery.sh create')"
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <sysext>: Extension image to run tests for. The extension image file must exist."
  echo
  echo " Optional arguments:"
  echo " --name <name> : Name of the extension (in extension metadata), including suffix ('.raw')."
  echo "                 Defaults to the extension filename ('<sysext>' argument)."
}
# --

function _test_interactive_help() {
  echo "Interactively test a system extension file in a local Flatcar VM."
  echo
  echo "This command launches a local Flatcar test VM for interactively testing and exploring extension images."
  echo "The latest stable OS image will be downloaded if no Flatcar image is present locally."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <sysext>: Extension image to include. The extension image file must be available (built)."
  echo
  echo " Optional arguments:"
  echo " --name <name> : Name of the extension (in extension metadata), including suffix ('.raw')."
  echo "                 Defaults to the extension filename ('<sysext>' argument)."
  echo " --template my-template.yaml: Custom provisioning template to use. Must be Butane YAML."
  echo "                              '%EXTENSION_FILE%' in the template will be"
  echo "                               replaced with the <sysext> file name,"
  echo "                              '%EXTENSION_NAME%' with the --name argument."
  echo " --ports <host>:<vm>[,<host>:<vm>...]: Forward ports into the VM. Will"
  echo "                                       override ports defined by the respective extension's"
  echo "                                       test implementation."
}
# --

function _test_common() {
  local extension="$(get_positional_param "1" "${@}")"
  local workdir="$(mktemp -d)"

  set -euo pipefail
  if [[ ! -f "${extension}" ]] || [[ ${extension} == help  ]] ; then
    return 1
  fi

  echo "Preparing temporary working directory"
  _populate_workdir "$workdir" "${extension}" "${@}"

  # cleanup: webserver, flatcar VM (non-interactive mode), work dir
  trap "kill %1 %2 >/dev/null 2>&1; rm -rf '${workdir}'" EXIT

  webserver "${workdir}" &

  cd "${workdir}"
}
# --

function test-interactive_sysext() {
  # Run in a sub-shell b/c this will change into a temporary working directory
  (
    if ! _test_common "${@}" ; then
      _test_interactive_help
      exit
    fi

    local ports="$(get_optional_param "ports" "" "${@}")"
    _flatcar_vm "test.json" "${ports}"
  )
}
# --

function test_sysext() {
  # Run in a sub-shell b/c this will change into a temporary working directory
  (
    if ! _test_common "${@}" ; then
      _test_help
      exit
    fi

    local ports="$(get_optional_param "ports" "" "${@}")"
    coproc flatcar { _flatcar_vm "${workdir}" "$ports" ; }

    _read_until "localhost login: core (automatic login)" <&"${flatcar[0]}"

    sleep 1
  )
}
