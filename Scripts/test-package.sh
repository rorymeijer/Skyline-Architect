#!/usr/bin/env bash
# Runs the SkylineKit package tests (macOS or Linux).
set -euo pipefail
cd "$(dirname "$0")/../Packages/SkylineKit"
swift build
swift test "$@"
