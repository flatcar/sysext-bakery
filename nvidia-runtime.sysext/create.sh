#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# NVIDIA runtime (userspace tools) extension.
#

RELOAD_SERVICES_ON_MERGE="false"

function list_available_versions() {
  list_github_releases "NVIDIA" "nvidia-container-toolkit"
}
# --

function populate_sysext_root() {
  local sysextroot="$1"
  local arch="$2"
  local version="$3"

  local rel_arch="$(arch_transform "x86-64" "amd64" "$arch")"

  announce "Building NVIDIA user space tools in Docker container. This may take some time."

  mkdir -p in out

  cd in

  git clone -b ${version} --depth 1 --recurse-submodules --shallow-submodules https://github.com/NVIDIA/nvidia-container-toolkit
  if [ "${version}" == v1.18.1 ]; then
    pushd nvidia-container-toolkit
    git am "${scriptroot}/nvidia-runtime.sysext/0001-nvidia-runtime-1.18.1-go-dl.patch"
    git am "${scriptroot}/nvidia-runtime.sysext/0002-nvidia-runtime-1.18.1-submodule-update.patch"
    popd
  fi

  pushd nvidia-container-toolkit
  ./scripts/build-packages.sh ubuntu18.04-${rel_arch}
  popd

  cp "${scriptroot}/nvidia-runtime.sysext/extract.sh" .

  cd ..

  announce "Extracting NVIDIA user space tools from DEB packages."

  local export_user_group="$(id -u):$(id -g)"
  docker run -i --rm \
             -v "$(pwd)/in":/in \
             -v "$(pwd)/out":/out \
              alpine \
               /in/extract.sh "$rel_arch"  "${export_user_group}"

  rm -rf out/usr/share

  mkdir -p "${sysextroot}/usr/bin/"
  mkdir -p "${sysextroot}/usr/lib64/"
  mkdir -p "${sysextroot}/usr/local/"
  mkdir -p "${sysextroot}/usr/lib/systemd/sytem/"
  mkdir -p "${sysextroot}/usr/share/flatcar/etc/"

  cp -aR out/etc/systemd/. "${sysextroot}/usr/lib/systemd/"
  cp -aR out/etc/nvidia-container-toolkit "${sysextroot}/usr/share/flatcar/etc/"
  cp -aR out/usr/bin/* "${sysextroot}/usr/bin/"
  cp -aR out/usr/lib/*-linux-gnu/* "${sysextroot}/usr/lib64/"

  ln -s /opt/nvidia "${sysextroot}/usr/local/nvidia"
}
# --
