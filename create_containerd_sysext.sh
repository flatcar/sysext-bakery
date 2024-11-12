#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-amd64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the containerd release tar ball (e.g., for 1.7.23) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

# The github release uses different arch identifiers (not the same as in the other scripts here),
# we map them here and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

# Download containerd
rm -f containerd-static-*
curl --remote-name -fsSL "https://github.com/containerd/containerd/releases/download/v${VERSION}/containerd-static-${VERSION}-linux-${ARCH}.tar.gz{,.sha256sum}"
sha256sum --check "containerd-static-${VERSION}-linux-${ARCH}.tar.gz.sha256sum"

# Create the sysext folder
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
tar --force-local -xf "containerd-static-${VERSION}-linux-${ARCH}.tar.gz" -C "${SYSEXTNAME}"
rm containerd-static-*

# Install containerd binaries and runc
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/bin/* "${SYSEXTNAME}"/usr/bin/
rmdir "${SYSEXTNAME}"/bin
runc_version=$(curl -fsSL "https://raw.githubusercontent.com/containerd/containerd/refs/tags/v${VERSION}/script/setup/runc-version")
echo "Downloading associated runc version: ${runc_version}"
curl --remote-name -fsSL "https://github.com/opencontainers/runc/releases/download/${runc_version}/runc.{${ARCH},sha256sum}"
sha256sum --ignore-missing -c runc.sha256sum
mv "runc.${ARCH}" "${SYSEXTNAME}/usr/bin/runc"
rm runc.sha256sum
chmod a+x "${SYSEXTNAME}/usr/bin/runc"

# Install systemd configuration
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/containerd.service" <<-'EOF'
[Unit]
Description=containerd container runtime
After=network.target
[Service]
Delegate=yes
Environment=CONTAINERD_CONFIG=/usr/share/containerd/config.toml
ExecStart=/usr/bin/containerd --config ${CONTAINERD_CONFIG}
KillMode=process
Restart=always
LimitNPROC=infinity
LimitCORE=infinity
TasksMax=infinity
[Install]
WantedBy=multi-user.target
EOF
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=containerd.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-containerd-service.conf"
mkdir -p "${SYSEXTNAME}/usr/share/containerd"
cat > "${SYSEXTNAME}/usr/share/containerd/config.toml" <<-'EOF'
version = 3
# set containerd's OOM score
oom_score = -999
[plugins.'io.containerd.cri.v1.runtime'.containerd.runtimes.runc.options]
  SystemdCgroup = true
EOF
sed 's/SystemdCgroup = true/SystemdCgroup = false/g' "${SYSEXTNAME}/usr/share/containerd/config.toml" > "${SYSEXTNAME}/usr/share/containerd/config-cgroupfs.toml"

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
