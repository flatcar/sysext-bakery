#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download cilium release binaries (e.g., for v0.16.24) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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

TARBALL="cilium-linux-${ARCH}.tar.gz"
SHASUM="${TARBALL}.sha256sum"

TARBALL_URL="https://github.com/cilium/cilium-cli/releases/download/${VERSION}/${TARBALL}"
SHASUM_URL="https://github.com/cilium/cilium-cli/releases/download/${VERSION}/${SHASUM}"

rm -rf "${SYSEXTNAME}"

TMP_DIR="${SYSEXTNAME}/tmp"
mkdir -p "${TMP_DIR}"

curl --parallel --fail --silent --show-error --location \
  --output "${TMP_DIR}/${TARBALL}" "${TARBALL_URL}" \
  --output "${TMP_DIR}/${SHASUM}" "${SHASUM_URL}"

pushd "${TMP_DIR}" > /dev/null
grep "${TARBALL}$" "${SHASUM}" | sha256sum -c -
popd  > /dev/null

mkdir -p "${SYSEXTNAME}/usr/local/bin"

tar --force-local -xf "${TMP_DIR}/${TARBALL}" -C "${SYSEXTNAME}/usr/local/bin"
chmod +x "${SYSEXTNAME}/usr/local/bin/cilium"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/cilium.service" <<-'EOF'
[Unit]
Description=Install cilium to running k8s cluster
Documentation=https://docs.cilium.io/en/stable
Wants=network-online.target
After=network-online.target

[Service]
Environment=KUBECONFIG='/home/core/.kube/config'
ExecStart=/opt/bin/cilium install ${CILIUM_INSTALL_ARGS}
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=cilium.service"; } > "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d/10-cilium.conf

rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
