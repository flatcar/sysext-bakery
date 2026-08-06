#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the kubernetes sysext.
#
# Tests run against the populated sysext root directory (static analysis).
# They do NOT require a live Flatcar VM.
#

function run_tests() {
  # --- Extension metadata ---
  test_extension_release_present "kubernetes"

  # --- Flatcar-specific constraint ---
  test_no_usr_sbin

  # --- Core Kubernetes binaries ---
  test_binary_exists "kubectl"
  test_binary_exists "kubeadm"
  test_binary_exists "kubelet"

  # --- systemd unit files ---
  test_service_file_exists "kubelet.service"

  # --- Version files written by populate_sysext_root ---
  test_file_exists "usr/local/share/kubernetes-version"
  test_file_exists "usr/local/share/kubernetes-cni-version"

  # --- CNI plugin directory ---
  test_file_exists "usr/local/bin/cni"
}
