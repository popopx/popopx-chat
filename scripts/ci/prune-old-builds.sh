#!/bin/sh
set -eu

version=$(awk '/^version:/ {print $2}' popopx-chat.cabal | tr -d '\r')
for dir in "$@"; do
  if [ -d "$dir/build" ]; then
    find "$dir/build" -mindepth 3 -maxdepth 3 -type d -name 'popopx-chat-*' ! -name "popopx-chat-$version" -exec rm -rf {} +
  fi
done
