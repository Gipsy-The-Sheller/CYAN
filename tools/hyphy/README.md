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
  on LP64. Native Windows x64 (LLP64) is therefore not packaged; Windows
  users should run the Linux build under WSL2.
- `hyphy-run` sets `HYPHY_PATH` to the adjacent `res/` directory; calling
  the raw binary requires setting `HYPHY_PATH` yourself.

## Smoke test

`smoke.sh` checks the version/help output, verifies the aBSREL batch file
is present in `res/`, and exercises the `hyphy-run` wrapper.
