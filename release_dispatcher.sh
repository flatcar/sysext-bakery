#!/bin/bash
#
# Ensure parity of Bakery releases and all extensions / release versions in release_build_versions.txt.
#
# Note that only new releases will be published; existing ones removed from release_build_versions.txt
#   will not be un-published.

set -euo pipefail
cd "$(dirname "$0")"
source "lib/libbakery.sh"

output="${GITHUB_OUTPUT:-releases_to_build.txt}"

echo
echo "Checking for new extension images to be built"
echo "============================================="
echo

mapfile -t images < <( awk '{ sub("[[:space:]]*#.*", ""); if ($0) print $0; }' \
                       release_build_versions.txt )

builds=()
extensions=()

for image in "${images[@]}"; do
  extension="${image% *}"
  version="${image#* }"

  if [ "${version}" = "latest" ] ; then
    mapfile -t version < <( ./bakery.sh list "${extension}" --latest true )
  fi

  build_required="false"
  for v in "${version[@]}"; do
    echo -n "*  ${extension} ${v}: "

    if ./bakery.sh list-bakery "${extension}" | grep -qE "^${v}\$"; then
      echo "Bakery release exists."
      continue
    fi

    echo "Build required. "
    build_required="true"
    builds+=( "${extension}:${v}" )
  done

  if [[ $build_required == true ]] && ! echo "${extensions[@]}" | grep -qw "${extension}" ; then
    extensions+=( "${extension}" )
  fi
done

function to_json_array() {
  local var="$1"
  shift

  echo -n "${var}=["
  local comma="" s=""
  for s in "${@}"; do
    echo -n "$comma\"$s\""
    comma=","
  done

  echo "]"
}
# --

to_json_array "builds" "${builds[@]}" >> "$output"
to_json_array "extensions" "${extensions[@]}" >> "$output"
