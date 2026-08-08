#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Hook specification for system extension automated testing.
#
# Execution Environment:
# - This script is executed automatically inside a temporary Flatcar VM during `./bakery.sh test`.
# - It is run by systemd as root.
# - The extension image is already merged via systemd-sysext.
# - A strict static analysis (paths, ownership) runs before this script.
#
# Return Code:
# - Exit 0 on success.
# - Exit non-zero on failure.
#
# Example (for Docker):
# systemctl start docker.service
# docker run --rm alpine echo "Hello World"
