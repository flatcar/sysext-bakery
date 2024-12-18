#!/bin/bash
#
# Build a bakery release of all sysexts.
#
# The release will include all sysexts from the "latest" release
# (these will be downloaded). Sysexts listed in release_build_versions.txt
# and _not_ included in the "latest" release will be built.

set -euo pipefail

: ${REPO:=flatcar/sysext-bakery}

echo
echo "Fetching list of latest Kubernetes minor releases"
echo "================================================="
KBS_VERS=$(curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
                --retry-max-time 60 --connect-timeout 20  \
                https://raw.githubusercontent.com/kubernetes/website/main/data/releases/schedule.yaml \
		| yq -r '.schedules[] | .previousPatches[0] // (.release = .release + ".0") | .release')
if [[ -z "${KBS_VERS}" ]] ; then
    echo "Failed fetching Kubernetes versions"
    exit 1
fi

KBS_VERS_ARRAY=(${KBS_VERS})
printf "%s\n" "${KBS_VERS_ARRAY[@]}"

# fetch_releases returns available for a given software
# based on Kubernetes major versions.
function fetch_releases {
	local software="${1}"
	local file; file=$(mktemp)
	local versions=()

	git ls-remote --tags --sort=-v:refname "https://github.com/${software}" \
	    | grep -v "{}" \
	    | awk '{ print $2}' \
	    | cut --delimiter='/' --fields=3 \
	    > "${file}"

	local version component r
	for r in "${KBS_VERS_ARRAY[@]}"; do
	    if ! grep -q "v${r%.*}" "${file}"; then
		continue
	    fi
	    version=$(cat "${file}" | grep "v${r%.*}" | grep -v "rc"| head -n1)
	    component="${software#*/}"

	    # remove extra '-' from component name (e.g cri-o -> crio)
	    component="${component//-/}"
	    versions+=( "${component}-${version}" )
	done

	rm -f "${file}"

	echo "${versions[@]}"
}

echo
echo "Fetching previous 'latest' release sysexts"
echo "=========================================="
curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
         --retry-max-time 60 --connect-timeout 20  \
         https://api.github.com/repos/"${REPO}"/releases/latest \
    | jq -r '.assets[] | "\(.name)\t\(.browser_download_url)"' | { grep -E '\.raw$' || true; } | tee prev_release_sysexts.txt

while IFS=$'\t' read -r name url; do
    echo
    echo "  ## Fetching ${name} <-- ${url}"
    curl -o "${name}" -fsSL --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20  "${url}"
done <prev_release_sysexts.txt

streams=()

echo
echo "Building sysexts"
echo "================"

mapfile -t images < <( awk '{ content=sub("[[:space:]]*#.*", ""); if ($0) print $0; }' \
                       release_build_versions.txt )

KUBERNETES=()
for v in "${KBS_VERS_ARRAY[@]}"; do
    KUBERNETES+=( "kubernetes-v${v}" )
done
images+=( $(fetch_releases "k3s-io/k3s") )
images+=( $(fetch_releases "cri-o/cri-o") )
images+=( $(fetch_releases "rancher/rke2") )
images+=( "${KUBERNETES[@]}" )

echo "building: ${images[@]}"

echo "# Release $(date '+%Y-%m-%d %R')" > Release.md
echo "The release adds the following sysexts:" >> Release.md

for image in "${images[@]}"; do
  component="${image%-*}"
  version="${image#*-}"
  for arch in x86-64 arm64; do
    target="${image}-${arch}.raw"
    if [ -f "${target}" ] ; then
        echo "  ## Skipping ${target} because it already exists (asset from previous release)"
        continue
    fi
    echo "  ## Building ${target}."
    ARCH="${arch}" "./create_${component}_sysext.sh" "${version}" "${component}"
    mv "${component}.raw" "${target}"
    echo "* ${target}" >> Release.md
  done
  streams+=("${component}:-@v")
  case "${component}" in
    kubernetes|crio|rke2|k3s)
      # Should give, e.g., v1.28 for v1.28.2 (use ${version#*.*.} to get 2)
      streams+=("${component}-${version%.*}:.@v")
  esac
done
  
echo "" >> Release.md
echo "The release includes the following sysexts from previous releases:" >> Release.md
awk '{ print "* ["$1"]("$2")" }' prev_release_sysexts.txt >>Release.md

echo
echo "Generating systemd-sysupdate configurations and SHA256SUM."
echo "=========================================================="

for stream in "${streams[@]}"; do
  component="${stream%:*}"
  pattern="${stream#*:}"
  cat << EOF > "${component}.conf"
[Transfer]
Verify=false
[Source]
Type=url-file
Path=https://github.com/flatcar/sysext-bakery/releases/latest/download/
MatchPattern=${component}${pattern}-%a.raw
[Target]
InstancesMax=3
Type=regular-file
Path=/opt/extensions/${component%-*}
CurrentSymlink=/etc/extensions/${component%-*}.raw
EOF
done

cat << EOF > "noop.conf"
[Source]
Type=regular-file
Path=/
MatchPattern=invalid@v.raw
[Target]
Type=regular-file
Path=/
EOF

# Generate new SHA256SUMS from all assets
sha256sum *.raw | tee SHA256SUMS
