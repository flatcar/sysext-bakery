#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Smoke tests for the docker-compose sysext.
# See _skel.sysext/test.sh for the test hook contract.

function run_tests() {
  check "the compose plugin is installed" \
        test -x /usr/local/lib/docker/cli-plugins/docker-compose

  # Compose is a docker CLI plugin: it is only useful if the docker that comes
  #  with the OS image picks it up from the directory the extension ships it in.
  check "docker finds the compose plugin" docker compose version
}
# --
