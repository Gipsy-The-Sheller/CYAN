# FAMSA

FAMSA (Fast and Accurate Multiple Sequence Alignment) is a progressive
multiple-sequence aligner. CYAN ships it as a standalone package so
OrthoFinder 3 and YR-MPE can share one binary; the OrthoFinder package adds
FAMSA as an optional `-A famsa` MSA method.

- Upstream: <https://github.com/refresh-bio/FAMSA>
- Version: 2.5.2
- License: GPL-3.0

## Package

```text
famsa/
├─ famsa(.exe)
├─ example.fa
├─ libgcc_s_seh-1.dll       Windows only
├─ libstdc++-6.dll          Windows only
├─ libwinpthread-1.dll      Windows only
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/famsa/famsa(.exe)`.

## Build notes

- FAMSA bundles `zlib-ng` and `mimalloc`. CYAN also needs `libdeflate` and,
  on x86-64, ISA-L. Those two are built as CYAN packages first and copied
  into FAMSA's expected `libs/` layout, so one library build serves FAMSA and
  future tools such as fastp.
- `patches/famsa-mingw.patch` makes Windows/MinGW work:
  - MSYS `uname` is normalized to `Windows`, enabling a real
    `GCC_Windows_x86_64` compiler rule instead of bypassing the check.
  - `-dumpversion` replaces parsing `g++ --version` (MinGW appends `Rev8`,
    which FAMSA misread as GCC 8).
  - zlib-ng builds its `zlibstatic` target only.
  - Windows gets `-include cstdint -DWIN32`, and the stopwatch uses
    `std::chrono` instead of `gettimeofday`.
  - Vendored sources skip `git submodule update`.
  - A prebuilt ISA-L archive is preferred over probing for NASM.
- Windows links dynamically; the three MinGW runtime DLLs are packaged.
  `STATIC_LINK=true` is not used because it duplicates `-lpthread` inside
  `--whole-archive`.
- Linux links statically. macOS is not built: FAMSA's makefile expects GCC,
  and the AppleClang toolchain is not supported upstream.

## Smoke test

`smoke.sh` aligns a six-sequence FASTA file, then checks that all six records
are present and aligned to the same length.
