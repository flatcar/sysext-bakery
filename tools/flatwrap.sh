#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-amd64}"
KEEP="${KEEP-}"
ETCMAP="${ETCMAP-host}"
VARMAP="${VARMAP-host}"
HOMEMAP="${HOMEMAP-host}"
CHROOT="${CHROOT-/usr /lib /lib64 /bin /sbin}"
HOST="${HOST-/dev /proc /sys /run /tmp /var/tmp}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 FOLDER SYSEXTNAME PATHS..."
  echo "The script will set up entry points for the specified binary or systemd unit paths (e.g., /usr/bin/nano, /usr/systemd/system/my.service) from FOLDER into a chroot under /usr/local/, and create a systemd-sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "Paths under /usr are recommended but paths under /etc or /bin can also be specified as 'CHROOT:TARGET', e.g., '/etc/systemd/system/my.service:/usr/systemd/system/my.service' or '/bin/mybin:/usr/bin/mybin' supported."
  echo "Since only the specified paths are available in the host, any files accessed by systemd for service units must also be specified."
  echo "The binary itself will be able to access all files of the chroot as specifed in the CHROOT environment variable (current value is '${CHROOT}')."
  echo "It will also be able to access all files of the host as specified in the HOST environment variable and to /etc, /var, /home if not disabled below (current value is '${HOST}')."
  echo "The mapping of /etc, /var, /home from host or the chroot can be controlled with the ETCMAP/VARMAP/HOMEMAP environment variables by setting them to 'chroot' (current values are '${ETCMAP}', '${VARMAP}', '${HOMEMAP}')."
  echo "The binaries will be spawned with bwrap if available for non-root users. When bwrap is missing, an almost equivalent combination of unshare commands is used."
  echo "For testing, pass KEEP=1 as environment variable (current value is '${KEEP}') and run the binaries with [sudo] FLATWRAP_ROOT=SYSEXTNAME SYSEXTNAME/usr/bin/binary."
  echo
  echo "A temporary directory named SYSEXTNAME in the current folder will be created and deleted again."
  echo "All files in the sysext image will be owned by root."
  echo "To use a different architecture than amd64 pass 'ARCH=arm64' as environment variable (current value is '${ARCH}')."
  "${SCRIPTFOLDER}"/bake.sh --help
  exit 1
fi

FOLDER="$1"
SYSEXTNAME="$2"
shift
shift
PATHS=("$@")

if [ "${ETCMAP}" = host ]; then
  HOST+=" /etc"
else
  CHROOT+=" /etc"
fi
if [ "${VARMAP}" = host ]; then
  HOST+=" /var"
else
  CHROOT+=" /var"
fi
if [ "${HOMEMAP}" = host ]; then
  HOST+=" /home"
else
  CHROOT+=" /home"
fi
# Make sure to mount /var before /var/tmp
HOST=$(echo "${HOST}" | tr ' ' '\n' | sort)
CHROOT=$(echo "${CHROOT}" | tr ' ' '\n' | sort)

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}/usr/local/${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/mount-dir"

cp -ar "${FOLDER}/." "${SYSEXTNAME}/usr/local/${SYSEXTNAME}"

CARGS=() # CHROOT unshare bind mounts
BWCARGS=() # CHROOT bwrap bind mounts
for DIR in ${CHROOT}; do
  CHROOTDIR="${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${DIR}"
  if [ ! -L "${CHROOTDIR}" ] && [ ! -e "${CHROOTDIR}" ]; then
    continue
  fi
  CHROOTDIR=$(realpath -m --relative-base="${SYSEXTNAME}/usr/local/${SYSEXTNAME}" "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${DIR}")
  CHROOTDIR="${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${CHROOTDIR}"
  CARGS+=(mkdir -p "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir/${DIR}" "&&" mount --rbind "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/${DIR}" "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir/${DIR}" "&&")
  BWCARGS+=(--bind "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/${DIR}" "${DIR}")
done
HARGS=() # HOST unshare bind mounts
BWHARGS=() # HOST bwrap bind mounts
for DIR in ${HOST}; do
  HARGS+=(mkdir -p "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir/${DIR}" "&&" mount --rbind "${DIR}" "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir/${DIR}" "&&")
  BWHARGS+=(--bind "${DIR}" "${DIR}")
done
# The above could be moved into the helper below to allow controlling the mapping at runtime
# and the helpers could be put into one file, controlled by a different first argument.

# Helper for priv chroot setup
tee "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/unshare-helper" > /dev/null <<EOF
#!/bin/sh
# Instead of chroot we run unshare --root --wd to keep PWD (but no new namespaces are created)
mount -t tmpfs tmpfs "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir" && ${CARGS[@]} ${HARGS[@]} exec unshare --root "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir" --wd "\${PWD}" "\$@"
EOF
chmod +x "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/unshare-helper"

# Helper for unpriv chroot setup (when bwrap is not available)
tee "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/unshare-helper-unpriv" > /dev/null <<EOF
#!/bin/sh
U="\$1"
G="\$2"
shift
shift
mount -t tmpfs tmpfs "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir" && ${CARGS[@]} ${HARGS[@]} exec unshare --map-user="\$U" --map-user="\$G" -U --root "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/mount-dir" --wd "\${PWD}" "\$@"
EOF
chmod +x "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/unshare-helper-unpriv"

for ENTRY in "${PATHS[@]}"; do
  NEWENTRY="${ENTRY}"
  if [[ "${ENTRY}" != /usr/* ]]; then
    NEWENTRY=$(echo "${ENTRY}" | cut -d : -f 2)
    ENTRY=$(echo "${ENTRY}" | cut -d : -f 1)
    if [ "${ENTRY}" = "${NEWENTRY}" ] || [ "${NEWENTRY}" = "" ] || [[ "${NEWENTRY}" != /usr/* ]]; then
      echo "Error: '${ENTRY}' should be passed with ':/usr/TARGET'" >&2; exit 1
    fi
  fi
  DIR=$(dirname "${NEWENTRY}")
  mkdir -p "${SYSEXTNAME}/${DIR}"
  if [ -L "${FOLDER}/${ENTRY}" ]; then
    TARGET=$(realpath -m --relative-base="${FOLDER}" "${FOLDER}/${ENTRY}")
    ln -fs "/usr/local/${SYSEXTNAME}/${TARGET}" "${SYSEXTNAME}/${NEWENTRY}"
  elif [ -d "${FOLDER}/${ENTRY}" ] || [ ! -x "${FOLDER}/${ENTRY}" ]; then
    NAME=$(basename "${NEWENTRY}")
    ln -fs --no-target-directory "/usr/local/${SYSEXTNAME}/${ENTRY}" "${SYSEXTNAME}/${DIR}/${NAME}"
  else
      tee "${SYSEXTNAME}/${NEWENTRY}" > /dev/null <<EOF
#!/bin/sh
if [ "\$(id -u)" = 0 ]; then
  exec unshare -m "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/unshare-helper" "${ENTRY}" "\$@"
elif command -v bwrap >/dev/null && [ "\${NOBWRAP-}" = "" ]; then
  exec bwrap ${BWCARGS[@]} ${BWHARGS[@]} "${ENTRY}" "\$@"
else
  exec unshare -m -U -r "\${FLATWRAP_ROOT-}/usr/local/${SYSEXTNAME}/unshare-helper-unpriv" "\$(id -u)" "\$(id -g)" "${ENTRY}" "\$@"
fi
EOF
    chmod +x "${SYSEXTNAME}/${NEWENTRY}"
  fi
done

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
if [ "${KEEP}" != 1 ]; then
  rm -rf "${SYSEXTNAME}"
fi
