# MPBoot

MPBoot performs fast maximum-parsimony tree search and bootstrap
approximation. CYAN vendors the maintained upstream branch head (which is
post-`v1.2`, but still reports version 1.1.1) and builds an AVX binary.

## Package

```text
mpboot/
├─ mpboot(.exe)
├─ LICENSE                      (GPL-2.0)
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/mpboot/mpboot(.exe)`, matching the path in
`YR_MPE/config.json`.

## Build notes

- The build uses `-DIQTREE_FLAGS=avx`; the binary requires an x86-64 CPU
  with AVX.
- `patches/mpboot-mingw.patch` fixes the vendored libpll's old hardware
  probe for MinGW: GCC has no `__cpuid`, the helper was called through a
  pointer-to-pointer, and Windows has no `/sys/devices/system/cpu` tree.
  It reports the logical processor count through `GetSystemInfo` instead.
- The same patch changes `optimizeModel.c` to release the aligned
  `pllBaseFrequenciesInstance` arrays with `rax_free`; on Windows `rax_malloc`
  is `_aligned_malloc`, so plain `free` corrupts the heap.

Only x86-64 Windows and Linux are supported. The vendored IQ-TREE 1.x code
uses x86 CPUID and AVX vector classes, so Windows/macOS ARM64 builds are not
offered.

## Smoke test

`smoke.sh` runs 10 parsimony iterations on a six-taxon FASTA example and
requires a Newick tree file and a reported best score.
