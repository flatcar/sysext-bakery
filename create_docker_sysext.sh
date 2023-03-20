#!/bin/bash
set -euo pipefail

ARCH="${ARCH-x86_64}"
OS="${OS-flatcar}"
ONLY_CONTAINERD="${ONLY_CONTAINERD:-0}"
ONLY_DOCKER="${ONLY_DOCKER:-0}"
FORMAT="${FORMAT:-squashfs}"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the Docker release tar ball (e.g., for 20.10.13) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "The necessary systemd services will be created by this script, by default only docker.socket will be enabled."
  echo "To only package containerd without Docker, pass ONLY_CONTAINERD=1 as environment variable (current value is '${ONLY_CONTAINERD}')."
  echo "To only package Docker without containerd and runc, pass ONLY_DOCKER=1 as environment variable (current value is '${ONLY_DOCKER}')."
  echo "To use arm64 pass 'ARCH=aarch64' as environment variable (current value is '${ARCH}')."
  echo "To build for another OS than Flatcar, pass 'OS=myosid' as environment variable (current value is '${OS}'), e.g., 'fedora' as found in 'ID' under '/etc/os-release'."
  echo "The '/etc/os-release' file of your OS has to include 'SYSEXT_LEVEL=1.0' as done in Flatcar."
  echo "If the mksquashfs tool is missing you can pass FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2 as environment variable but the files won't be owned by root."
  echo
  exit 1
fi

if [ "${ONLY_CONTAINERD}" = 1 ] && [ "${ONLY_DOCKER}" = 1 ]; then
  echo "Cannot set both ONLY_CONTAINERD and ONLY_DOCKER" >&2
  exit 1
fi
if [ "${FORMAT}" != "squashfs" ] && [ "${FORMAT}" != "btrfs" ] && [ "${FORMAT}" != "ext4" ] && [ "${FORMAT}" != "ext2" ]; then
  echo "Expected FORMAT=squashfs, FORMAT=btrfs, FORMAT=ext4, or FORMAT=ext2 got '${FORMAT}'" >&2
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"

