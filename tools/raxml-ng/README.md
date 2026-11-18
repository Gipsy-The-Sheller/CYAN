# RAxML-NG

RAxML-NG is a maximum-likelihood tree search and bootstrapping program.
CYAN vendors upstream `1.2.2` together with `pll-modules`, `libpll` and
`terraphast`, and builds a self-contained command line binary.

## Package

```text
raxml-ng/
├─ bin/raxml-ng(.exe)
├─ LICENSE                      (RAxML-NG, AGPL-3.0)
├─ libpll-AGPL-3.0.txt
├─ pll-modules-GPL-3.0.txt
├─ terraphast-GPL-3.0.txt
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

The archive extracts directly into `YR_MPE/bin/`, matching the path in
`YR_MPE/config.json`.

## Portability patches

Upstream documents Windows support through WSL only. CYAN applies:

1. `patches/raxml-ng-mingw.patch` — adds a native MinGW implementation of
   CPU time, memory, CPU count, CPUID and `realpath`, enables
   `-D_GNU_SOURCE` for `asprintf`, and widens the memory query to 64 bits on
   Windows.
2. `patches/pll-modules-portability.patch` — frees `pll_aligned_alloc`
   buffers with `pll_aligned_free` (required on Windows) and renames the
   `errno` parameter that collides with the MinGW macro.
3. `patches/libpll-portability.patch` — removes obsolete parser
   declarations rejected by modern Bison, fixes the aligned-free mismatch
   for repeat buffers and tip-character arrays, and replaces `RAND_MAX` in
   the Fisher-Yates shuffle. On Windows `RAND_MAX` is 32767 while
   `pll_random_r` returns 31-bit values, so the shuffle index left the
   array and crashed the parsimony starting-tree search.

RAxML-NG's own compile-time SIMD is disabled. libpll still selects SSE,
AVX or AVX2 kernels at runtime, so one package works on every supported CPU.

## Smoke test

`smoke.sh` runs an all-in-one ML search with 10 bootstrap replicates on the
bundled six-taxon example and requires a best tree, bootstrap support
values, a final likelihood and a complete run log. The bootstrap path also
exercises the `ParsimonyMSA` teardown that exposed a `malloc`/
`_aligned_free` mismatch.
