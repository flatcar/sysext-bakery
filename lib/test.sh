#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions to run automated tests on sysext images.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail

_harness_workdir=""
_harness_qemu_pid=""
_harness_server_pid=""
_harness_keep_vm="false"

function _test_help() {
  echo "Boot a local Flatcar VM and run automated tests on provisioned extension(s)."
  echo
  echo "This command launches a headless Flatcar VM in the background, provisions extension"
  echo "images via Ignition, and verifies systemd-sysext activation over SSH."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <sysext> [<sysext ...]: Extension image(s) to test. Raw image file(s) must be built."
  echo
  echo " Optional arguments:"
  echo "  --arch <amd64|arm64>  : VM architecture (default: amd64)."
  echo "  --port <port>         : Local port to forward to VM SSH (default: random free port)."
  echo "  --timeout <seconds>   : Max time to wait for VM boot (default: 90)."
  echo "  --keep-vm <true|false>: Preserve test directory on failure for debugging (default: false)."
  echo
}
# --

function _find_free_port() {
  local default_port="${1:-2222}"

  if command -v python3 >/dev/null 2>&1; then
    python3 -c "import socket; s = socket.socket(); s.bind((\"\", 0)); print(s.getsockname()[1]); s.close()"
  elif command -v python >/dev/null 2>&1; then
    python -c "import socket; s = socket.socket(); s.bind((\"\", 0)); print(s.getsockname()[1]); s.close()"
  else
    echo "${default_port}"
  fi
}
# --

function _test_ssh() {
  local key="$1"
  local port="$2"
  shift 2

  ssh -i "${key}" \
      -p "${port}" \
      -o StrictHostKeyChecking=no \
      -o UserKnownHostsFile=/dev/null \
      -o ConnectTimeout=2 \
      -o BatchMode=yes \
      -o LogLevel=ERROR \
      core@127.0.0.1 "${@}"
}
# --

function _cleanup_harness() {
  local rc=$?
  set +e

  echo "Cleaning up test environment..."

  if [[ -n "${_harness_qemu_pid:-}" ]] && kill -0 "${_harness_qemu_pid}" 2>/dev/null; then
    kill -15 "${_harness_qemu_pid}" 2>/dev/null || true
    for _ in 1 2 3; do
      if ! kill -0 "${_harness_qemu_pid}" 2>/dev/null; then break; fi
      sleep 1
    done
    kill -9 "${_harness_qemu_pid}" 2>/dev/null || true
  fi

  if [[ -n "${_harness_server_pid:-}" ]] && kill -0 "${_harness_server_pid}" 2>/dev/null; then
    kill -9 "${_harness_server_pid}" 2>/dev/null || true
  fi

  if [[ -n "${_harness_workdir:-}" && -d "${_harness_workdir}" ]]; then
    if [[ "${_harness_keep_vm:-false}" == "true" && ${rc} -ne 0 ]]; then
      echo "Preserved test directory for debugging: ${_harness_workdir}"
    else
      rm -rf "${_harness_workdir}"
    fi
  fi

  if [[ ${rc} -eq 0 ]]; then
    echo "Test run finished: PASS"
  else
    echo "Test run finished: FAIL (exit code ${rc})"
  fi

  exit ${rc}
}
# --

