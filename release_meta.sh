#!/bin/bash
#
# Update bakery release metadata
#
# If a sysext name is provided in "$1" we download
#  - all sysupdate configurations
#  - all SHA256SUMS
# and create a new extension metadata release from that.
#
# If $1 is empty, we update the global SHA256SUMS covering all releases.

set -euo pipefail
cd "$(dirname "$0")"
source "lib/libbakery.sh"

rm -f *.raw SHA256SUMS.* SHA256SUMS *.conf Release.md

extension="$(extension_name "${@:-}")"
tag="${extension:-SHA256SUMS}"

function out() {
  echo "${@:-}" | tee -a Release.md
}
# --

function fetch_artefacts() {
  local release="$1"


  { curl_wrapper \
         "https://api.github.com/repos/${bakery}/releases/tags/${release}" \
  | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"' | grep -E '(SHA256SUMS|.conf)$' || true; } \
  > downloads.txt

  while IFS=$'\t' read -r name url; do
    echo "  Fetching ${name} <-- ${url}"
    curl_wrapper \
      -o "${name}" -fsSL --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 \
       --connect-timeout 20  "${url}"
  done <downloads.txt

  rm -f downloads.txt
}
# --

function fetch_extension_metadata() {
  local extension="$1"
  local versions="$(./bakery.sh list-bakery "${extension}")"

  if [[ -z "${versions}" ]] ; then
    out "* SKIPPED ${extension} as no releases are available"
    touch SHA256SUMS
    return
  fi

  for version in $(./bakery.sh list-bakery "${extension}"); do
    release="${extension}-${version}"
    out "* ${release}"
    fetch_artefacts "${release}"
    cat SHA256SUMS >> SHA256SUMS.all
  done

  mv SHA256SUMS.all SHA256SUMS
}
# --

if [[ -n $extension ]] ; then

  out "# Extension ${extension} metadata release."

  fetch_extension_metadata "$extension"

  out ""
  out "## Sysupdate confs:"
  out '```'
  ls -1 *.conf | tee -a Release.md
  out '```'

else

  out "# Global SHA256SUMS metadata release."
  out ""

  for extension in $(./bakery.sh list --plain true); do
    fetch_artefacts "$extension"
		if [[ ! -f SHA256SUMS ]] ; then
	    out "* SKIPPED ${extension} as no SHA256SUMS is available"
			continue
		fi
    cat SHA256SUMS >> SHA256SUMS.global
		out "* ${extension}:"
		awk '{ print "  * " $2 }' SHA256SUMS | tee -a Release.md
    rm SHA256SUMS
  done

  mv SHA256SUMS.global SHA256SUMS
fi
# --

out ""
out "# SHA256SUMS:"
out '```'
cat SHA256SUMS | tee -a Release.md
out '```'

git tag -f "${tag}"
git push origin "${tag}" --force
