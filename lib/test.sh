#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions to test provisioned sysext images.
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail

_test_helper="$(cd "$(dirname "${BASH_SOURCE[0]}")"; pwd)/test_harness.py"

function _test_help() {
  cat <<HELP
Boot Flatcar and verify delivery and merge of every requested extension.
Usage: $0 test <recipe|image.raw> [<recipe|image.raw> ...] [options]
Images must already be built. A positional version is not supported.

  --arch <amd64|arm64>   VM architecture (default: amd64; x86-64 accepted).
  --port <port>          Loopback SSH port (default: dynamically allocated).
  --timeout <seconds>    SSH readiness deadline (default: 90).
  --test-timeout <secs>  Deadline for each recipe hook (default: 90).
  --keep-vm <true|false> Preserve diagnostics on failure, never keys (default: false).
  --checksums <file>     Use this SHA256SUMS file for every requested image.
  --require-checksums <true|false> Require recorded checksums (default: false).

Meaningful recipe test.sh hooks run after all images merge. Missing or empty
hooks are SKIPPED: merge-only coverage does not establish application health.
HELP
}

function _find_free_port() {
  python3 "${_test_helper}" port
}

function _test_ssh() {
  local key="$1" port="$2" command="$3" timeout="${4:-10}"
  _test_run "${timeout}" \
    ssh -F /dev/null -i "${key}" -p "${port}" \
      -o IdentitiesOnly=yes -o IdentityAgent=none \
      -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=2 -o BatchMode=yes -o LogLevel=ERROR \
      -o ServerAliveInterval=2 -o ServerAliveCountMax=2 \
      core@127.0.0.1 "${command}"
}

function _test_run() {
  local timeout="$1"
  shift
  _test_wait python3 "${_test_helper}" run "${timeout}" - "$@"
}

function _test_wait() {
  local rc=0
  "$@" <&0 &
  _harness_check_pid=$!
  wait "${_harness_check_pid}" || rc=$?
  _harness_check_pid=""
  return "${rc}"
}

function _test_has_commands() {
  [[ -f "$1" ]] && LC_ALL=C grep -Eq '^[[:space:]]*[^#[:space:]]' "$1"
}

