#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
make build
"build/CodexAccountManagerNext.app/Contents/MacOS/CodexAccountManagerNext" --self-test-palettes
