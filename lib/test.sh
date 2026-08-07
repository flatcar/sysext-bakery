#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions for validating built sysext images.
#
# Two layers of tests are implemented:
#  1. Offline validation of the extension image itself. These checks run
#     against the image file, do not need a VM, and are cheap enough for CI.
#  2. Smoke tests of the extension on a running system. These are implemented
#     by the extension in "<extension>.sysext/test.sh" and run in a local
#     Flatcar VM (see lib/boot.sh) with the extension merged.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

# Top level directories an extension may ship. Anything else is dropped when
#  the extension is merged (systemd-sysext only overlays /usr and /opt).
_sysext_top_level_dirs=( usr opt )

# Directories an extension must never ship.
#  On Flatcar /usr/sbin is a symlink to /usr/bin. An extension shipping a real
#  usr/sbin directory replaces that symlink on merge, which hides all host
#  binaries in /usr/sbin.
_sysext_forbidden_dirs=( usr/sbin )

# ELF machine types (e_machine, see <elf.h>) of the architectures we build for.
declare -A _elf_machine_types=( [x86-64]=62 [arm64]=183 )

# Commands commonly provided by the OS image. Units referring to these are not
#  reported when the extension does not ship them itself.
_os_provided_commands=( bash cat cp env kill ln mkdir modprobe mount mv rm
                        sed sh sleep systemctl systemd-run touch umount )

# Where the in-VM test harness and the extension's test hook are installed.
_vm_test_dir="/var/lib/bakery-test"

# Printed by the in-VM test harness to report the test result to the host.
_vm_test_marker="__BAKERY_TEST_RESULT__"

#
#  ---------------- test result accounting ----------------
#

_test_failures=0
_test_warnings=0

# Maximum number of files reported individually per check. Anything beyond is
#  summarised, to keep the output of a broken image readable.
_test_max_reported=10

function _test_section() {
  echo
  echo "== ${*}"
}
# --

function _test_ok()   { echo "   ok   | ${*}"; }
function _test_skip() { echo "   skip | ${*}"; }
# --

function _test_warn() {
  echo "   warn | ${*}"
  _test_warnings=$((_test_warnings + 1))
}
# --

function _test_fail() {
  echo "   FAIL | ${*}"
  _test_failures=$((_test_failures + 1))
}
# --

#
#  ---------------- image inspection helpers ----------------
#

# Print <count> bytes read at <offset> of <file> as a plain hex string.
function _read_hex() {
  local file="$1"
  local offset="$2"
  local count="$3"

  od --address-radix=n --format=x1 --skip-bytes="${offset}" --read-bytes="${count}" -v "${file}" \
    | tr -d ' \n'
}
# --

# Print the file system format of an extension image, detected from the file
#  system's magic bytes. Prints nothing if the format is not recognised.
function _image_format() {
  local image="$1"

  # squashfs: "hsqs" at offset 0.
  if [[ $(_read_hex "${image}" 0 4) == 68737173 ]] ; then
    echo "squashfs"
  # erofs: 0xe0f5e1e2 (little endian) at offset 1024.
  elif [[ $(_read_hex "${image}" 1024 4) == e2e1f5e0 ]] ; then
    echo "erofs"
  # ext2/ext4: 0xef53 (little endian) at offset 1080.
  elif [[ $(_read_hex "${image}" 1080 2) == 53ef ]] ; then
    echo "ext"
  # btrfs: "_BHRfS_M" at offset 0x10040.
  elif [[ $(_read_hex "${image}" 65600 8) == 5f42485266535f4d ]] ; then
    echo "btrfs"
  fi
}
# --

# Extract an extension image to <destdir>.
# Extraction runs unprivileged, so file ownership of the extracted tree is
#  meaningless; use _image_list_non_root() to validate ownership.
function _image_extract() {
  local image="$1"
  local format="$2"
  local destdir="$3"

  local log="${destdir}.extract.log"
  local rc=0

  case "${format}" in
    squashfs) unsquashfs -no-xattrs -force -dest "${destdir}" "${image}" >"${log}" 2>&1 || rc=$? ;;
    erofs)    fsck.erofs "--extract=${destdir}" "${image}" >"${log}" 2>&1 || rc=$? ;;
    *)
      echo "ERROR: cannot extract '${format}' images."
      echo "       Offline validation supports squashfs and erofs images."
      return 1
      ;;
  esac

  if [[ ${rc} -ne 0 ]] ; then
    echo "ERROR: failed to extract '${image}':"
    cat "${log}"
    return 1
  fi
}
# --

