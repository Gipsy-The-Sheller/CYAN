# DIAMOND

DIAMOND is a BLAST-compatible protein and translated-DNA sequence aligner.
OrthoFinder 3 uses DIAMOND as its default sequence-search program; CYAN also
packages it as the preferred replacement for BLAST+ in YR-MPE workflows.

- Upstream: <https://github.com/bbuchfink/diamond>
- Version: 2.2.9 (tag `v2.2.9`, commit `59dab9c`, 2026-11-14)
- License: GPL-3.0-or-later

## Package

```text
diamond/
├─ diamond(.exe)
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
├─ VERSION
└─ example.fa
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/diamond/diamond(.exe)`.

## Build notes

- CMake build; zlib and SQLite3 are the only external libraries.
- Windows and Linux builds are static (`BUILD_STATIC=ON`).
- The upstream CPU dispatcher keeps generic, SSE4.1 and AVX2 kernels on x86,
  and NEON on ARM64. CYAN does not use `-march=native`.
- `patches/diamond-mingw.patch` adds native MinGW support:
  - use `fread`/`fgetc`/`getdelim_generic` on Windows instead of the
    POSIX `*_unlocked`/`getdelim` calls;
  - use the inline-assembly CPUID path on MinGW rather than MSVC's
    `__cpuidex`/`_xgetbv` intrinsics;
  - replace `__builtin_expect((long)x, 0)` with a boolean form, which avoids
    the LLP64 pointer-to-`long` truncation on Windows;
  - include `<cstdint>` where newer GCC requires it;
  - use Win32 `GetModuleFileNameA`/`GetFileAttributes` for `_WIN32`, not
    only `_MSC_VER`;
  - avoid `posix_fadvise`/`mmap` in the hit buffer on Windows and fall back
    to `new[]`, and link the MinGW `synchronization` import library for
    `WaitOnAddress`/`WakeByAddressSingle`.
- CI installs zlib and SQLite3 development packages for the Windows and
  Linux jobs.

## Smoke test

`smoke.sh` runs `diamond makedb` on four short proteins, then
`diamond blastp --compress 1`, validates the gzip tabular output and checks
that the `alpha` query has at least one hit.
