#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the k0s binary (e.g., for v1.31.2+k0s.0) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
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
    ARCH="amd64"
fi
if [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then
    ARCH="arm64"
fi

URL="https://github.com/k0sproject/k0s/releases/download/${VERSION}/k0s-${VERSION}-${ARCH}"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/local/bin
curl -o "${SYSEXTNAME}/usr/local/bin/k0s" -fsSL "${URL}"
chmod +x "${SYSEXTNAME}"/usr/local/bin/k0s
pushd "${SYSEXTNAME}"/usr/local/bin/
ln -s ./k0s kubectl
ln -s ./k0s ctr
popd

mkdir -p "${SYSEXTNAME}"/usr/local/lib/systemd/system/
cat > "${SYSEXTNAME}"/usr/local/lib/systemd/system/k0s.service << EOF
[Unit]
Description=k0s - Init Controller / External ETCD Controller
Documentation=https://docs.k0sproject.io
ConditionFileIsExecutable=/usr/local/bin/k0s

Requires=containerd.service
Wants=network-online.target
After=network-online.target containerd.service

[Service]
EnvironmentFile=-/etc/default/k0s
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/bin/sh -c '[ -n "${CRI_SOCKET}" ] && exec /usr/local/bin/k0s controller --config=/etc/k0s/k0s.yaml --cri-socket=${CRI_SOCKET} || exec /usr/local/bin/k0s controller --config=/etc/k0s/k0s.yaml'

RestartSec=10
Delegate=yes
KillMode=process
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
LimitNOFILE=999999
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > "${SYSEXTNAME}"/usr/local/lib/systemd/system/k0scontroller.service << EOF
[Unit]
Description=k0s - Controller
Documentation=https://docs.k0sproject.io
ConditionFileIsExecutable=/usr/local/bin/k0s

Requires=containerd.service
Wants=network-online.target
After=network-online.target containerd.service

[Service]
EnvironmentFile=-/etc/default/k0s
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/bin/sh -c '[ -n "${CRI_SOCKET}" ] && exec /usr/local/bin/k0s controller --config=/etc/k0s/k0s.yaml --cri-socket=${CRI_SOCKET} --token-file=/etc/k0s/controller-token|| exec /usr/local/bin/k0s controller --config=/etc/k0s/k0s.yaml --token-file=/etc/k0s/controller-token'

RestartSec=10
Delegate=yes
KillMode=process
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
LimitNOFILE=999999
Restart=always

[Install]
WantedBy=multi-user.target
EOF

cat > "${SYSEXTNAME}"/usr/local/lib/systemd/system/k0sworker.service << EOF
[Unit]
Description=k0s - Worker
Documentation=https://docs.k0sproject.io
ConditionFileIsExecutable=/usr/local/bin/k0s

Requires=containerd.service
Wants=network-online.target
After=network-online.target containerd.service

[Service]
EnvironmentFile=-/etc/default/k0s
StartLimitInterval=5
StartLimitBurst=10
ExecStart=/usr/local/bin/k0s worker --cri-socket=$CRI_SOCKET --token-file=/etc/k0s/worker-token
ExecStart=/bin/sh -c '[ -n "${CRI_SOCKET}" ] && exec /usr/local/bin/k0s worker --cri-socket=${CRI_SOCKET} --token-file=/etc/k0s/worker-token|| exec /usr/local/bin/k0s worker --token-file=/etc/k0s/worker-token'

RestartSec=10
Delegate=yes
KillMode=process
LimitCORE=infinity
TasksMax=infinity
TimeoutStartSec=0
LimitNOFILE=999999
Restart=always

[Install]
WantedBy=multi-user.target
EOF

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