rm -f "docker-${VERSION}.tgz"
curl -o "docker-${VERSION}.tgz" -fsSL "https://download.docker.com/linux/static/stable/${ARCH}/docker-${VERSION}.tgz"
# TODO: Also allow to consume upstream containerd and runc release binaries with their respective versions
rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"
tar --force-local -xf "docker-${VERSION}.tgz" -C "${SYSEXTNAME}"
rm "docker-${VERSION}.tgz"
mkdir -p "${SYSEXTNAME}"/usr/bin
mv "${SYSEXTNAME}"/docker/* "${SYSEXTNAME}"/usr/bin/
rmdir "${SYSEXTNAME}"/docker
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
if [ "${ONLY_CONTAINERD}" = 1 ]; then
  rm "${SYSEXTNAME}/usr/bin/docker" "${SYSEXTNAME}/usr/bin/dockerd" "${SYSEXTNAME}/usr/bin/docker-init" "${SYSEXTNAME}/usr/bin/docker-proxy"
elif [ "${ONLY_DOCKER}" = 1 ]; then
  rm "${SYSEXTNAME}/usr/bin/containerd" "${SYSEXTNAME}/usr/bin/containerd-shim" "${SYSEXTNAME}/usr/bin/containerd-shim-runc-v2" "${SYSEXTNAME}/usr/bin/ctr" "${SYSEXTNAME}/usr/bin/runc"
fi
if [ "${ONLY_CONTAINERD}" != 1 ]; then
  cat > "${SYSEXTNAME}/usr/lib/systemd/system/docker.socket" <<-'EOF'
	[Unit]
	PartOf=docker.service
	Description=Docker Socket for the API
	[Socket]
	ListenStream=/var/run/docker.sock
	SocketMode=0660
	SocketUser=root
	SocketGroup=docker
	[Install]
	WantedBy=sockets.target
EOF
  mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/sockets.target.d"
  { echo "[Unit]"; echo "Upholds=docker.socket"; } > "${SYSEXTNAME}/usr/lib/systemd/system/sockets.target.d/10-docker-socket.conf"
  cat > "${SYSEXTNAME}/usr/lib/systemd/system/docker.service" <<-'EOF'
	[Unit]
	Description=Docker Application Container Engine
	After=containerd.service docker.socket network-online.target
	Wants=network-online.target
	Requires=containerd.service docker.socket
	[Service]
	Type=notify
	EnvironmentFile=-/run/flannel/flannel_docker_opts.env
	Environment=DOCKER_SELINUX=--selinux-enabled=true
	ExecStart=/usr/bin/dockerd --host=fd:// --containerd=/run/containerd/containerd.sock $DOCKER_SELINUX $DOCKER_OPTS $DOCKER_CGROUPS $DOCKER_OPT_BIP $DOCKER_OPT_MTU $DOCKER_OPT_IPMASQ
	ExecReload=/bin/kill -s HUP $MAINPID
	LimitNOFILE=1048576
	# Having non-zero Limit*s causes performance problems due to accounting overhead
	# in the kernel. We recommend using cgroups to do container-local accounting.
	LimitNPROC=infinity
	LimitCORE=infinity
	# Uncomment TasksMax if your systemd version supports it.
	# Only systemd 226 and above support this version.
	TasksMax=infinity
	TimeoutStartSec=0
	# set delegate yes so that systemd does not reset the cgroups of docker containers
	Delegate=yes
	# kill only the docker process, not all processes in the cgroup
	KillMode=process
	# restart the docker process if it exits prematurely
	Restart=on-failure
	StartLimitBurst=3
	StartLimitInterval=60s
	[Install]
	WantedBy=multi-user.target
EOF
fi
if [ "${ONLY_DOCKER}" != 1 ]; then
  cat > "${SYSEXTNAME}/usr/lib/systemd/system/containerd.service" <<-'EOF'
	[Unit]
	Description=containerd container runtime
	After=network.target
	[Service]
	Delegate=yes
	Environment=CONTAINERD_CONFIG=/usr/share/containerd/config.toml
	ExecStartPre=mkdir -p /run/docker/libcontainerd
	ExecStartPre=ln -fs /run/containerd/containerd.sock /run/docker/libcontainerd/docker-containerd.sock
	ExecStart=/usr/bin/containerd --config ${CONTAINERD_CONFIG}
	KillMode=process
	Restart=always
	# (lack of) limits from the upstream docker service unit
	LimitNOFILE=1048576
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
	version = 2
	# set containerd's OOM score
	oom_score = -999
	[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc]
	# setting runc.options unsets parent settings
	runtime_type = "io.containerd.runc.v2"
	[plugins."io.containerd.grpc.v1.cri".containerd.runtimes.runc.options]
	SystemdCgroup = true
EOF
  sed 's/SystemdCgroup = true/SystemdCgroup = false/g' "${SYSEXTNAME}/usr/share/containerd/config.toml" > "${SYSEXTNAME}/usr/share/containerd/config-cgroupfs.toml"
fi
mkdir -p "${SYSEXTNAME}/usr/lib/extension-release.d"
{ echo "ID=${OS}" ; echo "SYSEXT_LEVEL=1.0" ; } > "${SYSEXTNAME}/usr/lib/extension-release.d/extension-release.${SYSEXTNAME}"
rm -f "${SYSEXTNAME}".raw
if [ "${FORMAT}" = "btrfs" ]; then
  # Note: We didn't chown to root:root, meaning that the file ownership is left as is
  mkfs.btrfs --mixed -m single -d single --shrink --rootdir "${SYSEXTNAME}" "${SYSEXTNAME}".raw
  # This is for testing purposes and makes not much sense to use because --rootdir doesn't allow to enable compression
elif [ "${FORMAT}" = "ext4" ] || [ "${FORMAT}" = "ext2" ]; then
  # Assuming that 1 GB is enough
  truncate -s 1G "${SYSEXTNAME}".raw
  # Note: We didn't chown to root:root, meaning that the file ownership is left as is
  mkfs."${FORMAT}" -E root_owner=0:0 -d "${SYSEXTNAME}" "${SYSEXTNAME}".raw
  resize2fs -M "${SYSEXTNAME}".raw
else
  mksquashfs "${SYSEXTNAME}" "${SYSEXTNAME}".raw -all-root
fi
rm -rf "${SYSEXTNAME}"
echo "Created ${SYSEXTNAME}.raw"
