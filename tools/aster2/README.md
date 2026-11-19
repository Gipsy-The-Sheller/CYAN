# ASTER2

ASTER2 is the next-generation C++20 implementation of the ASTER package for
large-scale phylogenomic reconstruction. It estimates species trees from gene
trees (`astral`) or directly from whole-genome alignments (`caster`).

- Upstream: <https://github.com/chaoszhang/ASTER2>
- Version: 2.6.1 (commit `002c13c`, 2026-11-18; pre-release/alpha)
- License: AGPL-3.0

ASTER2 is explicitly alpha software upstream: command-line options, log
output and result annotations may change between commits. It is not yet a
complete replacement for ASTER v1.25. YR-MPE currently bundles ASTER v1.24;
this package makes ASTER2 available for evaluation and migration.

## Package

```text
aster2/
├─ astral(.exe)                 # ASTRAL-IV / wASTRAL
├─ caster(.exe)                 # CASTER-site
├─ LICENSE                      (AGPL-3.0)
├─ README.md
├─ README-CYAN.txt
├─ VERSION
├─ tiny.trees                   # five-taxon gene-tree example
└─ tiny.phy                     # five-taxon alignment example
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/aster2/astral(.exe)` and `caster(.exe)`.

The experimental fasta2ref tools (`trial`, `wtrial`, `wcaster`), `sister` and
`astral-iad` are not packaged. The trial tools currently fail on Windows
because their temporary `fasta2ref` list is written with POSIX `/tmp` paths
that native Windows cannot reopen.

## Usage

```text
astral -i gene_trees.nw -o species_tree.nw -t 1 -u none -l none --no-log
caster -i alignment.phy -o species_tree.nw -t 1 -u none -l none --no-log
```

`astral` replaces ASTER's separate `astral4`, `wastral` and `astral-hybrid`
entry points; use `--mode` to select the weighting scheme. `caster`
implements CASTER-site. `-u none -l none` disables branch-support and
branch-length annotation; omit them for the default `sbb` support and `cu`
lengths.

The binary banner reports `v2.6.1` for astral and `v2.6.0` for caster because
upstream computes the version separately from each driver's changelog.

## Build notes

- Requires a C++20 compiler. The vendored commit is built with `-O2` and
  without `-march=native` so the binary runs on all CPUs of the target
  architecture.
- `patches/aster2-portability.patch` replaces the single `<format>` use with
  ordinary string replacement and a `std::views::reverse` pipeline with
  reverse iterators. This keeps ASTER2 buildable with GCC 11 on the Ubuntu
  22.04 CI images; no functionality changes.
- Windows and Linux binaries are static. macOS uses the system
  libc++/libSystem.
- No external libraries are required.

## Smoke test

`smoke.sh` runs `astral` on five gene trees and `caster` on a five-taxon
alignment, requiring all taxa in both output trees.