# Print all image entries not owned by root:root, as "<uid>/<gid> <path>",
#  with <path> relative to the root of the image.
# Returns 1 if ownership cannot be read from the image's format.
function _image_list_non_root() {
  local image="$1"
  local format="$2"

  case "${format}" in
    squashfs)
      # "-lln" prints a numeric "ls -l" style listing, e.g.
      #   -rwxr-xr-x 0/0  26936 1970-01-01 00:00 squashfs-root/usr/bin/demo
      unsquashfs -lln "${image}" 2>/dev/null \
        | awk '$2 ~ /^[0-9]+\/[0-9]+$/ && $2 != "0/0" {
                 path = $6
                 for (i = 7; i <= NF; i++) { path = path " " $i }
                 # strip unsquashfs extraction directory ("squashfs-root")
                 sub(/^[^\/]+/, "", path)
                 print $2 " " (path == "" ? "/" : path)
               }'
      ;;
    *) return 1 ;;
  esac
}
# --

# Print the ELF machine type (e_machine) of <file> as a decimal number.
# Returns 1 if <file> is not an ELF binary.
function _elf_machine() {
  local file="$1"
  local -a header=()

  read -r -a header <<< "$(_read_hex "${file}" 0 20 | sed --regexp-extended 's/(..)/\1 /g')"
  if [[ ${#header[@]} -ne 20 ]] ; then
    return 1
  fi

  # e_ident starts with 0x7f "ELF"; EI_DATA (byte order) is at offset 5.
  if [[ "${header[0]}${header[1]}${header[2]}${header[3]}" != 7f454c46 ]] ; then
    return 1
  fi

  # e_machine is a 16 bit field at offset 18, stored in the ELF's byte order
  #  (EI_DATA: 1 - least significant byte first, 2 - most significant first).
  if [[ ${header[5]} == 01 ]] ; then
    echo $((16#${header[19]}${header[18]}))
  else
    echo $((16#${header[18]}${header[19]}))
  fi
}
# --

# Print the merged location of an absolute path on Flatcar.
# Flatcar is a usr-merged distribution: /bin, /sbin, /usr/sbin, /lib, and /lib64
#  are symlinks into /usr, so a unit may legitimately refer to a file the
#  extension ships below /usr by any of these paths.
function _merged_path() {
  local path="$1"

  case "${path}" in
    /bin/*)      echo "/usr/bin/${path#/bin/}" ;;
    /sbin/*)     echo "/usr/bin/${path#/sbin/}" ;;
    /usr/sbin/*) echo "/usr/bin/${path#/usr/sbin/}" ;;
    /lib/*)      echo "/usr/lib/${path#/lib/}" ;;
    /lib64/*)    echo "/usr/lib64/${path#/lib64/}" ;;
    *)           echo "${path}" ;;
  esac
}
# --

# Check whether an absolute path exists in the extension image extracted to
#  <root>. Symlinks are resolved with <root> as the file system root to mimic
#  what the path will look like on a host that merged the extension.
function _image_path_exists() {
  local root="$1"
  local path="$(_merged_path "$2")"

  local hops=0 target=""
  while true ; do
    # A path holding '..' components, or a symlink pointing out of the image,
    #  resolves to a file on the build host rather than to one the extension
    #  ships. Stop before the check consults the host's file system.
    if [[ "$(realpath -m -s --relative-base="${root}" "${root}${path}")" == /* ]] ; then
      return 1
    fi

    if [[ ! -L "${root}${path}" ]] ; then
      break
    fi

    # Give up on implausibly long symlink chains rather than spinning on a loop.
    if [[ ${hops} -ge 10 ]] ; then
      return 1
    fi
    hops=$((hops + 1))

    target="$(readlink "${root}${path}")"
    if [[ ${target} == /* ]] ; then
      path="$(_merged_path "${target}")"
    else
      path="$(dirname "${path}")/${target}"
    fi
  done

  [[ -e "${root}${path}" ]]
}
# --

# Print the path of the extension release file of the image extracted to <root>.
# Prints nothing if the image ships no (or more than one) release file.
function _extension_release_file() {
  local root="$1"
  local -a files=()

  readarray -t files < <(find "${root}/usr/lib/extension-release.d" \
                              -maxdepth 1 -type f -name 'extension-release.*' 2>/dev/null)

  if [[ ${#files[@]} -eq 1 ]] ; then
    echo "${files[0]}"
  fi
}
# --

# Print the value of <key> in an extension release file.
function _extension_release_field() {
  local key="$1"
  local file="$2"

  sed --silent --regexp-extended "s/^${key}=\"?([^\"]*)\"?$/\1/p" "${file}"
}
# --

#
#  ---------------- offline image checks ----------------
#

# The extension release metadata is what makes an image a system extension:
#  systemd refuses to merge an extension whose metadata is missing, is named
#  after a different extension, or does not match the host.
function _check_metadata() {
  local root="$1"
  local image="$2"
  local extname="$3"
  local arch="$4"

  local reldir="usr/lib/extension-release.d"
  local -a files=()
  readarray -t files < <(find "${root}/${reldir}" -maxdepth 1 -type f 2>/dev/null | sort)

  if [[ ${#files[@]} -eq 0 ]] ; then
    _test_fail "no extension release file in '${reldir}/'; the image will not be merged."
    return
  fi

  if [[ ${#files[@]} -gt 1 ]] ; then
    _test_fail "'${reldir}/' holds ${#files[@]} files; an extension must ship exactly one."
    return
  fi

  local relfile="${files[0]}"
  local relname="$(basename "${relfile}")"
  if [[ ${relname} != extension-release.?* ]] ; then
    _test_fail "'${reldir}/${relname}' is not named 'extension-release.<extension>'."
    return
  fi
  _test_ok "extension release metadata '${reldir}/${relname}'."

  # systemd matches the metadata file name against the name of the image it
  #  merges, i.e. the image file name without the ".raw" suffix. Release builds
  #  add a "-<version>-<arch>" suffix to the image file name; those images are
  #  deployed through the sysupdate configuration, which links them to
  #  "/etc/extensions/<extension>.raw" (see lib/sysupdate.conf.tmpl).
  local name="${relname#extension-release.}"
  local imagename="$(basename "${image}" .raw)"
  if [[ ${imagename} != "${name}" ]] && [[ ${imagename} != "${name}-"* ]] ; then
    _test_fail "image '${imagename}.raw' ships metadata for extension '${name}';" \
               "systemd will not merge it."
  elif [[ -n ${extname} ]] && [[ ${name} != "${extname}" ]] ; then
    _test_fail "the image ships metadata for extension '${name}', not for '${extname}'."
  fi

  local id="$(_extension_release_field "ID" "${relfile}")"
  local sysext_level="$(_extension_release_field "SYSEXT_LEVEL" "${relfile}")"
  case "${id}" in
    "")
      _test_fail "metadata has no 'ID='; systemd cannot tell which OS the extension is for." ;;
    _any)
      _test_ok "metadata matches any OS (ID=_any)." ;;
    *)
      if [[ -z ${sysext_level} ]] ; then
        _test_fail "metadata sets 'ID=${id}' but no 'SYSEXT_LEVEL='."
      else
        _test_ok "metadata matches OS '${id}' (SYSEXT_LEVEL=${sysext_level})."
      fi
      ;;
  esac

  local image_arch="$(_extension_release_field "ARCHITECTURE" "${relfile}")"
  if [[ -z ${image_arch} ]] ; then
    _test_fail "metadata has no 'ARCHITECTURE='; the extension merges on any architecture."
  elif [[ ${image_arch} != "${arch}" ]] ; then
    _test_fail "metadata declares architecture '${image_arch}', expected '${arch}'."
  else
    _test_ok "metadata declares architecture '${arch}'."
  fi
}
# --

# Extensions are overlaid onto /usr and /opt; files anywhere else are silently
#  dropped on merge, and shipping usr/sbin breaks Flatcar's usr-merge symlink.
function _check_layout() {
  local root="$1"
  local failures_before=${_test_failures}

  local entry=""
  while read -r entry; do
    if [[ " ${_sysext_top_level_dirs[*]} " == *" ${entry} "* ]] ; then
      continue
    fi
    _test_fail "'${entry}' is not below '${_sysext_top_level_dirs[*]/%//}';" \
               "it will not be present on the host after merge."
  done < <(find "${root}" -mindepth 1 -maxdepth 1 -printf '%P\n' | sort)

  local forbidden=""
  for forbidden in "${_sysext_forbidden_dirs[@]}"; do
    if [[ -e "${root}/${forbidden}" ]] ; then
      _test_fail "'${forbidden}' must not be shipped; it replaces the host's" \
                 "'/${forbidden}' symlink on merge and hides its contents."
    fi
  done

  if [[ ${_test_failures} -eq ${failures_before} ]] ; then
    _test_ok "all files are shipped below '${_sysext_top_level_dirs[*]/%//}'."
  fi
}
# --

# Extension images are merged into the host's /usr, which is owned by root.
# Files owned by the (unprivileged) build user leak the build environment into
#  the extension and may render shipped binaries writable to unrelated users.
function _check_ownership() {
  local image="$1"
  local format="$2"

  local listing=""
  if ! listing="$(_image_list_non_root "${image}" "${format}")" ; then
    _test_skip "file ownership cannot be read from '${format}' images."
    return
  fi

  if [[ -z ${listing} ]] ; then
    _test_ok "all files are owned by root."
    return
  fi

  local owner="" path="" reported=0 suppressed=0
  while read -r owner path; do
    if [[ ${reported} -ge ${_test_max_reported} ]] ; then
      suppressed=$((suppressed + 1))
      continue
    fi
    _test_fail "'${path}' is owned by ${owner} (uid/gid), expected 0/0."
    reported=$((reported + 1))
  done <<< "${listing}"

  if [[ ${suppressed} -gt 0 ]] ; then
    _test_fail "... and ${suppressed} more file(s) not owned by root."
  fi
}
# --

# A binary built for the wrong architecture is the classic copy-and-paste bug
#  in populate_sysext_root(); it only shows once the extension is deployed.
function _check_binaries() {
  local root="$1"
  local arch="$2"

  local expected="${_elf_machine_types[${arch}]}"
  local failures_before=${_test_failures}
  local file="" machine="" binaries=0 reported=0 suppressed=0

  while read -r file; do
    if ! machine="$(_elf_machine "${file}")" ; then
      continue
    fi
    binaries=$((binaries + 1))
    if [[ ${machine} -eq ${expected} ]] ; then
      continue
    fi
    if [[ ${reported} -ge ${_test_max_reported} ]] ; then
      suppressed=$((suppressed + 1))
      continue
    fi
    _test_fail "'${file#${root}}' is an ELF binary for machine type ${machine}," \
               "expected ${expected} (${arch})."
    reported=$((reported + 1))
  done < <(find "${root}" -type f)

  if [[ ${suppressed} -gt 0 ]] ; then
    _test_fail "... and ${suppressed} more binaries not built for ${arch}."
  fi

  if [[ ${binaries} -eq 0 ]] ; then
    _test_skip "the extension ships no ELF binaries."
  elif [[ ${_test_failures} -eq ${failures_before} ]] ; then
    _test_ok "all ${binaries} ELF binaries are built for ${arch}."
  fi
}
# --

# Print the command of a systemd "Exec*=" setting, i.e. without the special
#  execution modifier prefixes ("@", "-", ":", "+", "!", "!!") and arguments.
function _unit_exec_command() {
  local setting="$1"

  setting="${setting#"${setting%%[![:space:]]*}"}"
  setting="${setting#"${setting%%[!@:+!-]*}"}"

  echo "${setting%%[[:space:]]*}"
}
# --

# Every unit shipped by an extension must be able to start on a merged system.
# Wrong binary paths in units are a recurring source of 203/EXEC failures that
#  only surface at runtime, long after the extension was released.
function _check_units() {
  local root="$1"

  local unitdir="${root}/usr/lib/systemd"
  if [[ ! -d ${unitdir} ]] ; then
    _test_skip "the extension ships no systemd units."
    return
  fi

  local failures_before=${_test_failures} warnings_before=${_test_warnings}
  local unit="" setting="" exec_path="" exec_name="" shipped="" units=0

  while read -r unit; do
    units=$((units + 1))
    while read -r setting; do
      exec_path="$(_unit_exec_command "${setting}")"

      # Commands without a path are looked up in systemd's built-in $PATH at
      #  runtime; there is nothing we can validate offline.
      if [[ ${exec_path} != /* ]] ; then
        continue
      fi

      if _image_path_exists "${root}" "${exec_path}" ; then
        continue
      fi

      # The command is not shipped by the extension. If the extension ships a
      #  binary of that name elsewhere the unit points at the wrong path,
      #  otherwise the command is expected to come with the OS image.
      exec_name="$(basename "${exec_path}")"
      shipped="$(find "${root}" -type f -name "${exec_name}" -printf '%P\n' -quit)"
      if [[ -n ${shipped} ]] ; then
        _test_fail "unit '${unit#${root}}' runs '${exec_path}'," \
                   "but the extension ships it as '/${shipped}'."
      elif [[ " ${_os_provided_commands[*]} " != *" ${exec_name} "* ]] ; then
        _test_warn "unit '${unit#${root}}' runs '${exec_path}' which the extension" \
                   "does not ship; make sure the OS image provides it."
      fi
    done < <(sed --silent --regexp-extended \
                 's/^[[:space:]]*Exec(Start|StartPre|StartPost|Stop|StopPost|Reload|Condition)=(.+)$/\2/p' \
                 "${unit}")
  done < <(find "${unitdir}" -type f \
                \( -name '*.service' -o -name '*.socket' -o -name '*.mount' \
                   -o -name '*.path' -o -name '*.timer' -o -name '*.conf' \) | sort)

  if [[ ${units} -eq 0 ]] ; then
    _test_skip "the extension ships no systemd units."
  elif [[ ${_test_failures} -eq ${failures_before} ]] \
    && [[ ${_test_warnings} -eq ${warnings_before} ]] ; then
    _test_ok "all commands of the ${units} systemd unit file(s) shipped are available."
  fi
}
# --

#
#  ---------------- extension smoke tests in a VM ----------------
#

# Generate the test harness that runs the extension's test hook in the VM.
function _generate_vm_runner() {
  local extname="$1"

  # Parameters from the host; the harness itself follows verbatim below.
  cat <<EOF
#!/usr/bin/env bash
#
# Generated by the sysext bakery. Runs an extension's test hook in a test VM.

extension="${extname}"
testdir="${_vm_test_dir}"
marker="${_vm_test_marker}"
EOF

  cat <<'EOF'
# Do not abort on failing tests; we want to run and report all of them.
set -uo pipefail

# The host reads the test results from the VM's serial console. Systemd's
#  "StandardOutput=+console" writes to /dev/console, which is whatever the last
#  "console=" on the kernel command line names - tty0 for Flatcar's qemu
#  images, which a headless VM never shows. Write to the serial console the
#  host does read, whatever it is called on this architecture.
for tty in $(</sys/class/tty/console/active); do
  case "${tty}" in
    ttyS*|ttyAMA*|hvc*)
      exec >"/dev/${tty}" 2>&1
      break
      ;;
  esac
done

declare -i failures=0

# check <description> <command> [<argument> ...]
# Run <command> and report the result. Available to run_tests().
function check() {
  local description="$1"
  shift

  local output=""
  if output="$("${@}" 2>&1)" ; then
    echo "   ok   | ${description}"
    return 0
  fi

  echo "   FAIL | ${description}"
  echo "        | command: ${*}"
  if [[ -n ${output} ]] ; then
    echo "${output}" | sed 's/^/        | /'
  fi

  failures+=1
  return 1
}
# --

echo "Running smoke tests of extension '${extension}'"

# The extension release file only shows up in /usr once the image is merged,
#  so this also validates that systemd-sysext accepted the image.
check "extension '${extension}' is merged into the running system" \
      test -e "/usr/lib/extension-release.d/extension-release.${extension}"

if [[ -s "${testdir}/test.sh" ]] ; then
  source "${testdir}/test.sh"
fi

if [[ $(type -t run_tests) == function ]] ; then
  declare -i reported="${failures}"
  run_tests
  rc=$?
  # Hooks either use check() or just return a non-zero exit code. Only count
  #  the exit code if the hook did not report failures of its own; a hook using
  #  check() returns the status of its last check.
  if [[ ${rc} -ne 0 ]] && [[ ${failures} -eq ${reported} ]] ; then
    echo "   FAIL | run_tests() returned ${rc}"
    failures+=1
  fi
else
  echo "   skip | extension '${extension}' implements no run_tests() hook"
fi

echo "${marker} failures=${failures}"
EOF
}
# --

# Generate the provisioning config of the test VM.
# All files are served by the local webserver started by _run_vm_tests().
function _generate_vm_butane() {
  local extname="$1"

  cat <<EOF
version: 1.0.0
variant: flatcar

storage:
  files:
    # The image file name must match the extension release file it ships,
    #  otherwise systemd-sysext refuses to merge the extension.
    - path: /etc/extensions/${extname}.raw
      mode: 0644
      contents:
        # QEmu's default traffic-to-host IP
        source: http://10.0.2.2:12345/${extname}.raw
    - path: ${_vm_test_dir}/test.sh
      mode: 0644
      contents:
        source: http://10.0.2.2:12345/test.sh
    - path: ${_vm_test_dir}/run-tests.sh
      mode: 0755
      contents:
        source: http://10.0.2.2:12345/run-tests.sh

systemd:
  units:
    - name: update-engine.service
      mask: true
    - name: locksmithd.service
      mask: true
    - name: bakery-test.service
      enabled: true
      contents: |
        [Unit]
        Description=Sysext bakery extension smoke tests
        # Run on a fully booted system, with the extension merged. A failed
        #  merge is reported by the tests rather than skipping the run.
        After=systemd-sysext.service multi-user.target

        [Service]
        Type=oneshot
        ExecStart=${_vm_test_dir}/run-tests.sh
        # The host reads the test result from the VM's console.
        StandardOutput=journal+console
        StandardError=journal+console
        # Shut the VM down in any case, including a failing test run.
        ExecStopPost=/usr/bin/systemctl poweroff

        [Install]
        WantedBy=multi-user.target
EOF
}
# --

# Boot a Flatcar VM with the extension merged and run its test hook.
function _run_vm_tests() {
  local image="$1"
  local extname="$2"
  local arch="$3"
  local timeout="$4"

  local hook="${scriptroot}/${extname}.sysext/test.sh"
  # Absolute, as the VM runs in a temporary working directory below.
  local console_log="$(pwd)/${extname}-vm-test.log"

  if [[ ! -s ${hook} ]] ; then
    _test_warn "extension '${extname}' implements no test hook in" \
               "'${extname}.sysext/test.sh'; only checking that it merges."
    hook="/dev/null"
  fi

  # Run in a sub-shell b/c we will change into a temporary working directory
  (
    set -euo pipefail
    local workdir="$(mktemp -d)"
    # clean up: webserver (once started, below) and work dir
    trap "kill %1 >/dev/null 2>&1; rm -rf '${workdir}'" EXIT

    _generate_vm_runner "${extname}" >"${workdir}/run-tests.sh"
    _generate_vm_butane "${extname}" >"${workdir}/test.yaml"
    cp "${hook}" "${workdir}/test.sh"
    cp "${image}" "${workdir}/${extname}.raw"
    transpile "${workdir}/test.yaml" "${workdir}/test.json"

    # The OS image is downloaded to (and re-used from) the current directory.
    _download_os_image "$(arch_transform 'x86-64' 'amd64' "${arch}")"
    cp "${_flatcar_image_files[@]}" "${workdir}/"

    webserver "${workdir}" &

    # '-nographic' makes qemu multiplex its monitor onto the console, and qemu
    #  shuts the VM down as soon as that console reaches EOF. Feed the console
    #  from a fifo opened for reading *and* writing: it never signals EOF, and
    #  nothing is ever written to it.
    mkfifo "${workdir}/console-input"

    cd "${workdir}"
    echo "Booting test VM (test run timeout: ${timeout}s)"
    # The VM powers itself off when the tests are done. Keep going on timeouts
    #  and boot failures; the console log tells us what happened.
    timeout --foreground --kill-after 30 "${timeout}" \
        ./flatcar_production_qemu_uefi.sh -i "test.json" "-snapshot" "-nographic" \
      <>"console-input" 2>&1 | tee "${console_log}" || true

    local failures="$(sed --silent --regexp-extended \
                          "s/.*${_vm_test_marker} failures=([0-9]+).*/\1/p" \
                          "${console_log}" | tail -n 1)"

    echo
    if [[ -z ${failures} ]] ; then
      echo "ERROR: the test VM did not report a result. The extension may have failed"
      echo "       to merge, or the tests did not finish within ${timeout} seconds."
      echo "       Console output: '${console_log}'"
      exit 1
    fi

    if [[ ${failures} -ne 0 ]] ; then
      echo "ERROR: ${failures} smoke test(s) failed."
      echo "       Console output: '${console_log}'"
      exit 1
    fi

    rm -f "${console_log}"
  )
}
# --

#
#  ---------------- high level functions ----------------
#

function _test_help() {
  echo "Validate a built extension image."
  echo
  echo "The image is checked for the metadata, layout, and file ownership systemd-sysext"
  echo " expects, for binaries built for the wrong architecture, and for systemd units"
  echo " referring to files the extension does not ship."
  echo "With '--vm true' the extension's test hook ('<extension>.sysext/test.sh') is run"
  echo " in a local Flatcar VM with the extension merged."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <extension|image>:   Name of a built extension, e.g. 'docker', or the path of an"
  echo "                         extension image, e.g. 'docker-28.5.2-arm64.raw'."
  echo "                         Build the image first: '$0 create <extension> <version>'."
  echo
  echo " Optional arguments:"
  echo " --arch <arch>:        Architecture the image is expected to be built for."
  echo "                         Either x86-64 or arm64. Defaults to the image's metadata."
  echo " --vm <true|false>:    Also run the extension's test hook in a local Flatcar VM."
  echo "                         Defaults to 'false'. Requires qemu and docker."
  echo " --timeout <seconds>:  Time budget for the VM test run. Defaults to 600."
}
# --

function test_sysext() {
  local target="$(get_positional_param "1" "${@}")"

  if [[ -z ${target} ]] || [[ ${target} == help ]] ; then
    _test_help
    return
  fi

  # The target is either an image file or the name of a built extension.
  local image="${target}" extname=""
  if [[ ! -f ${image} ]] ; then
    extname="$(extension_name "${target}")"
    if [[ -z ${extname} ]] ; then
      echo "ERROR: '${target}' is neither an extension image nor a known extension."
      echo "       Use '$0 list' to list all extensions."
      return 1
    fi

    image="${extname}.raw"
    if [[ ! -f ${image} ]] ; then
      echo "ERROR: extension image '${image}' not found. Build it first, using"
      echo "         $0 create ${extname} <version>"
      return 1
    fi
  fi

  local format="$(_image_format "${image}")"
  if [[ -z ${format} ]] ; then
    echo "ERROR: '${image}' is not a file system image."
    return 1
  fi

  local workdir="$(mktemp -d)"
  trap "rm -rf '${workdir}'" EXIT

  announce "Validating '${image}' (${format})"

  local root="${workdir}/root"
  if ! _image_extract "${image}" "${format}" "${root}" ; then
    return 1
  fi

  # The extension release file is the only place that tells us the name and the
  #  architecture of an extension image, independent of the image's file name.
  local relfile="$(_extension_release_file "${root}")"
  local arch="$(get_optional_param "arch" "" "${@}")"
  if [[ -n ${arch} ]] ; then
    check_arch "${arch}"
  else
    # Default to the architecture the image declares. Images with missing or
    #  bogus metadata are reported by the metadata check below; fall back to
    #  the default architecture to still run all remaining checks on them.
    arch="$(_extension_release_field "ARCHITECTURE" "${relfile:-/dev/null}")"
    if [[ -z ${arch} ]] || [[ -z ${_elf_machine_types[${arch}]:-} ]] ; then
      arch="x86-64"
    fi
  fi

  _test_section "Extension metadata"
  _check_metadata "${root}" "${image}" "${extname}" "${arch}"
  _test_section "Image layout"
  _check_layout "${root}"
  _test_section "File ownership"
  _check_ownership "${image}" "${format}"
  _test_section "Binary architecture"
  _check_binaries "${root}" "${arch}"
  _test_section "Systemd units"
  _check_units "${root}"

  echo
  if [[ ${_test_failures} -gt 0 ]] ; then
    announce "FAILED: ${_test_failures} check(s) failed, ${_test_warnings} warning(s)"
    return 1
  fi
  announce "PASSED: image validation, ${_test_warnings} warning(s)"

  if [[ $(get_optional_param "vm" "false" "${@}") != true ]] ; then
    return 0
  fi

  # The smoke tests need the extension name to locate the extension's test hook.
  if [[ -z ${extname} ]] ; then
    extname="$(basename "${relfile}")"
    extname="${extname#extension-release.}"
  fi

  local timeout="$(get_optional_param "timeout" "600" "${@}")"
  announce "Running smoke tests of '${extname}' in a Flatcar VM"
  if ! _run_vm_tests "${image}" "${extname}" "${arch}" "${timeout}" ; then
    announce "FAILED: smoke tests of '${extname}'"
    return 1
  fi

  announce "PASSED: smoke tests of '${extname}'"
}
# --
