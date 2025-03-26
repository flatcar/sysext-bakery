#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Bakery library functions for listing extensions available for build, versions available for extension.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

function _print_line() {
    printf "| %30.30s | %7.7s | %5.5s | %4.4s |\n" "${@}"
}
# --

function _has_function() {
  local file="$1"
  local func="$2"
  (
    set +e
    source "$file" >/dev/null 2>&1
    set -e
    if [[ $(type -t $func) == function ]] ; then
      echo "Yes"
    else
      echo "No"
    fi
  )
}
# --

function _list_all_sysexts() {
  local plain="$(get_optional_param "plain" "false" "${@}")"

  if [[ $plain != true  ]]; then
    announce "The following extension build scripts are available"
    echo
    _print_line "Extension name" "Static" "Build" "Test"
    _print_line "" "Files" ""
    _print_line "------------------------------" "-------" "-----" "----"
  fi

  local dir=""
  find "${scriptroot}" -regex '.*\.sysext$' | sort | while read dir ; do
    local extname="$(basename "${dir}")"
    if [[ ! -d "${dir}" ]] || [[ $extname == _skel* ]]; then
      continue
    fi

    if [[ $plain == true  ]]; then
      echo "${extname%.sysext}"
      continue
    fi

    local has_files="No"
    if [[ -d "${dir}/files/usr" ]] || [[ -d "${dir}/files/opt" ]] ; then
      has_files="Yes"
    fi
    local has_build="$(_has_function "${dir}/create.sh" "populate_sysext_root")"
    local has_test="$(_has_function "${dir}/create.sh" "run_tests")"

    _print_line "${extname%.sysext}" "${has_files}" "${has_build}" "${has_test}"
  done
}
# --

function _list_sysext_versions() {
  local extname="$(extension_name "$(get_positional_param 1 "${@}")")"
  local extscript="${scriptroot}/${extname}.sysext/create.sh"

  if [[ ! -f "${extscript}" ]] ; then
    echo "ERROR: Extension script '${extscript}' not found"
    return 1
  fi

  if [[ $(_has_function "${extscript}" "list_available_versions") != "Yes" ]] ; then
    echo "No version information for '$extname'"
    return
  fi

  local func="list_available_versions"
  if [[ $(get_optional_param 'latest' 'false' "${@}") == true ]] ; then
    func="list_latest_release"
  fi

  (
    source "${extscript}"
    "$func"
  )
}
# --

function _list_bakery_releases() {
  local extname="$(extension_name "$(get_positional_param 1 "${@}")")"
  local extscript="${scriptroot}/${extname}.sysext/create.sh"

 (
    EXTENSION_VERSION_MATCH_PATTERN='[.v0-9]+'

    if [[ -f "${extscript}" ]] ; then
      source "${extscript}"
    fi

    list_github_releases "${bakery%/*}" "${bakery#*/}" \
      | sed --quiet -r "s/^${extname}-(${EXTENSION_VERSION_MATCH_PATTERN})$/\\1/p" \
      | uniq
 )
}
# --

function list_sysext() {
  local extname="$(extension_name "$(get_positional_param 1 "${@}")")"
  
  if [[ -n "${extname}" ]] ; then
    _list_sysext_versions "${@}"
  else
    _list_all_sysexts "${@}"
  fi
}
# --

function list-bakery_sysext() {
  if [[ -n "${@}" ]] ; then
    _list_bakery_releases "${@}"
  else
    echo "ERROR: missing mandatory <sysext> argument" 
  fi
}
# --
