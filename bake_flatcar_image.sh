#!/usr/bin/env bash
#
# Copyright (c) 2024 The Flatcar Maintainers.
# Use of this source code is governed by the Apache 2.0 license.
#
# Embed one or more sysexts into a Flatcar generic OS image.
# Optionally, build a vendor image (requires the Flatcar SDK).

fetch="no"
vendor="generic"
release="stable"

# From https://www.freedesktop.org/software/systemd/man/os-release.html#ARCHITECTURE=
arch="x86-64"
install_to="root:/opt/extensions/"

set -euo pipefail
workdir="$(pwd)/flatcar-os-image"
bakery_base_url="https://github.com/flatcar/sysext-bakery/releases/download/latest"

# ./run_sdk_container ./image_to_vm.sh --help 2>&1 | grep '\--format'
supported_vendors=( "ami" "ami_vmdk" "azure" "cloudsigma" "cloudstack" "cloudstack_vhd" "digitalocean" "exoscale" "gce" "hyperv" "iso" "openstack" "openstack_mini" "packet" "parallels" "pxe" "qemu" "qemu_uefi" "qemu_uefi_secure" "rackspace" "rackspace_onmetal" "rackspace_vhd" "vagrant" "vagrant_parallels" "vagrant_virtualbox" "vagrant_vmware_fusion" "virtualbox" "vmware" "vmware_insecure" "vmware_ova" "vmware_raw" "xen" )

function print_help() {
    echo
    echo "Usage: $0 [--fetch|--vendor|--arch|--release|--install_to <option>] <name:file> [<name:file> ...]"
    echo
    echo "Embed one or more sysexts into a Flatcar OS image. Optionally create a vendor image."
    echo "  The script will need your 'sudo' password during its run."
    echo "  Options:"
    echo "       <name:file>        Sysext name (e.g. 'kubernetes') is used to create the extensions symlink,"
    echo "                            file (e.g. 'kuibernetes-v1.29.1.raw') must be present in the local directory."
    echo "                            If a '<name>.conf' sysupdate conf exists it will also be installed in the image."
    echo "       --fetch            Instead of using a local syysext, fetch sysext and sysupdate conf from the latest"
    echo "                            Bakery release (https://github.com/flatcar/sysext-bakery/releases/tag/latest)."
    echo "       --vendor <vendor>  Create cloud vendor image from generic image after embedding."
    echo "                            By default, only a generic image is produced."
    echo "                            This command will run the Flatcar SDK container via 'docker'."
    echo "                            Supported vendors are:"
    echo -n "                               "
    local i
    for i in $(seq 0 "$((${#supported_vendors[@]} - 1))"); do
        echo -n "${supported_vendors[i]} "
        if [ "6" == "$((i%7))" -a "$i" != "$((${#supported_vendors[@]} - 1))" ] ; then
            echo
            echo -n "                               "
        fi
    done
    echo
    echo "       --arch <arch>      CPU architecture to build the image for; 'x86-64' (default) or 'arm64'."
    echo "                            Defaults to '${arch}'"
    echo "       --release          Release version (MMMM.m.p) to use."
    echo "                            Special values 'alpha', 'beta', 'stable', 'lts' will use the latest release"
    echo "                            of that channel."
    echo "                            Defaults to '${release}'"
    echo "       --install_to      <partition:install-root> Partition and installation directory of sysexts"
    echo "                            in the OS image. Partition can be 'root' and 'oem'."
    echo "                            Defaults to '${install_to}'"
    echo
}
# --

function latest_release() {
    local channel="$1"

    curl -s "https://www.flatcar.org/releases-json/releases.json" \
        | jq -r "to_entries[] | select (.value.channel==\"$channel\") | .key | match(\"[0-9]+\\\.[0-9]+\\\.[0-9]+\") | .string" \
        | sort -Vr | head -n1
}
# --

function grok_channel_release() {
    local release="$1"
    local channel=""

    case "$release" in
        alpha|beta|stable|lts)
            channel="$release"
            release=$(latest_release "${channel}");;
        *.0.*) channel="alpha";;
        *.1.*) channel="beta";;
        *.2.*) channel="stable";;
        *) channel="lts";;
    esac

    echo "${channel},${release}"
}
# --

