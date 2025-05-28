#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Llamaedge sysext. This sysext depends on the WasmEdge sysext.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "LlamaEdge" "LlamaEdge"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local wasmedge_version="$(get_optional_param "wasmedge-version" "" "${@}")"
  if [[ -z $wasmedge_version ]] ; then
      echo "SORRY! Unable to continue. --wasmedge-version parameter MUST be set."
      echo " See 'bakery.sh create LlamaEdge help' for more information."
      exit 1
  fi

  local rel_arch="$(arch_transform "x86-64" "x86_64" "$arch")"
  rel_arch="$(arch_transform "arm64" "aarch64" "$rel_arch")"

  curl -o "WasmEdge-plugin.tar.gz" \
       -fsSL "https://github.com/WasmEdge/WasmEdge/releases/download/${wasmedge_version}/WasmEdge-plugin-wasi_nn-ggml-${wasmedge_version}-ubuntu20.04_${rel_arch}.tar.gz"
  curl -o "llama-api-server.wasm" \
       -fsSL "https://github.com/LlamaEdge/LlamaEdge/releases/download/${version}/llama-api-server.wasm"

  tar --force-local -xzf "WasmEdge-plugin.tar.gz"
  mkdir -p "${sysextroot}"/usr/lib/wasmedge/wasm "${sysextroot}"/usr/share/llamaedge/

  cp -a libwasmedgePluginWasiNN.so "${sysextroot}"/usr/lib/wasmedge
  cp -a llama-api-server.wasm "${sysextroot}"/usr/lib/wasmedge/wasm

  echo "${wasmedge_version}" > "${sysextroot}"/usr/share/llamaedge/wasmedge-version
}
# --

function populate_sysext_root_options() {
  echo "  --wasmedge-version <version>  : Version of WasmEdge in the WasmEdge sysext."
  echo "            This parameter is required. It must be set to the version of the"
  echo "             WasmEdge sysext used in combination with LlamaEdge."
  echo "            The LlamaEdge sysext depends on WasmEdge. LlamaEdge ships a plugin"
  echo "             that depends on the WasmEdge version."
  echo "            In order for the build to include the correct WasmEdge plugin version,"
  echo "             this parameter must be set."
}
# --
