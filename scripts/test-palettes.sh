#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
make build
"build/CodexAccountManager.app/Contents/MacOS/CodexAccountManager" --self-test-palettes
