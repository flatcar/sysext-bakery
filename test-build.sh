#!/usr/bin/env bash
# Test building both docker and containerd-docker sysexts

set -euo pipefail

# Get the latest docker version
DOCKER_VERSION=$(./bakery.sh list docker --latest true | head -n 1)
echo "Building with Docker version: ${DOCKER_VERSION}"

# Build both docker and containerd-docker sysexts
./bakery.sh create docker "${DOCKER_VERSION}"

echo "Build completed successfully!" 