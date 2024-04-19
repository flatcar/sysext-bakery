#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME [NATS_VERSION]"
  echo "The script will download the wasmcloud release (e.g. 1.0.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"
NATS_VERSION="${3-latest}"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="x86_64"
  GOARCH="amd64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="aarch64"
  GOARCH="arm64"
else
  echo "Unknown architecture ('${ARCH}') provided, supported values are 'amd64', 'arm64'."
  exit 1
fi

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin

VERSION="v${VERSION#v}"
curl -o "${SYSEXTNAME}"/usr/bin/wasmcloud -fsSL "https://github.com/wasmcloud/wasmcloud/releases/download/${VERSION}/wasmcloud-${ARCH}-unknown-linux-musl"
chmod +x "${SYSEXTNAME}"/usr/bin/wasmcloud

# Install NATS
version="${NATS_VERSION}"
if [[ "${NATS_VERSION}" == "latest" ]]; then
  version=$(curl -fsSL https://api.github.com/repos/nats-io/nats-server/releases/latest | jq -r .tag_name)
  echo "Using latest version: ${version} for NATS Server"
fi
version="v${version#v}"

rm -f "nats-server.tar.gz"
curl -o nats-server.tar.gz -fsSL "https://github.com/nats-io/nats-server/releases/download/${version}/nats-server-${version}-linux-${GOARCH}.tar.gz"
tar -xf "nats-server.tar.gz" -C "${SYSEXTNAME}"
mv "${SYSEXTNAME}/nats-server-${version}-linux-${GOARCH}/nats-server" "${SYSEXTNAME}/usr/bin/"
rm -r "${SYSEXTNAME}/nats-server-${version}-linux-${GOARCH}"
rm "nats-server.tar.gz"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/wasmcloud.service" <<-'EOF'
[Unit]
Description=wasmCloud Host
Documentation=https://wasmcloud.com/docs/
After=nats.service network-online.target
Wants=network-online.target
Requires=nats.service
[Service]
ExecStart=/usr/bin/wasmcloud
Restart=always
StartLimitInterval=0
RestartSec=5
[Install]
WantedBy=multi-user.target
EOF

# Based on https://github.com/nats-io/nats-server/blob/main/util/nats-server.service
cat > "${SYSEXTNAME}/usr/lib/systemd/system/nats.service" <<-'EOF'
[Unit]
Description=NATS Server
After=network-online.target systemd-timesyncd.service
[Service]
PrivateTmp=true
Type=simple
Environment=NATS_CONFIG=/usr/share/nats/nats.conf
ExecStart=/usr/bin/nats-server --jetstream --config ${NATS_CONFIG}
ExecReload=/bin/kill -s HUP $MAINPID
ExecStop=/bin/kill -s SIGINT $MAINPID
# The nats-server uses SIGUSR2 to trigger using Lame Duck Mode (LDM) shutdown
KillSignal=SIGUSR2
# You might want to adjust TimeoutStopSec too.
[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=wasmcloud.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-wasmcloud-service.conf"
{ echo "[Unit]"; echo "Upholds=nats.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-nats-service.conf"

mkdir -p "${SYSEXTNAME}/usr/share/nats"
cat > "${SYSEXTNAME}/usr/share/nats/nats.conf" <<-'EOF'
port: 4222
monitor_port: 8222
EOF

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
