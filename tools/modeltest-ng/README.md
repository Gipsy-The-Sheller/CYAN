# ModelTest-NG

ModelTest-NG selects nucleotide or protein substitution models under BIC,
AIC, AICc and decision theory. CYAN vendors upstream `v0.1.7` together with
its `pll-modules` and `libpll` submodules and builds a self-contained command
line binary.

## Package

```text
modeltest-ng/
├─ bin/modeltest-ng(.exe)
├─ LICENSE                      (ModelTest-NG, GPL-3.0)
├─ libpll-AGPL-3.0.txt
├─ pll-modules-GPL-3.0.txt
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

The archive extracts directly into `YR_MPE/bin/`, matching the path in
`YR_MPE/config.json`.

## Portability patches

Upstream has no native Windows build. CYAN applies three patches at build
time:

1. `patches/modeltest-ng-portability.patch` — removes the hard-coded i686
   MinGW cross compiler, builds in release mode, adds `-D_GNU_SOURCE`,
   fixes the `uint64_t` include, reports Windows memory through
   `GlobalMemoryStatusEx`, and guards the x86 CPUID core count so ARM64
   builds work. The macOS deployment-target flag is dropped because current
   Xcode toolchains reject 10.7.
2. `patches/pll-modules-portability.patch` — renames the `errno` function
   parameter that collides with the MinGW macro, replaces `hcreate`/
   `hsearch` with a portable duplicate scan, and frees `pll_aligned_alloc`
   buffers with `pll_aligned_free` (required on Windows).
3. `patches/libpll-portability.patch` — removes obsolete parser
   declarations rejected by modern Bison, fixes the aligned-free mismatch
   for repeat buffers and tip-character arrays, disables the Apple x86 CPUID
   assembly path on ARM64, and replaces `RAND_MAX` in the Fisher-Yates
   shuffle. `RAND_MAX` is only 32767 on Windows while `pll_random_r`
   returns 31-bit values, which made the shuffle index leave the array and
   crash the starting-tree search.

ModelTest's own compile-time SIMD is disabled. libpll still selects SSE,
AVX or AVX2 kernels at runtime, so one package works on every supported CPU.

## Smoke test

`smoke.sh` runs the full 88-model nucleotide selection on the upstream
`tiny.fas` example and requires a completed result file and selected models.
