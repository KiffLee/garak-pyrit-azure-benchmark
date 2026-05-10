#!/usr/bin/env bash
set -euo pipefail

# A dolgozatban hasznalt PyRIT Docker image eloallitasa.
# A build eredmenye tovabbra is a pyrit:latest image.

PYRIT_REF="v0.12.1"
PYRIT_VERSION="0.12.1"
BUILD_ROOT="/tmp/pyrit-official-build"
SOURCE_DIR="${BUILD_ROOT}/PyRIT"

mkdir -p "${BUILD_ROOT}"

if [[ ! -d "${SOURCE_DIR}/.git" ]]; then
  git clone --depth=1 --branch "${PYRIT_REF}" \
    https://github.com/microsoft/PyRIT.git \
    "${SOURCE_DIR}"
fi

git -C "${SOURCE_DIR}" fetch --tags --depth=1 origin "${PYRIT_REF}"
git -C "${SOURCE_DIR}" checkout --detach FETCH_HEAD

echo "Building PyRIT ${PYRIT_VERSION} Docker image"
(
  cd "${SOURCE_DIR}"
  python3 docker/build_pyrit_docker.py --source pypi --version "${PYRIT_VERSION}"
)

echo "Built image: pyrit:latest"
