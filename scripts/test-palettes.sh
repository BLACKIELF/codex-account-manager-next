#!/bin/sh
set -eu

cd "$(dirname "$0")/.."
exec ./scripts/run-self-tests.sh "$@" --only palettes
