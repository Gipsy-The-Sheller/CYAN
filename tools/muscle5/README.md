# MUSCLE 5

MUSCLE 5 is a multiple sequence alignment program using the alpha/beta
posterior-based consistency algorithm. It supports protein, nucleotide and
codon alignments.

- Upstream: <https://github.com/rcedgar/muscle>
- Version: 5.3 (commit `29aa067`, 2026-08-29; post-`v5.3` HEAD)
- License: GPL-3.0

The vendored commit is after the `v5.3` tag and includes the upstream
mingw-w64 GCC and aarch64 fixes, which are required for the Windows and ARM
builds. The binary reports `muscle 5.3.<platform> [29aa067]`.

## Package

```text
muscle5/
├─ muscle(.exe)
├─ libomp.dylib                 (macOS only)
├─ LICENSE                      (GPL-3.0)
├─ README.md
├─ README-CYAN.txt
├─ VERSION
└─ example.fa
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/muscle5/muscle(.exe)`, matching the path in
`YR_MPE/config.json`.

## Build notes

- MUSCLE requires OpenMP. The source list is taken from the upstream Visual
  Studio project (`src/muscle.vcxproj`), but all platforms are compiled with
  GCC or Clang.
- Windows and Linux binaries are static, including the OpenMP runtime
  (libgomp on GCC, libomp on Clang/ARM).
- The macOS build uses Homebrew libomp and copies `libomp.dylib` into the
  package. Its install name is rewritten to `@loader_path/libomp.dylib`, so
  the package runs without Homebrew.
- `gitver.txt` is generated from the vendored upstream commit at build time.
- `-march=native` is deliberately not used, so the binaries run on all CPUs
  of the target architecture.

## Smoke test

`smoke.sh` checks the reported version and aligns a five-taxon FASTA
example, requiring five equal-length sequences.
