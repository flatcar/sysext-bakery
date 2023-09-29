#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME [CNI_VERSION]"
  echo "The script will download the Kubernetes release binaries (e.g., for v1.27.3) and create a sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use arm64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  echo "CNI version current value is 'latest'"
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

VERSION="$1"
SYSEXTNAME="$2"
CNI_VERSION="${3-latest}"

# The github release uses different arch identifiers (not the same as in the other scripts here),
# we map them here and rely on bake.sh to map them back to what systemd expects
if [ "${ARCH}" = "x86_64" ] || [ "${ARCH}" = "x86-64" ]; then
  ARCH="amd64"
elif [ "${ARCH}" = "aarch64" ]; then
  ARCH="arm64"
fi

rm -f kubectl kubeadm kubelet

# install kubernetes binaries.
curl --parallel --fail --silent --show-error --location \
  --output kubectl "https://dl.k8s.io/${VERSION}/bin/linux/${ARCH}/kubectl" \
  --output kubeadm "https://dl.k8s.io/${VERSION}/bin/linux/${ARCH}/kubeadm" \
  --output kubelet "https://dl.k8s.io/${VERSION}/bin/linux/${ARCH}/kubelet"

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"/usr/bin
mv kubectl kubeadm kubelet "${SYSEXTNAME}"/usr/bin

chmod +x "${SYSEXTNAME}"/usr/bin/{kubectl,kubeadm,kubelet}

# setup kubelet service.
mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/kubelet.service" <<-'EOF'
[Unit]
Description=kubelet: The Kubernetes Node Agent
Documentation=https://kubernetes.io/docs/home/
Wants=network-online.target
After=network-online.target

[Service]
ExecStart=/usr/bin/kubelet
Restart=always
StartLimitInterval=0
RestartSec=10

[Install]
WantedBy=multi-user.target
EOF

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/kubelet.service.d"
cat > "${SYSEXTNAME}/usr/lib/systemd/system/kubelet.service.d/10-kubeadm.conf" <<-'EOF'
# Note: This dropin only works with kubeadm and kubelet v1.11+
[Service]
Environment="KUBELET_KUBECONFIG_ARGS=--bootstrap-kubeconfig=/etc/kubernetes/bootstrap-kubelet.conf --kubeconfig=/etc/kubernetes/kubelet.conf"
Environment="KUBELET_CONFIG_ARGS=--config=/var/lib/kubelet/config.yaml"
# This is a file that "kubeadm init" and "kubeadm join" generates at runtime, populating the KUBELET_KUBEADM_ARGS variable dynamically
EnvironmentFile=-/var/lib/kubelet/kubeadm-flags.env
# This is a file that the user can use for overrides of the kubelet args as a last resort. Preferably, the user should use
# the .NodeRegistration.KubeletExtraArgs object in the configuration files instead. KUBELET_EXTRA_ARGS should be sourced from this file.
EnvironmentFile=-/etc/sysconfig/kubelet
ExecStart=
ExecStartPre=/usr/bin/mkdir -p /opt/cni/bin
ExecStartPre=/usr/bin/cp -r /usr/local/bin/cni/. /opt/cni/bin/
ExecStartPre=/usr/bin/cp /usr/local/share/kubernetes-version /etc/kubernetes-version
ExecStartPre=/usr/bin/mkdir -p /var/kubernetes/kubelet-plugins/volume/exec/
ExecStart=/usr/bin/kubelet $KUBELET_KUBECONFIG_ARGS $KUBELET_CONFIG_ARGS $KUBELET_KUBEADM_ARGS $KUBELET_EXTRA_ARGS
EOF

mkdir -p "${SYSEXTNAME}/usr/local/share/"
echo "${VERSION}" > "${SYSEXTNAME}/usr/local/share/kubernetes-version"

mkdir -p "${SYSEXTNAME}/usr/libexec/kubernetes/kubelet-plugins/volume/"
# /var/kubernetes/... will be created at runtime by the kubelet unit.
ln -sf "/var/kubernetes/kubelet-plugins/volume/exec" "${SYSEXTNAME}/usr/libexec/kubernetes/kubelet-plugins/volume/exec"

mkdir -p "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d"
{ echo "[Unit]"; echo "Upholds=kubelet.service"; } > "${SYSEXTNAME}/usr/lib/systemd/system/multi-user.target.d/10-kubelet-service.conf"

# install CNI.
version="${CNI_VERSION}"
if [[ "${CNI_VERSION}" == "latest" ]]; then
  version=$(curl -fsSL https://api.github.com/repos/containernetworking/plugins/releases/latest | jq -r .tag_name)
  echo "Using latest version: ${version} for CNI plugins"
fi
curl -o cni.tgz -fsSL "https://github.com/containernetworking/plugins/releases/download/${version}/cni-plugins-linux-${ARCH}-${version}.tgz"
mkdir -p "${SYSEXTNAME}/usr/local/bin/cni"
tar --force-local -xf "cni.tgz" -C "${SYSEXTNAME}/usr/local/bin/cni"

"${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