function download_all() {
    local board="$1"
    local vendor="$2"
    local release="$3"

    local chan_rel=$(grok_channel_release "$release")
    local channel="${chan_rel%,*}"
    release="${chan_rel#*,}"

    if [ "${vendor}" != "generic" ] ; then
        echo
        echo "Fetching SDK repo for generating vendor images."
        echo
        git clone https://github.com/flatcar/scripts.git ./
        git checkout "${channel}-${release}"
    fi

    local files=( "flatcar_production_image.bin.bz2" "flatcar_production_image.bin.bz2.sig" "version.txt" "version.txt.sig" )
    if [ "${vendor}" != "generic" ] ; then
        files+=( "flatcar_production_image_sysext.squashfs" "flatcar_production_image_sysext.squashfs.sig" )
    fi
    echo
    echo "Fetching OS image release '${release}', channel '${channel}', board '${board}'"
    echo
    local f
    for f in "${files[@]}"; do
        local url="https://${channel}.release.flatcar-linux.net/${board}/${release}/$f"
        echo "    ## fetching '$url'"
        curl -fLO --progress-bar --retry-delay 1 --retry 60 --retry-connrefused \
             --retry-max-time 60 --connect-timeout 20 \
             "${url}"
    done

    echo
    echo "Verifying OS image"
    echo
    echo "    ## Importing signing key"
    curl -fLO --progress-bar --retry-delay 1 --retry 60 --retry-connrefused \
             --retry-max-time 60 --connect-timeout 20 \
            https://www.flatcar.org/security/image-signing-key/Flatcar_Image_Signing_Key.asc
    gpg --no-default-keyring --keyring flatcar.gpg --import --keyid-format LONG Flatcar_Image_Signing_Key.asc

    local files=( "flatcar_production_image.bin.bz2" "version.txt" )
    if [ "${vendor}" != "generic" ] ; then
        files+=( "flatcar_production_image_sysext.squashfs" )
    fi
    for f in "${files[@]}"; do
        echo
        echo "    ## Verifying '${f}'"
        if ! gpg --no-default-keyring --keyring flatcar.gpg --verify "${f}.sig" 2>&1 \
            | grep 'gpg: Good signature from "Flatcar Buildbot (Official Builds) <buildbot@flatcar-linux.org>"' ; then
            echo "#### FAILED signature verification for '${f}'"
            exit 1
        fi
        echo "${f}: PASS"
    done

    echo
    echo "Uncompressing OS image"
    echo
    bunzip2 flatcar_production_image.bin.bz2

    if [ "${vendor}" != "generic" ] ; then
        echo
        echo "Pulling SDK container for generating vendor images."
        echo
        (
            source version.txt
            docker pull "ghcr.io/flatcar/flatcar-sdk-all:${FLATCAR_SDK_VERSION}"
        )
    fi

    echo
    echo "Successfully downloaded version"
    echo
    cat version.txt
}
# --

function install_sysexts() {
    local install_to="$1"
    shift

    echo
    echo "Loop-mounting OS image partitions."
    echo "This action requires your 'sudo' password"
    echo

    local workdir="$(pwd)"
    local loopdev=$(sudo losetup --partscan --find --show flatcar_production_image.bin)

    function _cleanup() {
        sudo umount "${workdir}/flatcar-oem"
        sudo umount "${workdir}/flatcar-root"
        sudo losetup -d "${loopdev}"
    }
    trap _cleanup EXIT

    if mount | grep "${workdir}/flatcar-oem"; then
        sudo umount flatcar-oem
    fi
    if mount | grep "${workdir}/flatcar-root"; then
        sudo umount flatcar-oem
    fi
    mkdir -p "flatcar-oem" "flatcar-root"
    sudo mount -o loop "${loopdev}p6" "flatcar-oem"
    sudo mount -o loop "${loopdev}p9" "flatcar-root"

    local partition="${install_to%:*}"
    local partition_dir="flatcar-${partition}"
    local path="${install_to#*:}"
    # Ensure path starts and ends with a slash
    path="/${path#/}"
    path="${path%%/}/"

    local sysext
    for sysext in "${@}"; do
        local name="${sysext%:*}"
        local file="${sysext#*:}"

        echo "    ## Sysext '${name}': installing '${file}' to '${partition}' -> '${path}'"
        sudo mkdir -p "${partition_dir}${path}"
        sudo cp "../${file}" "${partition_dir}${path}"

        local symlink="/etc/extensions/${name}.raw"
        local os_destpath="${path}${file}"
        if [ "$partition" = "oem" ] ; then
            os_destpath="/oem${os_destpath}"
        fi
        echo "    ## Sysext '${name}': Creating symlink '${symlink}' -> '${os_destpath}'"
        sudo mkdir -p "flatcar-root/etc/extensions/"
        sudo ln -s "${os_destpath}" "flatcar-root${symlink}"

        if [ -f "../${name}.conf" ] ; then
            local cpath="/etc/sysupdate.${name}.d/"
            echo "    ## Sysext '${name}': installing sysupdate config '${name}.conf' to 'root' -> '${cpath}'"
            sudo mkdir -p "flatcar-root${cpath}"
            sudo cp "../${name}.conf" "flatcar-root${cpath}"
        fi
    done

    sudo umount "flatcar-oem"
    sudo umount "flatcar-root"
    sudo losetup -d "${loopdev}"
    trap "" EXIT

    echo
    echo "Done!"
}
# --

