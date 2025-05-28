#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.
#
# Bakery library functions umbrella include file.
# Source this file to get access to all library functions.

libroot="$(dirname "${BASH_SOURCE[0]}")"
scriptroot="$(cd "$(dirname "${BASH_SOURCE[0]}")/../"; pwd)"

bakery="flatcar/sysext-bakery"
bakery_hub="extensions.flatcar.org"

if [[ -s "${scriptroot}/.env" ]]; then
  source "${scriptroot}/.env"
fi

# Add new library function scripts here:
source "${libroot}/helpers.sh"
source "${libroot}/generate.sh"
source "${libroot}/list.sh"
source "${libroot}/test.sh"
