#!/usr/bin/env bash
set -euo pipefail

export ARCH="${ARCH-amd64}"
EXTRALIBS="${EXTRALIBS-}"
KEEP="${KEEP-}"
SCRIPTFOLDER="$(dirname "$(readlink -f "$0")")"

if [ $# -lt 3 ] || [ "$1" = "-h" ] || [ "$1" = "--help" ]; then
  echo "Usage: $0 FOLDER SYSEXTNAME PATHS..."
  echo "The script will extract the specified binary paths (e.g., /usr/bin/nano) or resource paths (e.g., /usr/share/nano/) from FOLDER, resolve the dynamic libraries, and create a systemd-sysext squashfs image with the name SYSEXTNAME.raw in the current folder."
  echo "Paths under /usr are recommended but paths under /etc or /bin can also be specified as 'CHROOT:TARGET', e.g., '/etc/systemd/system/my.service:/usr/systemd/system/my.service' or '/bin/mybin:/usr/bin/mybin' supported (but not if they are symlinks under /bin/)."
  echo "Since dynamic libraries should not conflict, you must not pass libraries in PATHS."
  echo "If a particular library is needed for dlopen, pass EXTRALIBS as space-separated environment variable (current value is '${EXTRALIBS}')."
  echo "Note: The resolving of libraries copies them in one shared folder and might not cover all use cases."
  echo "E.g., specifying a folder with binaries does not work, each one has to be specified separately."
  echo "For testing, pass KEEP=1 as environment variable (current value is '${KEEP}') and run the binaries with bwrap --bind /proc /proc --bind SYSEXTNAME/usr /usr /usr/bin/BINARY."
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

if ! command -v patchelf >/dev/null; then
  echo "Error: patchelf missing" >&2
  exit 1
fi

# Map library name to found library location
declare -A FOUND_DEPS=()
find_deps() {
  local FROM="$1"
  local TO="$2"
  local FILE="$3" # Should be the copied file
  local DEP=
  local FOUND=
  local LIB_PATHS=
  local NEW_RPATHS=
  local RP=
  LIB_PATHS=("${FROM}/lib64" "${FROM}/usr/lib64" "${FROM}/usr/local/lib64" "${FROM}/lib" "${FROM}/usr/lib" "${FROM}/usr/local/lib")
  for RP in $({ cat "${FROM}"/etc/ld.so.conf.d/* "${FROM}"/etc/ld.so.conf 2> /dev/null || true ; } | { grep -Pv '^(#|include )' || true ; }); do
    LIB_PATHS+=("${RP}")
  done
  for DEP in $(patchelf --print-needed "${FILE}"); do
    if [ "${FOUND_DEPS["${DEP}"]-}" != "" ]; then
      continue
    fi
    FOUND=$({ find "${LIB_PATHS[@]}" -name "${DEP}" 2>/dev/null || true ;} | head -n 1)
    if [ "${FOUND}" = "" ]; then
      echo "Error: Library ${DEP} not found in ${LIB_PATHS[*]}" >&2; exit 1
    fi
    FOUND=$(echo -n "${FOLDER}/"; realpath -m --relative-base="${FOLDER}" "${FOUND}")
    cp -a "${FOUND}" "${TO}/usr/local/${SYSEXTNAME}/${DEP}"
    FOUND_DEPS["${DEP}"]="${FOUND}"
    find_deps "${FROM}" "${TO}" "${TO}/usr/local/${SYSEXTNAME}/${DEP}"
  done
  NEW_RPATHS="/usr/local/${SYSEXTNAME}:/usr/local/${SYSEXTNAME}/extralibs"
  for RP in $(patchelf --print-rpath "${FILE}" | tr ':' ' '); do
    if [[ "${RP}" == *"\$ORIGIN"* ]]; then
      echo "Warning: Ignored rpath ${RP}"
      continue
    fi
    if [ ! -e "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${RP}" ]; then
      mkdir -p "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${RP}"
      cp -ar "${FROM}/${RP}/." "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${RP}"
    fi
    NEW_RPATHS+=":/usr/local/${SYSEXTNAME}/${RP}"
  done
  patchelf --no-default-lib --set-rpath "${NEW_RPATHS}" "${FILE}"
}

rm -rf "${SYSEXTNAME}"
mkdir -p "${SYSEXTNAME}/usr/local/${SYSEXTNAME}"

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
  if [ ! -L "${FOLDER}/${ENTRY}" ] && [ -d "${FOLDER}/${ENTRY}" ]; then
    cp -ar "${FOLDER}/${ENTRY}/." "${SYSEXTNAME}/${NEWENTRY}"
  else
    cp -a "${FOLDER}/${ENTRY}" "${SYSEXTNAME}/${NEWENTRY}"
    if [ -L "${FOLDER}/${ENTRY}" ]; then
      TARGET=$(realpath -m --relative-base="${FOLDER}" "${FOLDER}/${ENTRY}")
      DIR=$(dirname "${TARGET}")
      mkdir -p "${SYSEXTNAME}/${DIR}"
      if [ -d "${FOLDER}/${TARGET}" ]; then
        cp -ar "${FOLDER}/${TARGET}/." "${SYSEXTNAME}/${TARGET}"
      else
        cp -a "${FOLDER}/${TARGET}" "${SYSEXTNAME}/${TARGET}"
        # Check if we need to patch the target file
        ENTRY="${TARGET}"
      fi
    fi
  fi
  INTERP=
  if [ ! -L "${SYSEXTNAME}/${NEWENTRY}" ] && [ -f "${SYSEXTNAME}/${NEWENTRY}" ]; then
    INTERP=$(patchelf --print-interpreter "${SYSEXTNAME}/${NEWENTRY}" 2>/dev/null || true)
  fi
  if [ "${INTERP}" != "" ]; then
    INTERP_NAME=$(basename "${INTERP}")
    if [ ! -f "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${INTERP}" ]; then
      INTERP=$(realpath -m --relative-base="${FOLDER}" "${FOLDER}/${INTERP}")
      cp -a "${FOLDER}/${INTERP}" "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/${INTERP_NAME}"
    fi
    patchelf --set-interpreter "/usr/local/${SYSEXTNAME}/${INTERP_NAME}" "${SYSEXTNAME}/${NEWENTRY}"
    find_deps "${FOLDER}" "${SYSEXTNAME}" "${SYSEXTNAME}/${NEWENTRY}"
  fi
done
for ENTRY in ${EXTRALIBS}; do
  DIR=$(dirname "${ENTRY}")
  NAME=$(basename "${ENTRY}")
  mkdir -p "${SYSEXTNAME}/${DIR}"
  cp -a "${FOLDER}/${ENTRY}" "${SYSEXTNAME}/usr/local/${SYSEXTNAME}/extralibs/${NAME}"
  if [ ! -L "${FOLDER}/${ENTRY}" ] && [ -f "${FOLDER}/${ENTRY}" ]; then
    find_deps "${FOLDER}" "${SYSEXTNAME}" "${FOLDER}/${ENTRY}"
  fi
done

RELOAD=1 "${SCRIPTFOLDER}"/bake.sh "${SYSEXTNAME}"
if [ "${KEEP}" != 1 ]; then
  rm -rf "${SYSEXTNAME}"
fi