function create_vendor_image() {
    local board="$1"
    local vendor="$2"

    if [ "${vendor}" = "generic" ] ; then
        return
    fi

    trap "docker container rm --force flatcar-oem-builder" EXIT
    COREOS_OFFICIAL=1 ./run_sdk_container -n flatcar-oem-builder \
        ./image_to_vm.sh --from=./ --to=./ --board="${board}" --getbinpkg --format="${vendor}"
    docker container rm --force flatcar-oem-builder
    trap "" EXIT
}
#
# Arguments parsing + basic sanity
#

declare -a sysexts

while [ $# -gt 0 ]; do
    case "$1" in
        "--fetch")      fetch="yes";     shift;;
        "--vendor")     vendor="$2";     shift 2;;
        "--arch")       arch="$2";       shift 2;;
        "--release")    release="$2";    shift 2;;
        "--install_to") install_to="$2"; shift 2;;
        --help) print_help; exit;;
        -h)  print_help; exit;;
        --*) echo -e "\nUnknown option '$1'\n"
             print_help; exit 1;;
        *) sysexts+=("$1"); shift;;
    esac
done

if [ -z "${sysexts[*]}" ] ; then
    echo -e "\nERROR: No sysexts specified.\n"
    print_help
    exit 1
fi

for sysext in "${sysexts[@]}"; do
    name="${sysext%:*}"
    file="${sysext#*:}"
    if [ "${fetch}" = "yes" ] ; then
        echo "    ## Fetching sysext '${name}': '${file}'"
        curl -fLO --progress-bar --retry-delay 1 --retry 60 --retry-connrefused \
             --retry-max-time 60 --connect-timeout 20 \
             "${bakery_base_url}/${file}"
        echo "    ## Fetching sysupdate '${name}': '${name}.conf'"
        curl -fLO --progress-bar --retry-delay 1 --retry 60 --retry-connrefused \
             --retry-max-time 60 --connect-timeout 20 \
             "${bakery_base_url}/${name}.conf"
    elif ! [ -f "${file}" ] ; then
        echo "ERROR: Sysext file '${file}' for sysext '${sysext}' not found."
        exit 1
    fi
done

case "$arch" in
    x86-64) board="amd64-usr";;
    arm64)  board="arm64-usr";;
    *) echo "ERROR: unknown arch '${arch}'. 'x86-64' and 'arm64' are supported."
       exit 1;;
esac

case "${install_to%:*}" in
    oem);;
    root);;
    *) echo "Unsupported OS image partition '${install_to%:*}' in --install_to target."
       exit 1;;
esac

if [[ "${vendor}" != "generic" && ! ${supported_vendors[@]} =~ ${vendor} ]] ; then
    echo "ERROR: unsupported vendor '${vendor}'".
    exit 1
fi

rm -rf "${workdir}"
mkdir "${workdir}"
(
    cd "${workdir}"

    download_all "$board" "${vendor}" "$release"
    install_sysexts "${install_to}" "${sysexts[@]}"
    create_vendor_image "$board" "${vendor}"
    rm -f *.sig *.squashfs
)

mv "${workdir}/"flatcar_production* ./
sudo rm -rf "${workdir}"

echo
echo "All done. Your baked images are ready:"
echo
ls -1 flatcar_production*
echo
