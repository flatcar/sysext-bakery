#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the containerd sysext.
#
# Tests run against the populated sysext root directory (static analysis).
# They do NOT require a live Flatcar VM.
#

function run_tests() {
  # --- Extension metadata ---
  test_extension_release_present "containerd"

  # --- Flatcar-specific constraint ---
  test_no_usr_sbin

  # --- Core binaries ---
  test_binary_exists "containerd"
  test_binary_exists "containerd-shim-runc-v2"
  test_binary_exists "ctr"
  test_binary_exists "runc"
}
