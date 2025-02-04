#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download nebula release binaries and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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

TARBALL="nebula-linux-${ARCH}.tar.gz"
SHASUM="SHASUM256.txt"

TARBALL_URL="https://github.com/slackhq/nebula/releases/download/${VERSION}/${TARBALL}"
SHASUM_URL="https://github.com/slackhq/nebula/releases/download/${VERSION}/${SHASUM}"

rm -rf "${SYSEXTNAME}"

TMP_DIR="${SYSEXTNAME}/tmp"
mkdir -p "${TMP_DIR}"

curl --parallel --fail --silent --show-error --location \
  --output "${TMP_DIR}/${TARBALL}" "${TARBALL_URL}" \
  --output "${TMP_DIR}/${SHASUM}" "${SHASUM_URL}"

pushd "${TMP_DIR}" > /dev/null
grep "${TARBALL}$" "${SHASUM}" | sha256sum -c -
popd  > /dev/null

mkdir -p "${SYSEXTNAME}/usr/bin"

tar --force-local -xf "${TMP_DIR}/${TARBALL}" -C "${SYSEXTNAME}/usr/bin"
chmod +x "${SYSEXTNAME}/usr/bin/nebula"
chmod +x "${SYSEXTNAME}/usr/bin/nebula-cert"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/nebula.service" <<-'EOF'
[Unit]
Description=Nebula overlay networking tool
Wants=basic.target network-online.target nss-lookup.target time-sync.target
After=basic.target network.target network-online.target

[Service]
Type=notify
NotifyAccess=main
SyslogIdentifier=nebula
ExecReload=/bin/kill -HUP $MAINPID
ExecStart=/usr/bin/nebula -config /etc/nebula/config.yaml
Restart=always

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=nebula.service"; } > "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d/10-nebula.conf

rm -rf "${TMP_DIR}"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
