#!/bin/bash

set -euo pipefail
script_dir="$(dirname "$0")"

# --

function download_if_needed() {
  local arch="${1:-amd64}"

  local files=( flatcar_production_qemu_uefi.sh
                flatcar_production_qemu_uefi_efi_code.qcow2
                flatcar_production_qemu_uefi_efi_vars.qcow2
                flatcar_production_qemu_uefi_image.img )

  local download="false"

  local f
  for f in "${files[@]}"; do
    if [[ ! -e $f ]] ; then
      download="true"
    fi
  done

  if [[ "${download}" = false ]] ; then
    return
  fi

  echo "Flatcar image not found, downloading."

  rm -f "${files[@]}"
  curl -fL --retry-delay 1 --retry 60 --retry-connrefused --remote-name-all --parallel \
    "${files[@]/#/https://stable.release.flatcar-linux.net/${arch}-usr/current/}"

  # exec qemu in the wrapper script instead of running it in a subshell so we can easier kill it on shutdown
  sed -i 's/qemu-system-/exec qemu-system-/g' flatcar_production_qemu_uefi.sh
  chmod 755 flatcar_production_qemu_uefi.sh
}
# --

function webserver() {
  local path="$1"
  cd "${path}"
  exec docker run --rm \
      -p 8000:80 \
      -v "${PWD}":/usr/share/caddy \
  caddy
}
# --

function transpile_template() {
  local extension="$1"
  local tmplfile="$2"
  local outfile="$3"

  local yaml_tmp="$(mktemp)"

  sed "s/%EXTENSION_FILE%/${extension}/g" "${tmplfile}" > "${yaml_tmp}"

  docker run --rm \
      -v "${PWD}":/files \
      -i quay.io/coreos/butane:latest \
      --files-dir /files  \
    >"${outfile}" <"${yaml_tmp}"

  rm -f "${yaml_tmp}"
}
# --

function read_until() {
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

function flatcar_vm() {
  local cfg="$1"
  local log="$2"
  exec ./flatcar_production_qemu_uefi.sh -i "${cfg}" -snapshot -nographic 2>&1
}
# --

# Check if a systemd unit is active
function check_unit() {
  true
}
# --

# Check if a command returns a pre-defined output
function check_command() {


}
# --

# Move this into a library that test.sh imports.
# Base "bakery.sh test" on that.
if [[ ! -f "${1:-}" ]] ; then
  echo "Usage: $0 <sysext-file>"
  exit 1
fi

extension_arg="${1}"
extension="$(basename "${extension_arg}")"
extension_path="$(dirname "${extension_arg}")"

# optional args
# - custom yaml template
# - range of ports to open
# ...

download_if_needed

template="${script_dir}/test.yaml.tmpl"
json="$(mktemp)"
transpile_template "${extension}" "${template}" "${json}"

# remove background webserver, Flatcar VM on exit as well as provisioning config
trap "kill %1 %2; rm -f '${json}'" EXIT

webserver "${extension_path}" &

coproc flatcar { flatcar_vm "${json}" "test-vm.log" ; }
read_until "localhost login: core (automatic login)" <&"${flatcar[0]}"
sleep 1


