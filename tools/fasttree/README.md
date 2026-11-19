# FastTree

FastTree infers approximately-maximum-likelihood phylogenetic trees from
nucleotide or protein alignments. Version 2.2 uses double precision by
default.

- Upstream: <https://github.com/morgannprice/fasttree>
- Commit: `a780aa4f6a18791ea76c04afaf37aafe43e51d59` (2026-10-07)
- Version: 2.2.0
- License: GPL-3.0

CYAN builds from the single upstream `FastTree.c`. The build omits
`-march=native` so binaries remain portable across CPUs of the same
architecture.

## Package

```text
FastTree/
├─ FastTree(.exe)       single-threaded, double precision
├─ FastTreeMP(.exe)     OpenMP build (Windows x64 and Linux)
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
├─ VERSION
└─ example.fa
```

Extracting into `YR_MPE/bin/` yields
`YR_MPE/bin/FastTree/FastTree(.exe)`, matching `YR_MPE/config.json`.

## Build notes

- Windows and Linux builds are static.
- FastTreeMP is built on Windows x64 and Linux. macOS and Windows arm64 get
  only the serial binary, avoiding a non-system libomp dependency.
- `-fopenmp-simd` is used on Windows/Linux to keep the upstream
  vectorisation hints active without `-march=native`.
- FastTreeMP is intentionally not byte-identical to FastTree; its thread
  interleaving can change heuristic search order.

## Smoke test

`smoke.sh` requires the version banner, runs a six-taxon nucleotide
alignment through FastTree, and validates the Newick output and all taxon
labels. When FastTreeMP is packaged it runs the same alignment with two
threads.
