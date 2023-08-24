#!/bin/bash
set -euo pipefail

export ARCH="${ARCH-amd64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the Teleport release binaries (e.g., for v9.6.23) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"
if [ "${ARCH}" = aarch64 ]; then
  ARCH=arm64
fi
rm -f teleport

# install teleport binaries.
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin
curl "https://get.gravitational.com/teleport-v${VERSION}-linux-${ARCH}-bin.tar.gz" | tar xvz -C "${SYSEXTNAME}"/usr/bin --strip-components=1 teleport/teleport

chmod +x "${SYSEXTNAME}"/usr/bin/teleport

# setup kubelet service.
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/teleport.service" <<-'EOF'
[Unit]
Description=Teleport SSH Service
After=network.target
After=systemd-machine-id-commit.service
Requires=systemd-machine-id-commit.service


[Service]
Type=simple
Restart=on-failure
# Set the nodes roles with the `--roles`
# In most production environments you will not
# want to run all three roles on a single host
# --roles='proxy,auth,node' is the default value
# if none is set
ExecStart=/usr/bin/teleport start --roles=node --config=/etc/teleport.yaml --pid-file=/run/teleport.pid --token=$(cat /etc/machine-id)
ExecReload=/bin/kill -HUP $MAINPID
PIDFile=/run/teleport.pid
LimitNOFILE=524288

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=teleport.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-teleport-service.conf"

"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
