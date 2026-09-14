#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Extension test skeleton script for sysext bakery extensions.
#

# This script is optional. Delete it if the extension has nothing to smoke test.
#
# The functions in this script run INSIDE a Flatcar test VM that has the
#  extension merged, started by
#    ./bakery.sh test <extension> --vm true
# The image itself - metadata, layout, file ownership, binary architecture, and
#  the commands its systemd units refer to - is validated by 'bakery.sh test'
#  before the VM is booted; there is no need to re-test any of that here.
#
# Only define functions here. This file is sourced, so any code at the top level
#  runs on the host as well, e.g. when 'bakery.sh list' inspects the extension.

# Smoke test the extension on a running Flatcar system.
# Called by 'bakery.sh test <extension> --vm true' without arguments, as root.
#
# The test harness provides
#   check "<description>" <command> [<argument> ...]
# which runs <command>, reports the result, and records a failure if <command>
#  exits non-zero. Failing checks do not abort the test run, so that a single
#  run reports all problems. Alternatively, return a non-zero exit code to fail.
#
# Keep tests hermetic: they run in a throw-away VM without credentials, and
#  network access to third parties makes CI flaky. Test that what the extension
#  ships is there and works, not that the shipped application is correct.
function run_tests() {
  # TODO: add smoke tests for the extension here, e.g.
  # check "the frobnicator runs"                 frobnicate --version
  # check "the frobnicator service is running"   systemctl is-active frobnicator.service
  # check "the default configuration is shipped" test -s /usr/share/frobnicator/config.toml
  true
}
# --
