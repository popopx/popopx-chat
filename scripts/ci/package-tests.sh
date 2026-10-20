#!/bin/bash

set -euo pipefail

cd "$(dirname "$0")/../.."
nodejs=packages/popopx-chat-nodejs
python_package=packages/popopx-chat-python
python=$(command -v python3 || command -v python)
temp=${RUNNER_TEMP:-$(mktemp -d)}

usage() {
  echo "usage: $0 build <platform> | test | addon <platform> | publish <platform> [nodejs] [python]" >&2
  exit 1
}

build_package() {
  (cd packages/popopx-chat-client/types/typescript && npm install --no-audit --no-fund && npx tsc)
  (cd "$nodejs" && npm install --ignore-scripts --no-save --no-audit --no-fund ../popopx-chat-client/types/typescript)
  if [ -n "${1:-}" ]; then
    (cd "$nodejs" && npx --yes node-gyp rebuild)
  fi
  (cd "$nodejs" && npx tsc && cp src/popopx.* dist)
  if [ -n "${1:-}" ]; then
    cp "$nodejs/build/Release/popopx.node" "$nodejs/build/popopx-chat-nodejs-$1.node"
  fi
}

test_nodejs() {
  (cd "$nodejs" && npx jest --forceExit)
}

test_python() {
  (unset POPOPX_LIBS_DIR && cd "$python_package" && "$python" -m pip install -e ".[test]" && "$python" -m pytest -q)
}

case "${1:-}" in
  build)
    [ $# -eq 2 ] || usage
    build_package "$2"
    ;;
  test)
    [ $# -eq 1 ] || usage
    test_nodejs
    test_python
    ;;
  addon)
    [ $# -eq 2 ] || usage
    build_package "$2"
    zip=popopx-chat-libs-$2.zip
    "$python" scripts/ci/packages_release.py download "$LIBS_RELEASE" "$zip" "$temp/libs"
    "$python" -m zipfile -e "$temp/libs/$zip" "$temp/libs"
    POPOPX_LIBS_DIR=$temp/libs/libs test_nodejs
    gh release upload "$ADDON_TAG" "$nodejs/build/popopx-chat-nodejs-$2.node" --clobber --repo "$LIBS_REPOSITORY"
    ;;
  publish)
    [ $# -ge 2 ] || usage
    platform=$2
    shift 2
    for suite in "$@"; do
      case "$suite" in
        nodejs)
          build_package
          addon=popopx-chat-nodejs-$platform.node
          "$python" scripts/ci/packages_release.py download-pinned "$addon" "$temp/addon"
          mkdir -p "$nodejs/build/Release"
          cp "$temp/addon/$addon" "$nodejs/build/Release/popopx.node"
          test_nodejs
          ;;
        python)
          test_python
          ;;
        *)
          usage
          ;;
      esac
    done
    ;;
  *)
    usage
    ;;
esac
