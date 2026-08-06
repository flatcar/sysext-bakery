#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library: shared helpers for sysext smoke tests.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.
#
# Usage from an extension's test.sh:
#
#   source "${scriptroot}/lib/libbakery.sh"
#
#   function run_tests() {
#     test_binary_exists "docker"
#     test_binary_version "docker" "--version"
#     test_service_file_exists "docker.service"
#     # ... add more assertions ...
#   }
#
# All test_* functions increment TESTS_PASSED or TESTS_FAILED counters and
# print a concise PASS/FAIL line.  Call test_summary at the end to print a
# result summary and exit with a non-zero code when any test failed.

TESTS_PASSED=0
TESTS_FAILED=0

# ---------------------------------------------------------------------------
# Internal helpers
# ---------------------------------------------------------------------------

_pass() {
  local desc="$1"
  : $(( TESTS_PASSED++ ))
  echo "  PASS  ${desc}"
}

_fail() {
  local desc="$1"
  local detail="${2:-}"
  : $(( TESTS_FAILED++ ))
  echo "  FAIL  ${desc}"
  if [[ -n "${detail}" ]]; then
    echo "        ${detail}"
  fi
}

# ---------------------------------------------------------------------------
# Assertion helpers
# ---------------------------------------------------------------------------

# test_binary_exists <binary>
# Assert that <binary> is present somewhere in PATH inside the sysext root.
function test_binary_exists() {
  local binary="$1"
  local sysextroot="${2:-${_TEST_SYSEXTROOT:-}}"

  if [[ -n "${sysextroot}" ]]; then
    if find "${sysextroot}/usr/bin" "${sysextroot}/usr/sbin" \
         -maxdepth 1 -name "${binary}" 2>/dev/null | grep -q .; then
      _pass "binary '${binary}' present in sysext root"
    else
      _fail "binary '${binary}' NOT found in sysext root" \
            "searched: ${sysextroot}/usr/bin, ${sysextroot}/usr/sbin"
    fi
  else
    if command -v "${binary}" &>/dev/null; then
      _pass "binary '${binary}' found in PATH"
    else
      _fail "binary '${binary}' NOT found in PATH"
    fi
  fi
}

# test_binary_version <binary> <version_flag> [expected_pattern]
# Assert that running "<binary> <version_flag>" exits 0 and optionally that
# its output matches <expected_pattern> (an ERE passed to grep -E).
function test_binary_version() {
  local binary="$1"
  local flag="${2:---version}"
  local pattern="${3:-}"

  local output
  if output="$("${binary}" "${flag}" 2>&1)"; then
    if [[ -n "${pattern}" ]]; then
      if echo "${output}" | grep -qE "${pattern}"; then
        _pass "'${binary} ${flag}' output matches '${pattern}'"
      else
        _fail "'${binary} ${flag}' output does NOT match '${pattern}'" \
              "got: ${output}"
      fi
    else
      _pass "'${binary} ${flag}' exited 0"
    fi
  else
    _fail "'${binary} ${flag}' exited non-zero" "output: ${output}"
  fi
}

# test_service_file_exists <unit-file>
# Assert that <unit-file> exists in the sysext root under
# usr/lib/systemd/system/.
function test_service_file_exists() {
  local unit="$1"
  local sysextroot="${2:-${_TEST_SYSEXTROOT:-}}"

  if [[ -z "${sysextroot}" ]]; then
    _fail "test_service_file_exists: sysext root not set" \
          "pass it as second arg or set _TEST_SYSEXTROOT"
    return
  fi

  local path="${sysextroot}/usr/lib/systemd/system/${unit}"
  if [[ -f "${path}" ]]; then
    _pass "unit file '${unit}' present in sysext root"
  else
    _fail "unit file '${unit}' NOT found in sysext root" \
          "expected: ${path}"
  fi
}

# test_file_exists <path-inside-sysext>
# Assert that a file exists at <path-inside-sysext> relative to the sysext root.
function test_file_exists() {
  local relpath="$1"
  local sysextroot="${2:-${_TEST_SYSEXTROOT:-}}"

  if [[ -z "${sysextroot}" ]]; then
    _fail "test_file_exists: sysext root not set"
    return
  fi

  local full="${sysextroot}/${relpath}"
  if [[ -e "${full}" ]]; then
    _pass "file '${relpath}' present in sysext root"
  else
    _fail "file '${relpath}' NOT found in sysext root" \
          "expected: ${full}"
  fi
}

# test_extension_release_present <extension-name>
# Assert that the extension-release file is present and non-empty.
function test_extension_release_present() {
  local extname="$1"
  local sysextroot="${2:-${_TEST_SYSEXTROOT:-}}"

  if [[ -z "${sysextroot}" ]]; then
    _fail "test_extension_release_present: sysext root not set"
    return
  fi

  local relfile="usr/lib/extension-release.d/extension-release.${extname}"
  local full="${sysextroot}/${relfile}"

  if [[ -s "${full}" ]]; then
    _pass "extension-release file present and non-empty"
  elif [[ -f "${full}" ]]; then
    _fail "extension-release file exists but is EMPTY" "path: ${full}"
  else
    _fail "extension-release file NOT found" "expected: ${full}"
  fi
}

# test_no_usr_sbin <sysext-root>
# Assert that the sysext does NOT ship /usr/sbin (which would shadow the
# host symlink on Flatcar).
function test_no_usr_sbin() {
  local sysextroot="${1:-${_TEST_SYSEXTROOT:-}}"

  if [[ -z "${sysextroot}" ]]; then
    _fail "test_no_usr_sbin: sysext root not set"
    return
  fi

  if [[ -d "${sysextroot}/usr/sbin" ]]; then
    _fail "sysext ships /usr/sbin — this will shadow the Flatcar host symlink" \
          "move binaries to /usr/bin instead"
  else
    _pass "sysext does not ship /usr/sbin"
  fi
}

# ---------------------------------------------------------------------------
# Test runner
# ---------------------------------------------------------------------------

# test_summary
# Print a summary of all PASS/FAIL results and exit 1 if any test failed.
function test_summary() {
  local total=$(( TESTS_PASSED + TESTS_FAILED ))
  echo
  echo "  Results: ${TESTS_PASSED}/${total} passed, ${TESTS_FAILED} failed"
  if [[ ${TESTS_FAILED} -gt 0 ]]; then
    echo "  OVERALL: FAIL"
    exit 1
  else
    echo "  OVERALL: PASS"
  fi
}

# test_sysext <sysext-root> <extension-name>
# Entry point called by bakery.sh's "test" command.
# Sources the extension's test.sh and calls run_tests if defined.
function test_sysext() {
  (
    set -euo pipefail

    local sysextroot="$(get_positional_param "1" "${@}")"
    local extname="$(get_positional_param "2" "${@}")"

    if [[ -z "${sysextroot}" || -z "${extname}" ]]; then
      echo "Usage: bakery.sh test <sysext-root-dir> <extension-name>"
      exit 1
    fi

    export _TEST_SYSEXTROOT="${sysextroot}"

    local testscript="${scriptroot}/${extname}.sysext/test.sh"
    if [[ ! -f "${testscript}" ]]; then
      echo "No test.sh found for extension '${extname}' — skipping."
      exit 0
    fi

    echo
    echo "  Running smoke tests for '${extname}'"
    echo "  Sysext root: ${sysextroot}"
    echo

    source "${testscript}"

    if declare -f run_tests &>/dev/null; then
      run_tests
    else
      echo "  WARNING: test.sh found but no run_tests() function defined — nothing to run."
    fi

    test_summary
  )
}
