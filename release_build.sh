#!/bin/bash
#
# Build a bakery release of all sysexts.
#
# The release will include all sysexts from the "latest" release
# (these will be downloaded). Sysexts listed in release_build_versions.txt
# and _not_ included in the "latest" release will be built.

set -euo pipefail


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

echo "Fetching list of latest CRI-O patch releases"
echo "================================================="

git ls-remote --tags --sort=-v:refname https://github.com/cri-o/cri-o \
    | grep -v "{}" \
    | awk '{ print $2}' \
    | cut --delimiter='/' --fields=3 \
    > crio.txt

CRIO=()
for r in "${KBS_VERS_ARRAY[@]}"; do
    version=$(cat crio.txt | grep "v${r%.*}" | head -n1)
    CRIO+=( "crio-${version:1}" )
done

echo
echo "Fetching previous 'latest' release sysexts"
echo "=========================================="
curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
         --retry-max-time 60 --connect-timeout 20  \
         https://api.github.com/repos/flatcar/sysext-bakery/releases/latest \
    | jq -r '.assets[].browser_download_url' | grep -E '\.raw$' | tee prev_release_sysexts.txt

for asset in $(cat prev_release_sysexts.txt); do
    echo
    echo "  ## Fetching $(basename "${asset}") <-- ${asset}"
    curl -O -fsSL --retry-delay 1 --retry 60 --retry-connrefused --retry-max-time 60 --connect-timeout 20  "${asset}"
done

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
images+=( "${CRIO[@]}" )
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
  if [ "${component}" = "kubernetes" ] || [ "${component}" = "crio" ]; then
    streams+=("${component}-${version%.*}:.@v")
    # Should give, e.g., v1.28 for v1.28.2 (use ${version#*.*.} to get 2)
  fi
done
  
echo "" >> Release.md
echo "The release includes the following sysexts from previous releases:" >> Release.md
sed 's/^/* /' prev_release_sysexts.txt >> Release.md

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
