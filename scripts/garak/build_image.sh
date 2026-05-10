#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
IMAGE_TAG="${IMAGE_TAG:-garak-azure:0.1.0}"

docker build \
  -f "${ROOT_DIR}/docker/garak/Dockerfile" \
  -t "${IMAGE_TAG}" \
  "${ROOT_DIR}"
