# vim: et ts=2 syn=bash
# Kubernetes system extension shared functions.

# List latest patch level releases of all supported major release series
function kubernetes_list_latest_release() {
  curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
       --retry-max-time 60 --connect-timeout 20 \
       https://raw.githubusercontent.com/kubernetes/website/main/data/releases/schedule.yaml \
       | yq -r '.schedules[] | .previousPatches[0] // (.release = .release + ".0") | .release' \
       | sed 's/^/v/'
}
# --

# List all releases of all supported major release series
function kubernetes_list_available_versions() {
  curl -fsSL --retry-delay 1 --retry 60 --retry-connrefused \
       --retry-max-time 60 --connect-timeout 20 \
       https://raw.githubusercontent.com/kubernetes/website/main/data/releases/schedule.yaml \
       | yq -r '.schedules[] | .previousPatches[] // (.release = .release + ".0") | .release' \
       | sed 's/^/v/'
}
# --
