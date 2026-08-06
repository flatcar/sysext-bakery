#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke test skeleton for sysext bakery extensions.
#
# Copy this file to <your-extension>.sysext/test.sh and implement run_tests().
#
# All helper functions (test_binary_exists, test_binary_version, etc.) are
# provided by lib/test.sh and are available here automatically.
#

# run_tests is called by "bakery.sh test <sysext-root> <extension-name>".
# The sysext root directory is available as ${_TEST_SYSEXTROOT}.
function run_tests() {
  # 1. Verify the extension-release file is present and non-empty.
  test_extension_release_present "CHANGEME"

  # 2. Verify no /usr/sbin is shipped (Flatcar constraint).
  test_no_usr_sbin

  # 3. Check that expected binaries are present in the sysext root.
  test_binary_exists "CHANGEME"

  # 4. After the sysext is merged on a live system, check version output.
  #    Uncomment and adapt when running an integration test.
  # test_binary_version "CHANGEME" "--version" "CHANGEME version [0-9]"

  # 5. Check that required systemd unit files are present (if your sysext
  #    ships a service).
  # test_service_file_exists "CHANGEME.service"
}