function _test_recipe() {
  local name="$1" dir recipe suffix
  if [[ -d "${scriptroot}/${name}.sysext" && "${name}" != _skel ]]; then
    printf '%s\n' "${name}"
    return
  fi
  local match=""
  for dir in "${scriptroot}/"*.sysext; do
    [[ -d "${dir}" ]] || continue
    recipe="$(basename "${dir}" .sysext)"
    [[ "${recipe}" != _skel && "${name}" == "${recipe}-"* ]] || continue
    suffix="${name#"${recipe}-"}"
    if [[ "${suffix}" =~ ^v?[0-9][A-Za-z0-9.+_-]*-(x86-64|amd64|arm64)$ && ${#recipe} -gt ${#match} ]]; then
      match="${recipe}"
    fi
  done
  printf '%s\n' "${match}"
}

function _cleanup_harness() {
  local rc="${1:-1}" pid cleanup_failed=false
  trap '' INT TERM HUP
  trap - EXIT
  set +e
  local children=()
  # Include a child interrupted between spawning it and recording $!.
  while IFS= read -r pid; do children+=("${pid}"); done < <(jobs -pr)
  for pid in "${children[@]}"; do
    kill -TERM "${pid}" 2>/dev/null
    wait "${pid}" 2>/dev/null
    if kill -0 "${pid}" 2>/dev/null; then cleanup_failed=true; fi
  done
  if [[ -n "${_harness_butane_name:-}" ]]; then
    local containers
    containers="$(python3 "${_test_helper}" run 10 - docker ps -aq --filter "name=^/${_harness_butane_name}$")"
    if [[ $? != 0 ]]; then cleanup_failed=true;
    elif [[ -n "${containers}" ]]; then
      python3 "${_test_helper}" run 10 - docker rm -f "${_harness_butane_name}" >/dev/null || cleanup_failed=true
    fi
  fi
  if [[ -n "${_harness_workdir:-}" && -d "${_harness_workdir}" ]]; then
    rm -rf -- "${_harness_workdir}/identity" || cleanup_failed=true
    if [[ "${cleanup_failed}" == true && "${rc}" == 0 ]]; then rc=1; fi
    if [[ "${_harness_keep_vm:-false}" == true && "${rc}" != 0 ]]; then
      rm -rf -- "${_harness_workdir}/artifacts" "${_harness_workdir}/vm" || cleanup_failed=true
      echo "Preserved diagnostics: ${_harness_workdir}"
    else
      rm -rf -- "${_harness_workdir}" || cleanup_failed=true
    fi
  fi
  if [[ "${cleanup_failed}" == true ]]; then
    echo "ERROR: Cleanup did not complete."
    if [[ "${rc}" == 0 ]]; then rc=1; fi
  fi
  if [[ "${rc}" == 0 && "${_harness_complete:-false}" == true ]]; then
    echo "Test run finished: PASS (${_harness_coverage})"
  else
    if [[ "${rc}" == 0 ]]; then rc=1; fi
    echo "Test run finished: FAIL (exit code ${rc})"
  fi
  exit "${rc}"
}

function _run_sysext_checks() {
  local key="$1" port="$2" image="$3" expected="$4"
  local filename name actual status
  filename="$(basename "${image}")"
  name="${filename%.raw}"
  echo "Verifying '${name}'..."
  local output="${_harness_workdir}/ssh.out"
  _test_ssh "${key}" "${port}" "sha256sum -- $(printf '%q' "/etc/extensions/${filename}")" >"${output}" || return 1
  actual="$(cat "${output}")"
  if [[ "${actual%% *}" != "${expected}" ]]; then
    echo "ERROR: Provisioned image checksum mismatch: ${filename}"
    return 1
  fi
  if ! _test_ssh "${key}" "${port}" 'systemctl is-active systemd-sysext.service'; then
    echo "ERROR: systemd-sysext.service is not active."
    return 1
  fi
  _test_ssh "${key}" "${port}" 'systemd-sysext status --json=short' >"${output}" || return 1
  status="$(cat "${output}")"
  if ! python3 "${_test_helper}" merged "${name}" <<<"${status}"; then
    echo "ERROR: Requested extension '${name}' is not confirmed merged."
    return 1
  fi
  echo "  -> Delivery checksum and merge passed"
}

function _run_sysext_hook() {
  local key="$1" port="$2" image="$3" timeout="$4"
  local name recipe hook
  name="$(basename "${image}" .raw)"
  recipe="$(_test_recipe "${name}")"
  hook="${scriptroot}/${recipe}.sysext/test.sh"
  if [[ -z "${recipe}" ]] || ! _test_has_commands "${hook}"; then
    echo "  -> ${name}: workflow tests SKIPPED (missing or empty hook; merge-only coverage)"
    _harness_coverage="merge-only coverage for one or more images; workflow tests SKIPPED"
    return 0
  fi
  echo "  -> Running recipe hook: ${recipe}.sysext/test.sh"
  if ! _test_ssh "${key}" "${port}" 'bash -euo pipefail -s' "${timeout}" <"${hook}"; then
    echo "ERROR: Recipe hook failed or timed out: ${recipe}"
    return 1
  fi
  echo "  -> ${name}: recipe hook passed"
}

function _test_diagnostics() {
  local key="${_harness_workdir}/identity/id_ed25519"
  if [[ -f "${key}" ]]; then
    _test_ssh "${key}" "${_harness_port}" \
      'systemctl status systemd-sysext.service --no-pager; journalctl -u systemd-sysext.service -b --no-pager -n 40; systemd-sysext status --json=short' \
      >"${_harness_workdir}/guest.log" 2>&1 || true
  fi
  local log
  for log in qemu.log server.log guest.log; do
    if [[ -s "${_harness_workdir}/${log}" ]]; then
      echo "--- ${log} ---"
      tail -n 25 "${_harness_workdir}/${log}"
    fi
  done
}

function test_sysext() (
  _test_sysext "$@"
)

function _test_sysext() {
  set -euo pipefail
  local extensions=() names=() digests=() arg target filename value tool
  local arch=amd64 ssh_port="" timeout=90 test_timeout=90 keep_vm=false
  local checksums="" require_checksums=false
  while [[ $# -gt 0 ]]; do
    arg="$1"
    shift
    case "${arg}" in
      help|--help) _test_help; return 0;;
      --arch|--port|--timeout|--test-timeout|--keep-vm|--checksums|--require-checksums)
        if [[ $# -eq 0 || "$1" == --* ]]; then echo "ERROR: Missing value for ${arg}"; return 1; fi
        value="$1"; shift
        case "${arg}" in
          --arch) arch="${value}";;
          --port) ssh_port="${value}";;
          --timeout) timeout="${value}";;
          --test-timeout) test_timeout="${value}";;
          --keep-vm) keep_vm="${value}";;
          --checksums)
            if [[ -z "${value}" ]]; then echo "ERROR: Missing value for --checksums"; return 1; fi
            checksums="${value}";;
          --require-checksums) require_checksums="${value}";;
        esac;;
      --*) echo "ERROR: Unknown option ${arg}"; return 1;;
      *) extensions+=("${arg}");;
    esac
  done
  [[ "${arch}" != x86-64 ]] || arch=amd64
  if [[ "${arch}" != amd64 && "${arch}" != arm64 ]]; then echo "ERROR: Invalid architecture"; return 1; fi
  if [[ "${keep_vm}" != true && "${keep_vm}" != false ]]; then echo "ERROR: Invalid --keep-vm value"; return 1; fi
  if [[ "${require_checksums}" != true && "${require_checksums}" != false ]]; then echo "ERROR: Invalid --require-checksums value"; return 1; fi
  for value in "${timeout}" "${test_timeout}"; do
    if [[ ! "${value}" =~ ^[1-9][0-9]{0,5}$ ]]; then echo "ERROR: Timeouts must be positive integers (max 999999)."; return 1; fi
  done
  if [[ -n "${ssh_port}" ]] && { [[ ! "${ssh_port}" =~ ^[1-9][0-9]{0,4}$ ]] || (( ssh_port > 65535 )); }; then
    echo "ERROR: Invalid SSH port"; return 1
  fi
  if [[ ${#extensions[@]} -eq 0 ]]; then echo "ERROR: Missing extension image"; _test_help; return 1; fi
  local index=0
  for arg in "${extensions[@]}"; do
    target="${arg}"
    if [[ ! -f "${target}" && -f "${target}.raw" ]]; then target="${target}.raw";
    elif [[ ! -f "${target}" && -f "${target%.sysext}.raw" ]]; then target="${target%.sysext}.raw"; fi
    filename="$(basename "${target}")"
    if [[ ! -f "${target}" || ! "${filename}" =~ ^[A-Za-z0-9][A-Za-z0-9._+-]*\.raw$ ]]; then
      echo "ERROR: Expected an existing .raw image: ${arg}"; return 1
    fi
    for value in "${names[@]}"; do
      if [[ "${filename}" == "${value}" ]]; then echo "ERROR: Duplicate image basename: ${filename}"; return 1; fi
    done
    names+=("${filename}")
    extensions[index]="$(cd "$(dirname "${target}")"; pwd)/${filename}"
    index=$(( index + 1 ))
  done
  if ! command -v python3 >/dev/null; then echo "ERROR: Missing prerequisite: python3"; return 1; fi

  _harness_qemu_pid="" _harness_server_pid="" _harness_check_pid="" _harness_butane_name=""
  _harness_keep_vm="${keep_vm}" _harness_complete=false
  _harness_coverage="delivery, merge and available recipe hooks"
  _harness_port="${ssh_port}"
  local key deadline ready=false attempt
  _harness_workdir="$(mktemp -d)"
  trap '_cleanup_harness "$?"' EXIT
  trap '_cleanup_harness 130' INT
  trap '_cleanup_harness 143' TERM
  trap '_cleanup_harness 129' HUP
  chmod 700 "${_harness_workdir}"
  mkdir "${_harness_workdir}/identity" "${_harness_workdir}/artifacts" "${_harness_workdir}/vm"
  mkdir "${_harness_workdir}/vm/tmp"
  cp -- "${extensions[@]}" "${_harness_workdir}/artifacts/"
  index=0
  local recipe digest
  for target in "${extensions[@]}"; do
    filename="${names[index]}"
    recipe="$(_test_recipe "${filename%.raw}")"
    _test_run 90 python3 "${_test_helper}" verify-artifact "${_harness_workdir}/artifacts/${filename}" \
      "${recipe}" "${checksums}" "${require_checksums}" "${target}" >"${_harness_workdir}/digest.out" || return 1
    digest="$(cat "${_harness_workdir}/digest.out")"
    digests[index]="${digest}"
    index=$(( index + 1 ))
  done
  local qemu=qemu-system-x86_64
  [[ "${arch}" != arm64 ]] || qemu="qemu-system-aarch64"
  for tool in ssh ssh-keygen curl docker gpg "${qemu}"; do
    if ! command -v "${tool}" >/dev/null; then echo "ERROR: Missing prerequisite: ${tool}"; return 1; fi
  done
  key="${_harness_workdir}/identity/id_ed25519"
  ssh-keygen -t ed25519 -N "" -f "${key}" -C sysext-test >/dev/null
  chmod 600 "${key}"

  python3 "${_test_helper}" serve "${_harness_workdir}/artifacts" "${_harness_workdir}/http.port" \
    >"${_harness_workdir}/server.log" 2>&1 &
  _harness_server_pid=$!
  deadline=$(( SECONDS + 10 ))
  until [[ -s "${_harness_workdir}/http.port" ]]; do
    if ! kill -0 "${_harness_server_pid}" 2>/dev/null || (( SECONDS >= deadline )); then
      echo "ERROR: Artifact server failed to start"; _test_diagnostics; return 1
    fi
    sleep 0.1
  done
  local http_port
  http_port="$(cat "${_harness_workdir}/http.port")"
  _harness_butane_name="sysext-test-$(basename "${_harness_workdir}" | tr '[:upper:]' '[:lower:]')"
  SSH_AUTH_KEY="$(cat "${key}.pub")" SYSEXT_HTTP_PORT="${http_port}" BUTANE_CONTAINER_NAME="${_harness_butane_name}" \
    _test_run 90 bash -c 'source "$1"; _generate_config "$2" "" "${@:3}"' \
      _ "${_test_helper%/*}/libbakery.sh" "${_harness_workdir}/vm" "${names[@]}"
  _test_wait python3 "${_test_helper}" prepare "${arch}" \
    "${PWD}/.cache/sysext-test/${arch}" "${_harness_workdir}/vm"
  python3 "${_test_helper}" patch-launcher "${_harness_workdir}/vm/flatcar_production_qemu_uefi.sh"
  for attempt in 1 2 3; do
    [[ -n "${ssh_port}" ]] || _harness_port="$(_find_free_port)"
    echo "Booting ${arch} Flatcar (attempt ${attempt}); SSH on 127.0.0.1:${_harness_port}"
    (
      cd "${_harness_workdir}/vm"
      # Keep launcher-created config drives inside our cleanup boundary.
      export TMPDIR="${_harness_workdir}/vm/tmp"
      exec python3 "${_test_helper}" run 0 "${_harness_workdir}/qemu.pid" \
        ./flatcar_production_qemu_uefi.sh -i boot.json -p "${_harness_port}" -snapshot -nographic
    ) >"${_harness_workdir}/qemu.log" 2>&1 &
    _harness_qemu_pid=$!
    deadline=$(( SECONDS + timeout ))
    while (( SECONDS < deadline )); do
      if ! kill -0 "${_harness_server_pid}" 2>/dev/null || ! kill -0 "${_harness_qemu_pid}" 2>/dev/null; then break; fi
      if _test_ssh "${key}" "${_harness_port}" true 2 >/dev/null 2>&1; then ready=true; break; fi
      sleep 1
    done
    if [[ "${ready}" == true ]]; then break; fi
    if [[ -z "${ssh_port}" ]] && grep -Eq 'host forwarding rule|Address already in use' "${_harness_workdir}/qemu.log"; then
      kill -TERM "${_harness_qemu_pid}" 2>/dev/null || true
      wait "${_harness_qemu_pid}" || true
      _harness_qemu_pid=""
      echo "Retrying automatic SSH port after bind failure"
    else
      break
    fi
  done
  if [[ "${ready}" != true ]]; then echo "ERROR: VM exited or SSH readiness timed out"; _test_diagnostics; return 1; fi
  local image
  index=0
  for image in "${extensions[@]}"; do
    if ! _run_sysext_checks "${key}" "${_harness_port}" "${image}" "${digests[index]}"; then _test_diagnostics; return 1; fi
    index=$(( index + 1 ))
  done
  for image in "${extensions[@]}"; do
    if ! _run_sysext_hook "${key}" "${_harness_port}" "${image}" "${test_timeout}"; then _test_diagnostics; return 1; fi
  done
  _harness_complete=true
}
