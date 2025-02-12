#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Rebuild all sysexts and compare with pre-built images.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail

# run 'gh release download latest -R flatcar/sysext-bakery'
# in download dir to fetch all sysexts in "latest"
orig_dir="$1"

banner() {
  echo   "#################################################################################################################"
  printf "###### %100.100s #####\n" "${@}"
  echo   "#################################################################################################################"
}
# --

declare -A extensions

while read ext ver arch; do
  extensions["$ext-$ver-$arch.raw"]="$ext $ver $arch"
done < <(ls -1 ${orig_dir}/ | grep -E '.raw$' | sed -e 's/.*\///' -e 's/-\([^-]\+\)-\(arm64\|x86-64\)\.raw/ \1 \2/')

for e in ${!extensions[@]}; do
  a=( ${extensions[$e]} )
  ext=${a[0]}
  ver=${a[1]}
  arch=${a[2]}

  build_ver="$ver"
  extra_param=""
  case $ext in
    nvidia_runtime) ext=nvidia-runtime ;;
    docker_compose) ext=docker-compose ;;
    llamaedge) extra_param="--wasmedge-version 0.14.1" ;;
    nebula) build_ver="v${ver#v}" ;;
    ollama) build_ver="v${ver#v}" ;;
    wasmtime) build_ver="v${ver#v}" ;;
    wasmcloud) build_ver="v${ver#v}" ;;
  esac

  if [[ -f "$e" ]] ; then
    echo "$e exists - skipping."
    continue
  fi

  banner "Building '$e' - $ext $ver $arch"

  if ! ./bakery.sh create "$ext" "$build_ver" --arch "$arch" $extra_param ; then
    echo "BUILD FAIL: $e"
    continue
  fi

  echo "$e build succeeded."
  mv "$ext".raw "$e"
done

for e in ${!extensions[@]}; do
  banner "Comparing '$e' -> ${orig_dir}/$e"

  if [[ ! -f "$e" ]] ; then
    echo "$e does not exist."
    continue
  fi

  if ! tools/compare.sh "$e" "${orig_dir}/$e" ; then
    echo "COMPARE FAIL: $e"
  fi
  echo "$e compare succeeded."
done
