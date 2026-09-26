# Development Status

_Last updated: 2026-09-26_

## Current phase
**Phase 0 — Project bootstrap** (in progress)

## Current milestone
M1 “First Playable” (end of Phase 9) — not started.

## Completed
- Repository inspected (empty apart from README).
- Documentation set, CLAUDE.md, decision log, roadmap.
- `SkylineKit` package skeleton (Core/Content/Presentation/Snapshot) — builds & tests on Linux.
- Xcode project (multiplatform app target, synchronized `App/` folder, shared scheme).
- CI workflow (Linux package tests, macOS build/test, iPad simulator build, screenshot capture hook).

## In progress
- First CI validation of the hand-written Xcode project.

## Known bugs
- None known.

## Technical debt
- None yet.

## Next tasks
- Phase 1 (see ROADMAP.md).

## Environment
- Cloud sessions run in a Linux container without Xcode. To build/test the package there,
  install Swift from the official Docker image layers (download.swift.org is blocked):
  pull `library/swift:6.1-noble` layers via the registry API, extract the toolchain
  layer into `/opt/swift`, apt-install its runtime deps (libcurl4-openssl-dev,
  libxml2-dev, libedit2, libz3-dev, libpython3-dev, libstdc++-13-dev, …) and use
  `PATH=/opt/swift/usr/bin:$PATH`.
- The app target is verified only by macOS CI (`.github/workflows/ci.yml`) or locally.
