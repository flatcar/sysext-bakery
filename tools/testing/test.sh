#!/bin/bash

set -euo pipefail

if [[ ! -f "${1:-}" ]] ; then
  echo "Usage: $0 <sysext-file>"
  exit 1
fi

extension_arg="${1}"
extension="$(basename "${extension_arg}")"
extension_path="$(dirname "${extension_arg}")"

# --

function download_if_needed() {
  local files=( flatcar_production_qemu_uefi.sh
                flatcar_production_qemu_uefi_efi_code.qcow2
                flatcar_production_qemu_uefi_efi_vars.qcow2
                flatcar_production_qemu_uefi_image.img )

  local download="false"

  local f
  for f in "${files[@]}"; do
    if [ ! -e "$f" ] ; then
      download="true"
    fi
  done

  if [[ "${download}" = false ]] ; then
    return
  fi

  echo "Flatcar image not found, downloading."

  for f in "${files[@]}"; do
    rm -f "$f"
    curl -fL --progress-bar --retry-delay 1 --retry 60 --retry-connrefused --remote-name "https://stable.release.flatcar-linux.net/amd64-usr/current/$f"
  done

  chmod 755 flatcar_production_qemu_uefi.sh
}
# --

function webserver() {
  local path="$1"
  cd "${path}"
  exec docker run -i --rm \
      -p 8000:80 \
      -v "$(pwd)":/usr/share/caddy \
  caddy
}
# --

download_if_needed

sed -s "s/EXTENSION/${extension}/g" "test.yaml.tmpl" > "test.yaml"
cat test.yaml \
    | docker run --rm \
      -v "$(pwd)":/files \
      -i quay.io/coreos/butane:latest \
      --files-dir /files  \
    > test.json

trap 'kill %1' EXIT
webserver "${extension_path}" &

./flatcar_production_qemu_uefi.sh -i test.json -snapshot -nographic
