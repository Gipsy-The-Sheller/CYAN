# Clustal Omega

Clustal Omega is a multiple sequence alignment program for proteins and
nucleic acids. It uses seeded guide trees and HMM profile-profile techniques
to align large numbers of sequences.

- Upstream: <https://github.com/GSLBiotech/clustal-omega>
- Version: 1.2.4 (commit `d21fab8`, 2018-01-02)
- License: GPL-2.0

## Package

```text
clustalo/
├─ clustalo(.exe)
├─ LICENSE                      (GPL-2.0)
├─ LICENSE-argtable2            (LGPL-2.0)
├─ README.md
├─ README-CYAN.txt
├─ VERSION
└─ example.fa
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/clustalo/clustalo(.exe)`, matching the path in
`YR_MPE/config.json`.

## argtable2 dependency

Clustal Omega requires argtable2. CYAN vendors argtable2 2.13 (commit
`f2e2391`, LGPL-2.0) under `argtable2/` and builds it as a static library.
Its 2012-era code needs three small portability fixes
(`patches/argtable2-portability.patch`):

- `EOVERFLOW` is an errno macro on modern systems; the internal enum is
  renamed to `EARGOVERFLOW`;
- the bundled `getopt.h`/`getopt.c` use old-style empty parameter lists,
  which conflict with the modern libc prototypes; they now use the standard
  `getopt(int, char *const *, const char *)` and `getenv(const char *)`
  declarations;
- `arg_int.c` includes `<ctype.h>` for `isspace`/`toupper`.

## Build notes

- Windows and Linux builds are static.
- OpenMP is enabled on Windows x64 and Linux. Windows arm64 and macOS build
  serial, so the packages do not depend on a non-system OpenMP runtime.
- The macOS build uses the system libc++/libSystem.
- `ENABLE_OPENMP` is passed to Clustal Omega's CMake; argtable2 is linked
  from the static library built in the same recipe.

## Smoke test

`smoke.sh` checks the reported version and aligns a five-taxon FASTA example,
requiring all five sequences in the output.
