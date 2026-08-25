#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the btop sysext.
# See _skel.sysext/test.sh for the test hook contract.

function run_tests() {
  # btop ships as a flatwrap (see tools/flatwrap.sh): an entry point script in
  #  /usr/bin that runs the real binary in a sandbox built from the extension's
  #  own /usr/local tree. Running it covers the entry point, the sandbox setup,
  #  and the shared libraries shipped alongside the binary.
  check "btop runs" btop --version

  check "the btop sandbox root is shipped" test -d /usr/local/btop
}
# --
