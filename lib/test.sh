#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions to validate a Flatcar image with a sysext.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

libroot="$(dirname "${BASH_SOURCE[0]}")"
# shellcheck disable=SC1090,SC1091
source "${libroot}/helpers.sh"
# shellcheck disable=SC1090,SC1091
source "${libroot}/boot.sh"

function _test_help() {
  echo "Test a local Flatcar VM and provision an extension for automated testing."
  echo
  echo " Positional (mandatory) arguments:"
  echo "  <sysext>: Extension image file to test. Must end in .raw"
  echo
  echo " Optional arguments:"
  echo " --arch <amd64|arm64>: Architecture of the extension file."
}

function test_sysext() {
  local extfile
  extfile="$(get_positional_param "1" "${@}")"
  if [[ -z "${extfile}" ]] || [[ "${extfile}" == "help" ]]; then
    _test_help
    return
  fi

  if [[ ! -f "${extfile}" ]]; then
    echo "ERROR: Extension file '${extfile}' not found."
    return 1
  fi

  local extbasename
  extbasename="$(basename "${extfile}")"
  local extname="${extbasename%%-*}"
  extname="${extname%.raw}"
  extname="$(extension_name "${extname}")"

  if [[ -z "${extname}" ]]; then
    echo "ERROR: Could not resolve extension directory for '${extbasename}'."
    return 1
  fi

  local arch
  arch="$(get_optional_param "arch" "amd64" "${@}")"
  local scriptroot
  scriptroot="$(dirname "${libroot}")"
  local testscript="${scriptroot}/${extname}.sysext/test.sh"

  local workdir
  workdir="$(mktemp -d)"
  # trap 'rm -rf "${workdir:-}"' RETURN

  local butane="${workdir}/test.yaml"
  local runner="${workdir}/test-runner.sh"
  local dynamic_test="${workdir}/dynamic-test.sh"

  if [[ -s "${testscript}" ]]; then
    cp "${testscript}" "${dynamic_test}"
  else
    echo "echo 'No test.sh provided. Skipping dynamic tests.'" > "${dynamic_test}"
  fi
  local runner="${workdir}/test-runner.sh"

  cat > "${runner}" <<EOF
#!/bin/bash
set -euo pipefail

exec > /dev/kmsg 2>&1

echo "Running tests for ${extname}..."

# Verify that systemd-sysext actually merged extensions
if ! systemctl is-active systemd-sysext.service > /dev/null; then
    echo "ERROR: systemd-sysext.service is not active. The extension may be invalid."
    exit 1
fi

# Verify the extension-release file exists in the merged tree
if [ ! -f "/usr/lib/extension-release.d/extension-release.${extname}" ]; then
    echo "ERROR: Missing extension-release file in merged /usr. Found:"
    ls -l /usr/lib/extension-release.d/ || true
    exit 1
fi

if [ -f "/opt/bin/dynamic-test.sh" ]; then
    echo "Executing custom test script..."
    chmod +x "/opt/bin/dynamic-test.sh"
    /opt/bin/dynamic-test.sh
else
    echo "No custom test.sh found."
fi

echo "Test runner completed successfully."
EOF
  chmod +x "${runner}"



  cat > "${butane}" <<EOF
version: 1.0.0
variant: flatcar
storage:
  files:
    - path: /opt/bin/test-runner.sh
      mode: 0755
      contents:
        local: test-runner.sh
    - path: /opt/bin/dynamic-test.sh
      mode: 0755
      contents:
        local: dynamic-test.sh
    - path: /etc/extensions/${extname}.raw
      mode: 0644
      contents:
        source: http://10.0.2.2:12345/${extbasename}
systemd:
  units:
    - name: update-engine.service
      mask: true
    - name: locksmithd.service
      mask: true
    - name: sysext-test.service
      enabled: true
      contents: |
        [Unit]
        Description=Sysext Test Runner
        Wants=systemd-sysext.service
        After=systemd-sysext.service
        ConditionPathExists=/opt/bin/test-runner.sh

        [Service]
        Type=idle
        StandardOutput=journal+console
        StandardError=journal+console
        ExecStart=/opt/bin/test-runner.sh
        ExecStopPost=/bin/sh -c 'if [ "\$EXIT_STATUS" = "0" ]; then echo "TEST_SUCCESS_MARKER" > /dev/kmsg; else echo "TEST_FAILURE_MARKER" > /dev/kmsg; fi; sleep 1; systemctl poweroff --no-block'

        [Install]
        WantedBy=multi-user.target
EOF

  # Map sysext architecture names to Flatcar OS architectures
  local os_arch="${arch}"
  if [[ "${os_arch}" == "x86-64" || "${os_arch}" == "x86_64" ]]; then
    os_arch="amd64"
  fi
  if [[ "${os_arch}" == "aarch64" ]]; then
    os_arch="arm64"
  fi

  echo "Running automated testing for ${extfile}"
  local output_log="${workdir}/qemu.log"

  boot_sysext "${extfile}" --butane "${butane}" --arch "${os_arch}" | tee "${output_log}"

  if grep -q "TEST_SUCCESS_MARKER" "${output_log}"; then
    echo "Tests passed!"
    return 0
  else
    echo "Tests failed!"
    return 1
  fi
}
