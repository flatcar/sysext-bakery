#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the cri-o release binaries (e.g., for v1.28.4) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  echo "CNI version current value is 'latest'"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# For compatibility with existing automation.
[[ "${VERSION}" == v* ]] || VERSION="v${VERSION}"

# The github release uses different arch identifiers (not the same as in the other scripts here),
# we map them here and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

rm -f "cri-o.${ARCH}.${VERSION}.tar.gz"
curl -o "cri-o.${ARCH}.${VERSION}.tar.gz" -fsSL "https://storage.googleapis.com/cri-o/artifacts/cri-o.${ARCH}.${VERSION}.tar.gz"
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}" "${SYSEXTNAME}/tmp"
tar --force-local -xf "cri-o.${ARCH}.${VERSION}.tar.gz" -C "${SYSEXTNAME}/tmp"
cd "${SYSEXTNAME}/tmp/cri-o/"
sed -i '/^sed -i.*DESTDIR/d' install # removes sed replacements from install script to keep the default location (/usr) in the base config file
DESTDIR="${PWD}/../../../${SYSEXTNAME}" PREFIX=/usr ETCDIR=$PREFIX/share/crio/etc OCIDIR=$PREFIX/share/oci-umount/oci-umount.d \
  CNIDIR=$PREFIX/share/crio/cni/etc/net.d/ OPT_CNI_BIN_DIR=$PREFIX/share/crio/cni/bin/  BASHINSTALLDIR=/tmp FISHINSTALLDIR=/tmp ZSHINSTALLDIR=/tmp MANDIR=/tmp ./install 
cd -
rm -rf "${SYSEXTNAME}/tmp" 


cat > "${SYSEXTNAME}"/usr/share/crio/etc/crio/crio.conf <<'EOF'
# /etc/crio/crio.conf - Configuration file for crio
# See /etc/crio/crio.conf.d/ for additional config files 
#
EOF

cat > "${SYSEXTNAME}"/usr/share/crio/README-flatcar <<'EOF'
To use kubernetes with crio in flatcar, you will need to pass the criSocket to kubeadm. 
Eg: kubeadm init --pod-network-cidr=10.244.0.0/16 --kubernetes-version v1.29.2 --cri-socket=unix:///var/run/crio/crio.sock'
EOF


mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/crio.service.d
cat > "${SYSEXTNAME}"/usr/lib/systemd/system/crio.service.d/10-crio.conf <<-'EOF'
[Service]
Environment="CONTAINER_CNI_PLUGIN_DIR=/opt/cni/bin"
Environment="CONTAINER_CONFIG=/etc/crio/crio.conf"
Environment="CONTAINER_CNI_CONFIG_DIR=/etc/cni/net.d"
ExecStartPre=/usr/bin/mkdir -p /opt/cni/bin /etc/crio/crio.conf.d/ /etc/cni/net.d/ /var/log/crio
ExecStartPre=/usr/bin/rsync -ur /usr/share/crio/etc/ /etc/
ExecStart=
ExecStart=/usr/bin/crio --config-dir /etc/crio/crio.conf.d/ \
          $CRIO_CONFIG_OPTIONS \
          $CRIO_RUNTIME_OPTIONS \
          $CRIO_STORAGE_OPTIONS \
          $CRIO_NETWORK_OPTIONS \
          $CRIO_METRICS_OPTIONS
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d
{ echo "[Unit]"; echo "Upholds=crio.service"; } > "${SYSEXTNAME}"/usr/lib/systemd/system/multi-user.target.d/10-crio.conf

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
