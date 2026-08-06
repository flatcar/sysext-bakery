#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the docker sysext.
#
# Tests run against the populated sysext root directory (static analysis).
# They do NOT require a live Flatcar VM.
#

function run_tests() {
  # --- Extension metadata ---
  test_extension_release_present "docker"

  # --- Flatcar-specific constraint ---
  test_no_usr_sbin

  # --- Core Docker binaries ---
  test_binary_exists "docker"
  test_binary_exists "dockerd"
  test_binary_exists "docker-init"
  test_binary_exists "docker-proxy"

  # --- Containerd and runc (bundled with docker sysext) ---
  test_binary_exists "containerd"
  test_binary_exists "containerd-shim-runc-v2"
  test_binary_exists "ctr"
  test_binary_exists "runc"

  # --- systemd unit files ---
  test_service_file_exists "docker.service"
  test_service_file_exists "docker.socket"
  test_service_file_exists "containerd.service"

  # --- containerd config files ---
  test_file_exists "usr/share/containerd/config.toml"
}
