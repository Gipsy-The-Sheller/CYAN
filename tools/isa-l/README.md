# ISA-L

Intel ISA-L (Intelligent Storage Acceleration Library) provides optimized
CRC, compression, decompression and erasure-code routines. CYAN packages
the static library and headers used by FAMSA and fastp on x86-64.

- Upstream: <https://github.com/refresh-bio-dependencies/isa-l>
- Version: 2.30.0 (commit `7e39a2b`)
- License: BSD-3-Clause
- Platforms: Windows x64, Linux x64 (x86-64 assembly via NASM)

## Package

```text
isa-l/
├─ include/
├─ lib/libisal.a
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

## Build notes

`make -f Makefile.unx` builds the static library; NASM is required. ARM
targets do not build ISA-L and use zlib-ng instead.
