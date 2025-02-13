#!/bin/bash
#
# Build a bakery release of all sysexts.
#
# The release will include all sysexts from the "latest" release
# (these will be downloaded). Sysexts listed in release_build_versions.txt
# and _not_ included in the "latest" release will be built.

set -euo pipefail

: ${REPO:=flatcar/sysext-bakery}

cd "$(dirname "$0")"

rm -f *.raw SHA256SUMS.* SHA256SUMS *.conf

echo
echo "Fetching previous 'latest' release sysexts list"
echo "==============================================="
{ curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
         --retry-max-time 60 --connect-timeout 20  \
         https://api.github.com/repos/"${REPO}"/releases/latest \
    | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"' | grep -E '(\.raw|.conf)$' || true; } | tee prev_release_sysexts.txt

echo
echo "Fetching previous 'latest' release sysexts"
echo "==============================================="

while IFS=$'\t' read -r name url; do
    echo "  ## Fetching ${name} <-- ${url}"
    curl -o "${name}" -fsSL --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 \
         --connect-timeout 20  "${url}"
done <prev_release_sysexts.txt

sha256sum *.raw | tee SHA256SUMS


echo
echo "Building sysexts"
echo "================"

mapfile -t images < <( awk '{ sub("[[:space:]]*#.*", ""); if ($0) print $0; }' \
                       release_build_versions.txt )

echo "building: ${images[@]}"

echo "# Release $(date '+%Y-%m-%d %R')" > Release.md
echo "The release adds the following sysexts:" >> Release.md

for image in "${images[@]}"; do
  extension="${image% *}"
  version="${image#* }"

  if [ "${version}" = "latest" ] ; then
    mapfile -t version < <( ./bakery.sh list "${extension}" --latest true )
  fi

  for arch in x86-64 arm64; do
    target="${extension}-${version}-${arch}"
    target_oldname="${extension/-/_}-${version}-${arch}"

    if [ -f "${target}.raw" -o -f "${target_oldname}.raw" ] ; then
        echo "  ## Skipping ${target} / ${target_oldname} because it already exists (asset from previous release)"
        continue
    fi

    for v in "${version[@]}"; do
      echo "---------------------------------------------------------------------------"
      echo "  ## Building ${extension} version ${v} for ${arch}: ${target}."
      echo "---------------------------------"
      ./bakery.sh create "${extension}" "${v}" --arch "${arch}" --sysupdate true

      mv "${extension}.raw" "${target}.raw"
      cat SHA256SUMS."${extension}" >> SHA256SUMS

      echo "* ${target}" >> Release.md
    done
  done

done
  
echo "" >> Release.md

echo "The release includes the following sysexts from previous releases:" >> Release.md
awk '{ print "* ["$1"]("$2")" }' prev_release_sysexts.txt >>Release.md

# generate sysupdate config for "noop hack"
cat << EOF > "noop.conf"
[Source]
Type=regular-file
Path=/
MatchPattern=invalid@v.raw
[Target]
Type=regular-file
Path=/
EOF
