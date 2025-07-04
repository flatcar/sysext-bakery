#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions to boot a Flatcar image with a list of sysexts provisioned.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

_flatcar_image_files=( flatcar_production_qemu_uefi.sh
                       flatcar_production_qemu_uefi_efi_code.qcow2
                       flatcar_production_qemu_uefi_efi_vars.qcow2
                       flatcar_production_qemu_uefi_image.img )

# --

function _need_os_image_download() {
  local arch="${1}"
  local f="" download="false"

  for f in "${_flatcar_image_files[@]}"; do
    if [[ ! -e $f ]] ; then
      echo "OS image file '$f' is missing."
      download="true"
    fi
  done

  if ! $download; then
    local img_arch="$(sed --silent --regexp-extended \
                        "s/VM_BOARD='(amd64|arm64)-usr'/\1/p" \
                        flatcar_production_qemu_uefi.sh)"
    if [[ $arch != $img_arch ]] ; then
      echo "OS image files present but architecture of image '$img_arch' does not match architecture of sysext '$arch'"
      download="true"
    fi
  fi

  $download
}
# --

function _download_os_image() {
  local arch="${1:-amd64}"

  if ! _need_os_image_download "${arch}" ; then
    return
  fi

  echo "Downloading OS image to local directory."

  rm -f "${_flatcar_image_files[@]}"
  curl -fL --retry-delay 1 --retry 60 --retry-connrefused --remote-name-all --parallel \
    "${_flatcar_image_files[@]/#/https://stable.release.flatcar-linux.net/${arch}-usr/current/}"

  chmod 755 flatcar_production_qemu_uefi.sh
}
# --

_generate_butane() {
 cat <<EOF
version: 1.0.0
variant: flatcar

storage:
  files:
EOF

  local e=""
  for e in "${@}"; do
    cat <<EOF
    - path: /etc/extensions/${e}
      mode: 0644
      contents:
        # QEmu's default traffic-to-host IP
        source: http://10.0.2.2:12345/${e}
EOF
  done

 cat <<EOF
systemd:
  units:
    - name: update-engine.service
      mask: true
    - name: locksmithd.service
      mask: true
EOF
}
# --

function _generate_config() {
  local workdir="$1"
  local butane_file="$2"
  shift; shift

  if [[ -z "${butane_file}" ]] ; then
    butane_file="${workdir}/boot.yaml"
    _generate_butane "${@}" > "${butane_file}"
  elif [[ ! -f "${butane_file}" ]]; then
    echo "ERROR: Unable to find butane config '${butane_file}'"
    return 1
  fi

  transpile "${butane_file}" "${workdir}/boot.json"
}
# --

function _flatcar_vm() {
  local cfg="$1"
  local ports="${2:-}"

  if [[ -n $ports ]] ; then
    # flatcar script wants "-f host:vm [-f host2:vm2 ...]"
    ports="-f ${ports//,/ -f }"
  fi

  ./flatcar_production_qemu_uefi.sh -i "${cfg}" $ports "-snapshot" "-nographic"
}
# --

function _boot_help() {
  echo "Boot a local Flatcar VM and provision one or more extension(s) for interactive testing."
  echo
  echo "This command launches a local Flatcar test VM for interactively testing and exploring extension images."
  echo "The latest stable OS image will be downloaded if no Flatcar image is present locally."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <sysext> [<sysext ...]: Extension image(s) to include. The extension image file(s) must be available (built)."
  echo
  echo " Optional arguments:"
  echo " --butane <yaml-file> : Custom provisioning YAML file to use instead of auto-generating one."
  echo "                        All <sysext> files specified as positional arguments will be served to the VM"
  echo "                        via 'http://10.0.2.2:12345/'. This http source can be used in custom YAML."
  echo " --ports <host>:<vm>[,<host>:<vm>...]: Forward ports into the VM."
  echo " --arch <amd64|arm64>: Architecture of the extension file(s). Note that a non-native architecture"
  echo "                        VM will be software emulated and significantly slower."

}
# --

function boot_sysext() {
  # Run in a sub-shell b/c we will change into a temporary working directory
  (
    set -euo pipefail
    local workdir="$(mktemp -d)"
    local extensions=() extension_files=() extension=""

    for extension in $(get_all_positional_params "$@"); do
      if [[ ${extension} == help  ]] ; then
        _boot_help
        return
      fi

      if [[ ! -f "${extension}" ]] ; then
        echo "ERROR: Extension file '${extension}' not found."
        exit 1
      fi
      extensions+=( "$extension" )
      extension_files+=( "$(basename "$extension")" )
    done

    echo "Preparing temporary working directory"

    local butane="$(get_optional_param "butane" "" "${@}")"
    if ! _generate_config "${workdir}" "${butane}" "${extension_files[@]}"; then
      exit 1
    fi

    local arch="$(get_optional_param "arch" "amd64" "${@}")"
    _download_os_image "${arch}"

    cp "${_flatcar_image_files[@]}" \
        "${extensions[@]}" \
        "${workdir}/" 
    # clean up: webserver and work dir
    trap "kill %1 >/dev/null 2>&1; rm -rf '${workdir}'" EXIT

    webserver "${workdir}" &

    cd "${workdir}"
    local ports="$(get_optional_param "ports" "" "${@}")"
    _flatcar_vm "boot.json" "${ports}"
  )
}
# --
