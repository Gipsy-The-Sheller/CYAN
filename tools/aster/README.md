# ASTER (v1)

ASTER v1 is the predecessor of ASTER2. It contains ASTRAL-IV, ASTRAL-Pro3,
wASTRAL, CASTER and distance-based utilities. YR-MPE's existing `aster/`
configuration uses this v1 layout; ASTER2 is packaged separately as
`aster2/` for evaluation and migration.

- Upstream: <https://github.com/chaoszhang/ASTER>
- Version: v1.25 (tag `v1.25`, commit `db2b3e9`, 2026-04-20)
- License: AGPL-3.0

## Package

```text
aster/
├─ astral4(.exe) / astral(.exe)
├─ astral-pro3(.exe) / astral-pro(.exe)
├─ wastral(.exe) / astral-hybrid(.exe)
├─ caster-site(.exe)
├─ caster-pair(.exe)
├─ waster(.exe)
├─ dstar(.exe)
├─ dstar-branch(.exe)
├─ sister(.exe)
├─ tiny.trees
├─ tiny.map
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/aster/`, matching the old
YR-MPE ASTER directory and config path.

## Build notes

- Upstream single-file C++ targets; CYAN compiles each with
  `-std=c++17 -O2 -pthread`, omitting upstream's `-march=native`.
- Windows and Linux builds statically link libgcc/libstdc++.
- ASTER v1.25 uses `std::uniform_int_distribution<unsigned __int128>` for
  taxon hashes, which GCC 15/libstdc++ rejects. The patch uses two
  `uint64_t` draws to build the 128-bit hash.
- ASTER v1 v1.25 supports x86-64 and ARM64 Linux/macOS in this package;
  Windows arm64 is not enabled until validated.

## Smoke test

`smoke.sh` runs both ASTRAL-Pro3 and ASTRAL-IV on four five-taxon gene
trees and validates the resulting species trees.
