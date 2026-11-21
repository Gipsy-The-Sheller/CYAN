# HyPhy

HyPhy is a molecular-evolution analysis package (aBSREL, BUSTED, RELAX,
FEL, MEME, FUBAR, GARD, SLAC, etc.). The CYAN package includes the CLI and
the standard HyPhy batch library.

- Upstream: <https://github.com/veg/hyphy>
- Version: 2.5.103 (tag `2.5.103`, commit `1ac8cf4`, 2026-10-06)
- License: MIT

## Package

```text
hyphy/
├─ hyphy(.exe)
├─ hyphy-run             sets HYPHY_PATH to the packaged res/
├─ res/                  standard batch library
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

## Build notes

- CMake/Ninja build; BLAS, zlib, curl and MPI are disabled so the package
  has no optional runtime dependencies.
- Linux builds are static; macOS uses the system C/C++ runtime.
- HyPhy historically stores object handles in `long`, which is only valid
  on LP64. Native MinGW/LLP64 is therefore not supported. The Windows x64
  package is built with the MSYS POSIX toolchain and bundles `msys-2.0.dll`,
  `msys-gcc_s-seh-1.dll` and `msys-stdc++-6.dll`; WSL2 is also an option.
- `hyphy-run` (Unix) or `hyphy-run.bat` (Windows) sets `HYPHY_PATH` to the
  adjacent `res/` directory; calling the raw binary requires setting
  `HYPHY_PATH` yourself.
- Windows `res/` is repacked with the two trailing-dot filenames renamed,
  because ZIP cannot represent them; the model references are updated.

## Smoke test

`smoke.sh` checks the version/help output, verifies the aBSREL batch file
is present in `res/`, and exercises the `hyphy-run` wrapper.
