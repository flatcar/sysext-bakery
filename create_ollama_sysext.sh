#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download ollama release binaries (e.g., for v0.3.9) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

VERSION="v${VERSION#v}"

TARBALL="ollama-linux-${ARCH}.tgz"
SHASUM="sha256sum.txt"

TARBALL_URL="https://github.com/ollama/ollama/releases/download/${VERSION}/${TARBALL}"
SHASUM_URL="https://github.com/ollama/ollama/releases/download/${VERSION}/${SHASUM}"

rm -rf "${SYSEXTNAME}"

TMP_DIR="${SYSEXTNAME}/tmp"
mkdir -p "${TMP_DIR}"

curl --parallel --fail --silent --show-error --location \
  --output "${TMP_DIR}/${TARBALL}" "${TARBALL_URL}" \
  --output "${TMP_DIR}/${SHASUM}" "${SHASUM_URL}"

pushd "${TMP_DIR}" > /dev/null
grep "${TARBALL}$" "${SHASUM}" | sha256sum -c -
popd  > /dev/null

mkdir -p "${SYSEXTNAME}/usr/local"

tar --force-local -xf "${TMP_DIR}/${TARBALL}" -C "${SYSEXTNAME}/usr/local"
chmod +x "${SYSEXTNAME}/usr/local/bin/ollama"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/ollama.service" <<-'EOF'
[Unit]
Description=Ollama
Documentation=https://github.com/ollama/ollama/tree/main/docs
Wants=network-online.target
After=network-online.target

[Service]
Environment="HOME=/var/lib/ollama"
Environment="OLLAMA_MODELS=/var/lib/ollama/models"
Environment="OLLAMA_RUNNERS_DIR=/var/lib/ollama/runners"
ExecStart=/usr/local/bin/ollama serve
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=ollama.service"; } > "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d/10-ollama.conf

rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
