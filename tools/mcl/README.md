# MCL

MCL is Stijn van Dongen's Markov Cluster algorithm. OrthoFinder uses it to
cluster the sequence-similarity graph into orthogroups.

- Upstream: <https://micans.org/mcl/>
- GitHub mirror: <https://github.com/micans/mcl>
- Version: 22-282
- License: GPL-3.0-or-later (MCL and cimfomfa/libtingea)

## Package

```text
mcl/
├─ mcl(.exe)
├─ example.abc       two-cluster ABC graph
├─ LICENSE-MCL
├─ LICENSE-CIMFOMFA
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/mcl/mcl(.exe)`.

## Vendored dependency

MCL needs `libtingea` from cimfomfa. The cimfomfa 21-361 GitHub tag ships
without a generated `configure`, so CYAN builds the 17-file `tingea`
library directly and installs a temporary header/library prefix before
running MCL's configure.

## Build notes

- Only `mcl` is built. The optional `mcx*` utilities, `shcl`/`clm` and RCL
  scripts are not needed by OrthoFinder or YR-MPE.
- MinGW needs `patches/mcl-mingw.patch`:
  - `SIGALRM` is absent on Windows; the signal handler is made portable.
  - `srandom`/`random`/`SIGUSR1` are POSIX-only; `mcl.c` uses `srand` and
    guards the `SIGUSR1` log handler on Windows.
  - cimfomfa's `rand.c` uses `getppid`, which MinGW lacks; Windows uses
    `getpid`.
- cimfomfa is compiled with `-D__CRT__NO_INLINE` and a small forced header
  that exposes `_read`/`_write` and a fixed 4096-byte page size on Windows.
- Windows and Linux builds are static; macOS uses the system C runtime.

## Smoke test

`smoke.sh` runs MCL on a six-node, two-component ABC graph and requires two
clusters containing all six nodes.
