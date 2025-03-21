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

mapfile -t images < <( sed -e 's:\s*#.*::' -e '/^$/d' release_build_versions.txt )

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

    if ./bakery.sh list-bakery "${extension}" | grep -qFx "${v}"; then
      echo "Bakery release exists."
      continue
    fi

    echo "Build required. "
    build_required="true"
    builds+=( "${extension}:${v}" )
  done

  if [[ $build_required == true && " ${extensions[@]} " != *" ${extension} "* ]] ; then
    extensions+=( "${extension}" )
  fi
done

cat >> "${output}" <<EOF
builds=$(jq -r -c -n --args '$ARGS.positional' "${builds[@]}")
extensions=$(jq -r -c -n --args '$ARGS.positional' "${extensions[@]}")
EOF
