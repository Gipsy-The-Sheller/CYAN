# libdeflate

libdeflate is a fast DEFLATE/zlib/gzip implementation. CYAN packages the
static library and headers for downstream tools (FAMSA, fastp) and the
upstream `libdeflate-gzip` command-line utility.

- Upstream: <https://github.com/refresh-bio-dependencies/libdeflate>
- Version: 1.21 (commit `ced051e`)
- License: MIT

## Package

```text
libdeflate/
├─ include/libdeflate.h
├─ lib/libdeflate.a
├─ bin/libdeflate-gzip(.exe)
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

## Build notes

CMake static build; shared library and tests are disabled. Windows/Linux
link statically, macOS uses the system runtime. Downstream builds can use
`$CYAN_BUILD/stage/libdeflate` via `FAMSA`'s or fastp's include/library
flags.
