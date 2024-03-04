#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will build nvidia-container-toolkit on ubuntu 18 and package it into a syseext."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

# Default should be: v1.14.3
VERSION="$1"
SYSEXTNAME="$2"

# The github release uses different arch identifiers, we map them here
# and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "amd64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "arm64" ]; then
  ARCH="arch64"
fi

git clone -b ${VERSION} --depth 1 https://github.com/NVIDIA/libnvidia-container || true
git clone -b ${VERSION} --depth 1 https://github.com/NVIDIA/nvidia-container-toolkit || true

make -C libnvidia-container ubuntu18.04-${ARCH}
make -C nvidia-container-toolkit ubuntu18.04-${ARCH}

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
for deb in libnvidia-container/dist/ubuntu18.04/${ARCH}/libnvidia-container{1_*,-tools_}*.deb; do
  dpkg-deb -x $deb "${SYSEXTNAME}"/
done
for deb in nvidia-container-toolkit/dist/ubuntu18.04/${ARCH}/nvidia-container-toolkit*.deb; do
  dpkg-deb -x $deb "${SYSEXTNAME}"/
done
rm -rf "${SYSEXTNAME}"/usr/share
mv "${SYSEXTNAME}"/usr/lib/*-linux-gnu "${SYSEXTNAME}"/usr/lib64
mkdir -p "${SYSEXTNAME}"/usr/local
ln -s /opt/nvidia "${SYSEXTNAME}"/usr/local/nvidia
ln -s /opt/bin/nvidia-smi "${SYSEXTNAME}"/usr/bin/nvidia-smi

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/docker.service.d
cat <<EOF >"${SYSEXTNAME}"/usr/lib/systemd/system/docker.service.d/10-nvidia.conf
[Unit]
After=nvidia.service

[Service]
Environment=DOCKER_OPTS=--add-runtime=nvidia=nvidia-container-runtime
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/containerd.service.d
cat <<EOF >"${SYSEXTNAME}"/usr/lib/systemd/system/containerd.service.d/10-nvidia.conf
[Unit]
After=nvidia.service

[Service]
ExecStart=
ExecStart=/usr/bin/containerd --config /etc/containerd/config.toml
EOF

mkdir -p "${SYSEXTNAME}"/usr/lib/systemd/system/nvidia.service.d
cat <<EOF >"${SYSEXTNAME}"/usr/lib/systemd/system/nvidia.service.d/10-persistenced.conf
[Service]
ExecStartPost=-/opt/bin/nvidia-persistenced
ExecStartPost=-/bin/sh -c "chcon -R -t container_file_t /dev/nvidia*"
ExecStartPost=mkdir -p /run/extensions
ExecStartPost=ln -s /opt/nvidia/current /run/extensions/nvidia-driver
ExecStartPost=systemctl restart systemd-sysext
EOF


mkdir -p "${SYSEXTNAME}"/usr/lib/tmpfiles.d/
cat <<EOF >"${SYSEXTNAME}"/usr/lib/tmpfiles.d/10-nvidia.conf
C /etc/containerd/config.toml - - - - /usr/share/flatcar/etc/containerd/config.toml
C /etc/nvidia-container-runtime/config.toml - - - - /usr/share/flatcar/etc/nvidia-container-runtime/config.toml
EOF

mkdir -p "${SYSEXTNAME}"/usr/share/flatcar/etc/nvidia-container-runtime/
cat <<EOF >"${SYSEXTNAME}"/usr/share/flatcar/etc/nvidia-container-runtime/config.toml
#accept-nvidia-visible-devices-as-volume-mounts = false
#accept-nvidia-visible-devices-envvar-when-unprivileged = true
disable-require = false
supported-driver-capabilities = "compat32,compute,display,graphics,ngx,utility,video"
#swarm-resource = "DOCKER_RESOURCE_GPU"

[nvidia-container-cli]
#debug = "/var/log/nvidia-container-toolkit.log"
environment = []
#ldcache = "/etc/ld.so.cache"
ldconfig = "@/sbin/ldconfig"
load-kmods = true
#no-cgroups = false
#path = "/usr/bin/nvidia-container-cli"
#root = "/run/nvidia/driver"
#user = "root:video"

[nvidia-container-runtime]
#debug = "/var/log/nvidia-container-runtime.log"
log-level = "info"
mode = "auto"
runtimes = ["docker-runc", "runc", "crun"]

[nvidia-container-runtime.modes]

[nvidia-container-runtime.modes.cdi]
annotation-prefixes = ["cdi.k8s.io/"]
default-kind = "nvidia.com/gpu"
spec-dirs = ["/etc/cdi", "/var/run/cdi"]

[nvidia-container-runtime.modes.csv]
mount-spec-path = "/etc/nvidia-container-runtime/host-files-for-container.d"

[nvidia-container-runtime-hook]
path = "nvidia-container-runtime-hook"
skip-mode-detection = false

[nvidia-ctk]
path = "nvidia-ctk"
EOF

mkdir -p "${SYSEXTNAME}"/usr/share/flatcar/etc/containerd/
cat <<EOF >"${SYSEXTNAME}"/usr/share/flatcar/etc/containerd/config.toml
version = 2

# persistent data location
root = "/var/lib/containerd"
# runtime state information
state = "/run/containerd"
# set containerd as a subreaper on linux when it is not running as PID 1
subreaper = true
# set containerd's OOM score
oom_score = -999
disabled_plugins = []

# grpc configuration
[grpc]
address = "/run/containerd/containerd.sock"
# socket uid
uid = 0
# socket gid
gid = 0

[plugins."io.containerd.runtime.v1.linux"]
# shim binary name/path
shim = "containerd-shim"
# runtime binary name/path
runtime = "runc"
# do not use a shim when starting containers, saves on memory but
# live restore is not supported
no_shim = false

[plugins."io.containerd.grpc.v1.cri"]
# enable SELinux labeling
enable_selinux = true

[plugins."io.containerd.grpc.v1.cri".containerd]
default_runtime_name = "nvidia"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
# setting runc.options unsets parent settings
runtime_type = "io.containerd.runc.v2"
[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
SystemdCgroup = true

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia]
runtime_type = "io.containerd.runc.v2"

[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.nvidia.options]
BinaryName = "/usr/bin/nvidia-container-runtime"
SystemdCgroup = true
EOF

mkdir -p "${SYSEXTNAME}"/usr/bin
"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
