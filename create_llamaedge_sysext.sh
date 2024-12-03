#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the llamaedge release tar ball (e.g., for 0.14.16) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="x86_64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="aarch64"
fi

# llamaedge is a wasm application, which requires WasmEdge and its WASI-NN GGML/GGUF plugin
WASMEDGE_VERSION="0.14.1"

# Download WasmEdge WASI-NN GGML/GGUF plugin
rm -f "WasmEdge-plugin-wasi_nn-ggml-${WASMEDGE_VERSION}.tar.gz"
curl -o "WasmEdge-plugin-wasi_nn-ggml-${WASMEDGE_VERSION}.tar.gz" -fsSL "https://github.com/WasmEdge/WasmEdge/releases/download/${WASMEDGE_VERSION}/WasmEdge-plugin-wasi_nn-ggml-${WASMEDGE_VERSION}-ubuntu20.04_${ARCH}.tar.gz"

# Download llamaedge api server
rm -f "llama-api-server.wasm"
curl -o "llama-api-server.wasm" -fsSL "https://github.com/LlamaEdge/LlamaEdge/releases/download/${VERSION}/llama-api-server.wasm"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"

tar --force-local -xvf "WasmEdge-plugin-wasi_nn-ggml-${WASMEDGE_VERSION}.tar.gz" -C "${SYSEXTNAME}"
mv "llama-api-server.wasm" "${SYSEXTNAME}"

rm "WasmEdge-plugin-wasi_nn-ggml-${WASMEDGE_VERSION}.tar.gz"

mkdir -p "${SYSEXTNAME}"/usr/lib/wasmedge # for plugins
mkdir -p "${SYSEXTNAME}"/usr/lib/wasmedge/wasm # for llamaedge application

mv "${SYSEXTNAME}"/libwasmedgePluginWasiNN.so "${SYSEXTNAME}"/usr/lib/wasmedge
mv "${SYSEXTNAME}"/llama-api-server.wasm "${SYSEXTNAME}"/usr/lib/wasmedge/wasm

"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
