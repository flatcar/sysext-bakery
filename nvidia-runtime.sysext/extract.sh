#!/bin/ash
#
# Build script helper for NVIDIA sysext.
# This script runs inside an ephemeral alpine container to extract DEB packages.
# It extracts NVIDIA userspace binaries to a bind-mounted volume.
#
set -euo pipefail

arch="$1"
export_user_group="$2"

apk --no-cache add dpkg

cd /in

for deb in \
        libnvidia-container/dist/ubuntu18.04/${arch}/libnvidia-container1_*.deb \
        libnvidia-container/dist/ubuntu18.04/${arch}/libnvidia-container-tools*.deb; do
  dpkg-deb -x $deb /out/
done

for deb in nvidia-container-toolkit/dist/ubuntu18.04/${arch}/nvidia-container-toolkit*.deb; do
  dpkg-deb -x $deb /out
done

chown -R "$export_user_group" /in
chown -R "$export_user_group" /out
