# FastME

FastME is a distance-based phylogeny inference program (BIONJ, NJ, NNI, SPR,
minimum evolution). It is the distance-tree backend used by STAG and by
OrthoFinder's `-M dendroblast` mode.

- Upstream: <https://gite.lirmm.fr/atgc/FastME>
- Version: 2.1.6.3 (tag `v2.1.6.3`)
- License: GPL-3.0

## Package

```text
fastme/
├─ fastme(.exe)
├─ dist.txt         4-taxon PHYLIP distance example
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/fastme/fastme(.exe)`.

## Build notes

- Upstream autotools build; CYAN runs `./configure --disable-OpenMP`.
- OpenMP is intentionally off so the binary has no libomp/libgomp runtime
  dependency on macOS or Windows.
- Windows and Linux link statically.
- Upstream 2.1.6.4 exists only as a prebuilt binary in some bundles; the
  public source tag is 2.1.6.3, which is also the version bundled by
  OrthoFinder 3.2.

## Smoke test

`smoke.sh` checks the version, builds a tree from a four-taxon PHYLIP
distance matrix, and validates the Newick structure and all taxon labels.