function test_sysext() {
  local extensions=() extension_files=() extension=""

  for extension in $(get_all_positional_params "$@"); do
    if [[ ${extension} == help ]]; then
      _test_help
      return
    fi

    local target="${extension}"
    if [[ ! -f "${target}" && -f "${target}.raw" ]]; then
      target="${target}.raw"
    elif [[ ! -f "${target}" && -f "${target%.sysext}.raw" ]]; then
      target="${target%.sysext}.raw"
    fi

    if [[ ! -f "${target}" ]]; then
      echo "ERROR: Extension file '${extension}' not found."
      echo "Please build it first with: $0 create ${extension%.raw} <version>"
      return 1
    fi

    extensions+=( "${target}" )
    extension_files+=( "$(basename "${target}")" )
  done

  if [[ ${#extensions[@]} -eq 0 ]]; then
    echo "ERROR: Missing mandatory extension argument."
    _test_help
    return 1
  fi

  local arch="$(get_optional_param "arch" "amd64" "${@}")"
  local ssh_port="$(get_optional_param "port" "" "${@}")"
  if [[ -z "${ssh_port}" ]]; then
    ssh_port="$(_find_free_port 2222)"
  fi
  local timeout="$(get_optional_param "timeout" "90" "${@}")"
  _harness_keep_vm="$(get_optional_param "keep-vm" "false" "${@}")"

  echo "Preparing test environment for ${arch}..."
  echo "Forwarding SSH via 127.0.0.1:${ssh_port} -> VM:22"

  _harness_workdir="$(mktemp -d)"
  chmod 700 "${_harness_workdir}"
  _harness_qemu_pid=""
  _harness_server_pid=""

  trap _cleanup_harness EXIT INT TERM HUP

  ssh-keygen -t ed25519 -N "" -f "${_harness_workdir}/id_ed25519" -C "sysext-test" >/dev/null 2>&1
  chmod 600 "${_harness_workdir}/id_ed25519"
  local ssh_pub_key="$(cat "${_harness_workdir}/id_ed25519.pub")"

  export SSH_AUTH_KEY="${ssh_pub_key}"
  if ! _generate_config "${_harness_workdir}" "" "${extension_files[@]}"; then
    echo "ERROR: Failed to generate Ignition configuration."
    return 1
  fi
  unset SSH_AUTH_KEY

  _download_os_image "${arch}"

  cp "${_flatcar_image_files[@]}" \
     "${extensions[@]}" \
     "${_harness_workdir}/"

  ( webserver "${_harness_workdir}" ) >/dev/null 2>&1 &
  _harness_server_pid=$!

  echo "Booting Flatcar QEMU VM in background..."
  (
    cd "${_harness_workdir}"
    _flatcar_vm "boot.json" "${ssh_port}:22" > "${_harness_workdir}/qemu.log" 2>&1
  ) &
  _harness_qemu_pid=$!

  echo "Waiting up to ${timeout}s for VM to boot..."
  local elapsed=0
  local ssh_ready=false

  while (( elapsed < timeout )); do
    if ! kill -0 "${_harness_qemu_pid}" 2>/dev/null; then
      echo "ERROR: QEMU process terminated unexpectedly during boot."
      if [[ -f "${_harness_workdir}/qemu.log" ]]; then
        echo "--- QEMU console log tail ---"
        tail -n 25 "${_harness_workdir}/qemu.log"
      fi
      return 1
    fi

    if _test_ssh "${_harness_workdir}/id_ed25519" "${ssh_port}" "true" >/dev/null 2>&1; then
      ssh_ready=true
      break
    fi

    sleep 2
    elapsed=$(( elapsed + 2 ))
  done

  if [[ ${ssh_ready} != true ]]; then
    echo "ERROR: Timed out waiting for SSH on port ${ssh_port} after ${timeout}s."
    if [[ -f "${_harness_workdir}/qemu.log" ]]; then
      echo "--- QEMU console log tail ---"
      tail -n 25 "${_harness_workdir}/qemu.log"
    fi
    return 1
  fi

  echo "VM online via SSH (${elapsed}s elapsed)."
  echo "Checking systemd-sysext merge service..."

  if ! _test_ssh "${_harness_workdir}/id_ed25519" "${ssh_port}" "systemctl is-active systemd-sysext.service" >/dev/null 2>&1; then
    echo "ERROR: systemd-sysext service failed to activate."
    _test_ssh "${_harness_workdir}/id_ed25519" "${ssh_port}" "systemctl status systemd-sysext.service --no-pager" || true
    return 1
  fi

  echo "systemd-sysext is active."
  return 0
}
# --
