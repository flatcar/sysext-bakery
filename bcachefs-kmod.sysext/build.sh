#!/bin/bash
#
# Build script helper for the bcachefs-kmod sysext.
# Runs inside the Flatcar SDK container (ghcr.io/flatcar/flatcar-sdk-all).
# Builds bcachefs.ko using koverstreet/bcachefs-tools's dkms/ harness
# against the kernel source shipped by the SDK, then exports the .ko
# plus a modules-load.d snippet to the bind-mounted /install_root.
set -euo pipefail

bcachefs_version="$1"     # koverstreet/bcachefs-tools tag, e.g. v1.25.2
export_user_group="$2"

# 1. Fetch Flatcar's Portage tree + kernel sources ------------------------
#
# The SDK image ships emerge but not the Portage tree; emerge-gitclone
# clones it on first use. coreos-modules pulls in coreos-sources as a
# dependency, drops the kernel source with Flatcar's patches applied at
# /usr/src/linux-<kver>-flatcar, and runs modules_prepare so we end up
# with a build-usable KDIR (Module.symvers, generated headers, etc.).
emerge-gitclone
emerge -gKv sys-kernel/coreos-modules

# 2. Resolve KDIR + kernel release string ---------------------------------
kdir="$(readlink -f /usr/src/linux)"
kver="$(basename "${kdir}")"
kver="${kver#linux-}"    # e.g. "6.6.86-flatcar"

echo "==> Building bcachefs ${bcachefs_version} against kernel ${kver}"

# 3. Clone bcachefs-tools at the requested tag ----------------------------
#
# The kernel-side bcachefs source and its out-of-tree Kbuild harness live
# in koverstreet/bcachefs-tools now — everything since the 6.18 mainline
# removal ships through this repo (see dkms/ subdirectory).
cd /tmp
git clone --depth 1 --branch "${bcachefs_version}" --single-branch \
  https://github.com/koverstreet/bcachefs-tools.git bcachefs

# 4. Enforce the DKMS kernel-version floor --------------------------------
#
# dkms/dkms.conf.in advertises the minimum kernel version bcachefs will
# build against. Extract it and compare against the target Flatcar kernel
# so we fail early with a legible message instead of a compile error deep
# in fs/bcachefs/.
min_kver="$(sed -n 's/^BUILD_EXCLUSIVE_KERNEL_MIN="\([^"]*\)"/\1/p' \
  /tmp/bcachefs/dkms/dkms.conf.in 2>/dev/null || true)"
if [ -n "${min_kver}" ]; then
  target="${kver%%-*}"     # strip "-flatcar" suffix for comparison
  lowest="$(printf '%s\n' "${min_kver}" "${target}" | sort -V | head -n1)"
  if [ "${lowest}" != "${min_kver}" ]; then
    echo "ERROR: bcachefs ${bcachefs_version} requires kernel >= ${min_kver}," \
         "Flatcar ships ${kver}" >&2
    exit 1
  fi
fi

# 5. Build the module -----------------------------------------------------
#
# dkms/Makefile drives `$(MAKE) -C $(KDIR) M=$$PWD modules` and produces
# src/fs/bcachefs/bcachefs.ko. No overlay onto the kernel tree, no manual
# modules_prepare here — coreos-modules already did that.
make -j"$(nproc)" -C /tmp/bcachefs/dkms KDIR="${kdir}"

ko_src=/tmp/bcachefs/dkms/src/fs/bcachefs/bcachefs.ko
[ -f "${ko_src}" ] || {
  echo "ERROR: bcachefs.ko was not produced at ${ko_src}" >&2
  exit 1
}

# 6. Stage into the sysext root -------------------------------------------
#
# /usr/lib/modules/<kver>/updates/ is depmod's out-of-tree convention and
# is preferred by modprobe over any in-tree copy (though there is none on
# post-6.18 Flatcar kernels — bcachefs is gone from mainline).
modules_dst="/install_root/usr/lib/modules/${kver}/updates"
mkdir -p "${modules_dst}"
install -m 0644 "${ko_src}" "${modules_dst}/bcachefs.ko"

# Run depmod against the sysext root so `modprobe bcachefs` resolves on
# first merge without needing depmod to run on-target.
mkdir -p "/lib/modules/${kver}"
touch "/lib/modules/${kver}/modules.builtin" "/lib/modules/${kver}/modules.order"
depmod -a -b /install_root/usr "${kver}" || true

mkdir -p /install_root/usr/lib/modules-load.d
cat > /install_root/usr/lib/modules-load.d/bcachefs.conf <<EOF
bcachefs
EOF

chown -R "${export_user_group}" /install_root
chmod -R u+rwX,go+rX /install_root

echo "==> bcachefs-kmod build complete"
echo "    bcachefs: ${bcachefs_version}"
echo "    kernel:   ${kver}"
