#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the tailscale sysext.
# See _skel.sysext/test.sh for the test hook contract.

function run_tests() {
  check "the tailscale CLI runs" tailscale version

  # The extension ships a multi-user.target drop-in that starts tailscaled on
  #  merge. The daemon comes up without credentials and waits for 'tailscale
  #  up', so it must be running even in a throw-away VM.
  check "tailscaled is running" systemctl is-active tailscaled.service

  # The CLI talks to the daemon through this socket; the daemon only creates it
  #  once it is up and reading its (tmpfiles-provisioned) default settings.
  check "the tailscaled socket is served" test -S /run/tailscale/tailscaled.sock

  check "the default settings are provisioned" test -s /etc/default/tailscaled

  # Note: do not log in. The test VM has no credentials, and a login attempt
  #  would tie the test to the availability of the coordination server.
}
# --
