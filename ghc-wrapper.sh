#!/bin/bash
export DYLD_FALLBACK_LIBRARY_PATH=/usr/local/opt/openssl@3/lib
exec /Users/elliot/.ghcup/ghc/9.6.3/bin/ghc-9.6.3 "$@"
