# Treerecs

Treerecs reconciles gene trees with a species tree. It can correct,
rearrange, re-root and annotate gene trees, and reports duplication and loss
events.

- Upstream: <https://project.inria.fr/treerecs/>
- Git source: <https://github.com/Gipsy-The-Sheller/Treerecs-dev> branch `master`
- Version: 1.3 (commit `0c68102`, 2025-10-31)
- License: AGPL-3.0

The official project source is hosted on INRIA GitLab; CYAN vendors the
`Gipsy-The-Sheller/Treerecs-dev` tree because it contains the maintained
CMake infrastructure, the pll-modules/libpll submodule upgrade and the C++17
`std::random_shuffle` fix.

## Package

```text
treerecs/
├─ treerecs(.exe)
├─ LICENSE                      (AGPL-3.0)
├─ README.md
├─ README-CYAN.txt
├─ VERSION
├─ genetree.nwk
└─ speciestree.nwk
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/treerecs/treerecs(.exe)`, matching `YR_MPE/config.json`.

## Vendored dependencies

The source tree is self-contained:

- Bio++ (`bpp-core`, `bpp-seq`, `bpp-phyl`) and a Boost header subset under
  `src/ext/`;
- pll-modules commit `0a458f5` with libpll commit `9be0d0a` under
  `src/ext/pll/pll-modules`;
- simple-svg.

Bison and Flex are required at configure time for libpll.

## Patches

- `patches/treerecs-cmake.patch` makes the unit tests opt-in
  (`TREERECS_BUILD_TESTS`, default `OFF`). The GoogleTest submodule is not
  needed for the production binary.
- `patches/pll-modules-errno.patch` renames the `errno` parameter of
  `pllmod_set_error` to `errnum`. On MinGW, `errno` is a macro and the
  original declaration expands into invalid code.

## Build notes

- Windows and Linux builds are static.
- OpenMP is enabled on Windows x64 and Linux. Windows arm64 and macOS build
  serial, avoiding a non-system libomp dependency.
- The macOS build uses the system libc++/libSystem.
- The input file names passed to `-g`/`-s` must be simple basenames: Treerecs
  mirrors the gene-tree path below the output directory.
- Output is written as `<outdir>/<gene-tree-name>_recs.<format>`.

## Smoke test

`smoke.sh` reconciles the upstream fish gene tree with its species tree and
requires the Newick output with a reported total cost.
