#!/usr/bin/env bash
# vim: et ts=2 syn=bash
#
# Compare 2 sysext images, check for differences.
#
# Copyright (c) 2025 the Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.

set -euo pipefail


first="$1"
second="$2"

function comp_files() {
  file1="$1"
  file2="$2"
  sha256sum "$file1" \
    | sed "s,${file1},${file2}," \
    | sha256sum -c>/dev/null 2>&1
}

function compare_types() {
  file1="$1"
  file2="$2"

  file1_t="$(stat --format %F "$file1")"
  file2_t="$(stat --format %F "$file2" 2>/dev/null || true)"

  if [[ $file1_t != $file2_t ]] ; then
    if [[ -z $file2_t ]] ; then
      echo "  '${file1}' exists but '${file2}' doesn't."
      return 1
    fi
    echo "File types differ: '$file1' is '$file1_t', '$file2' is '$file2_t'"
    return 1
  fi

  if [[ $file1_t == "symbolic link" ]] ; then
    file1_l="$(stat --format %N "$file1" | sed 's/.*->//')"
    file2_l="$(stat --format %N "$file2" | sed 's/.*->//')"
    if [[ $file1_l != $file2_l ]] ; then
      echo "Symbolic links differ: '$file1' -> '$file1_l', '$file2' -> '$file2_l'"
      return 1
    fi
  fi

  return 0
}

if comp_files "$first" "$second"; then
  echo "$first and $second are identical."
  exit
fi

echo "$first and $second differ, running detailed scan."
mkdir -p mnt1 mnt2
trap 'sudo umount mnt1 mnt2' EXIT

sudo mount -o loop "$first" mnt1
sudo mount -o loop "$second" mnt2

diff_found=0
# compare 1 vs. 2 thoroughly compare each file
while read first_item; do
  second_item="${first_item/mnt1/mnt2}"

  if ! compare_types "$first_item" "$second_item" ; then
    diff_found=1
    continue
  fi

  if [[ -f "${first_item}" ]] && ! comp_files "${first_item}" "${second_item}"; then
    echo "  '${first_item}' differs from '${second_item}'."
    diff_found=1
    if [[ $(diff "${first_item}" "${second_item}") == *'Binary files'* ]] ; then
      continue
    fi
    set +e
    diff "${first_item}" "${second_item}"
    set -e
    echo "----"
  fi
done < <(find mnt1)

# Compare 2 vs. 1, only check for missing files in 1
while read second_item; do
  first_item="${second_item/mnt2/mnt1}"
  if ! compare_types "${second_item}" "$first_item" ; then
    diff_found=1
  fi
done < <(find mnt2)

if [[ $diff_found == 0 ]] ; then
  echo "No differences found in image contents."
  exit 0
else
  echo "Image contents differ."
  exit 1
fi
