#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-x86-64}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 2 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 VERSION SYSEXTNAME"
  echo "The script will download the sysdig falco binary (e.g., for 0.38.0) and create a sysext squashfs image with the name falco.raw in the current folder."
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
  URL="https://download.falco.org/packages/bin/x86_64/falco-${VERSION}-x86_64.tar.gz"
elif [ "${ARCH}" = "arm64" ] || [ "${ARCH}" = "aarch64" ]; then
  URL="https://download.falco.org/packages/bin/aarch64/falco-${VERSION}-aarch64.tar.gz"
fi

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}"{/usr/share/falco/etc/,/usr/lib/tmpfiles.d,/usr/local/lib/systemd/system/}

cat <<EOF >"${SYSEXTNAME}"/usr/lib/tmpfiles.d/10-falco.conf
C+ /etc/falco - - - - /usr/share/falco/etc/falco
EOF

curl -o - -fsSL "${URL}" | tar --strip-components 1 -xzvf - -C "${SYSEXTNAME}/"
mv "${SYSEXTNAME}"{/etc/{falco,falcoctl},/usr/share/falco/etc/}

cat > "${SYSEXTNAME}"/usr/local/lib/systemd/system/falco-modern-bpf.service <<'EOF'
[Unit]
Description=Falco: Container Native Runtime Security with modern ebpf
Documentation=https://falco.org/docs/
Before=falcoctl-artifact-follow.service
Wants=falcoctl-artifact-follow.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/falco -o engine.kind=modern_ebpf
ExecReload=kill -1 $MAINPID
UMask=0077
TimeoutSec=30
RestartSec=15s
Restart=on-failure
PrivateTmp=true
NoNewPrivileges=yes
ProtectHome=read-only
ProtectSystem=full
ProtectKernelTunables=true
RestrictRealtime=true
RestrictAddressFamilies=~AF_PACKET
StandardOutput=null

[Install]
WantedBy=multi-user.target
EOF

cat > "${SYSEXTNAME}"/usr/local/lib/systemd/system/falcoctl-artifact-follow.service << EOF
[Unit]
Description=Falcoctl Artifact Follow: automatic artifacts update service
Documentation=https://falco.org/docs/
PartOf=falco-bpf.service falco-kmod.service falco-modern-bpf.service falco-custom.service

[Service]
Type=simple
User=root
ExecStart=/usr/bin/falcoctl artifact follow --allowed-types=rulesfile
UMask=0077
TimeoutSec=30
RestartSec=15s
Restart=on-failure
PrivateTmp=true
NoNewPrivileges=yes
ProtectSystem=true
ReadWriteDirectories=/usr/share/falco
ProtectKernelTunables=true
RestrictRealtime=true

[Install]
WantedBy=multi-user.target
EOF

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
rm -rf "${SYSEXTNAME}"
