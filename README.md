# CYAN

**CYAN** is the cross-platform binary source for YRTools / YR-MPE. It keeps
the upstream source of each bundled analysis tool, one reproducible build
recipe per tool, and a GitHub Actions matrix that produces native packages for
every supported platform.

Build artifacts are published on the
[releases page](https://github.com/Gipsy-The-Sheller/CYAN/releases). The
repository itself contains source and build recipes, not compiled binaries.

## Targets

| Platform | Architecture | Toolchain |
| --- | --- | --- |
| Windows | x64 | MSYS2 `MINGW64` (GCC) |
| Windows | arm64 | MSYS2 `CLANGARM64` (Clang/LLD) |
| Linux | x64 | Ubuntu 22.04 (GCC) |
| Linux | arm64 | Ubuntu 22.04 arm64 (GCC) |
| macOS | arm64 | Apple Clang |

## Layout

```text
.
├─ .github/workflows/build.yml   # full-platform matrix + release job
├─ scripts/
│  ├─ common.sh                  # platform, architecture, toolchain, version
│  ├─ build_all.sh               # loops tools/*/build.sh
│  ├─ smoke_all.sh               # loops tools/*/smoke.sh
│  └─ package_tool.sh            # archive + SHA-256 + source manifest
└─ tools/
   ├─ lsd2/
   │  ├─ VERSION                 # tool version
   │  ├─ UPSTREAM                # upstream URL, commit, license
   │  ├─ build.sh                # compile and stage
   │  ├─ smoke.sh                # run a real example
   │  ├─ src/                    # vendored upstream source
   │  └─ examples/               # upstream example data
   └─ pbmpi/
      ├─ VERSION
      ├─ UPSTREAM
      ├─ PACKAGE_DIR             # archive root (pbmpi-1.9)
      ├─ SUPPORTED_PLATFORMS     # Windows arm64 intentionally absent
      ├─ build.sh
      ├─ smoke.sh
      ├─ bundle_mpi.sh          # relocatable OpenMPI runtime (Linux/macOS)
      ├─ sources/
      └─ pb_mpiManual1.9.pdf
```

## Build locally

On Windows use an MSYS2 **MINGW64** (x64) or **CLANGARM64** (arm64) shell; on
Linux/macOS use the system shell.

```bash
bash scripts/build_all.sh
bash scripts/smoke_all.sh
```

Build output goes to `build/`; packages go to `dist/`. Both directories are
ignored by git.

### Selective builds (debug)

When the repository contains many tools, build only what you are changing:

```bash
CYAN_TOOLS=lsd2 bash scripts/build_all.sh
CYAN_TOOLS=lsd2 bash scripts/smoke_all.sh
```

`CYAN_TOOLS` accepts comma- or space-separated names; an empty value builds
everything.

The same selection is available in GitHub Actions:
**Actions → build → Run workflow**. Set `tools` (for example `lsd2`) and
`platform` (or leave `all`). Push, pull-request and tag builds ignore these
inputs and build every tool on every platform.

## Packages

Each package is a single archive whose root is the tool name (or its
`PACKAGE_DIR` value), so extracting it into `YR_MPE/bin/` produces
`YR_MPE/bin/<tool>/<binary>` directly:

```text
lsd2-2.4.4-Windows-x64-v0.1.0.zip
└─ lsd2/
   ├─ lsd2.exe
   ├─ LICENSE
   ├─ README.md
   ├─ VERSION
   └─ SOURCE_MANIFEST.md
```

Windows packages are `.zip`; Linux and macOS packages are `.tar.gz`. Every
archive has a `.sha256` sidecar, and the release job also publishes a combined
`SHA256SUMS`.

The package name uses `<tool>-<version>-<Platform>-<arch>-<release>`, where
`<release>` is the git tag for tagged builds and `dev-<sha8>` otherwise.

## Adding a tool

1. Vendor the upstream source under `tools/<name>/` and keep its license.
2. Add `VERSION` and `UPSTREAM` (URL, commit, tag, license).
3. Optionally add `PACKAGE_DIR` (archive root directory; defaults to the tool
   name) and `SUPPORTED_PLATFORMS` (one `platform-arch` per line; missing means
   all targets).
4. Implement `build.sh`: compile into `build/<name>/`, stage the binary plus
   `LICENSE`, `README.md` and `VERSION` into `build/stage/<name>/`, then call
   `bash scripts/package_tool.sh <name> <stage-dir>`.
5. Implement `smoke.sh`: run the built binary against a small upstream example.
6. Commit. The workflow discovers `tools/*/build.sh` automatically; no matrix
   edit is needed.

A tool that does not list the current target in `SUPPORTED_PLATFORMS` is
skipped with a log message, so a single configuration can cover native-only
and cross-platform tools.

## Tools

| Tool | Version | Platforms | Upstream | License |
| --- | --- | --- | --- | --- |
| LSD2 | 2.4.4 | all five targets | [tothuhien/lsd2](https://github.com/tothuhien/lsd2) commit `c61110f` | GPL-2.0 |
| PhyloBayes-MPI | 1.9 | Windows x64, Linux x64/arm64, macOS arm64 | [bayesiancook/pbmpi](https://github.com/bayesiancook/pbmpi) tag `v1.9` | GPL-2.0 |
| MrBayes | 3.2.8 | Windows x64 | [NBISweden/MrBayes](https://github.com/NBISweden/MrBayes) tag `v3.2.8` | GPL-3.0 |

LSD2 is vendored unmodified from upstream commit
`c61110f3a4fa05325b45c97b2134792ff9d55d4c` (2024-10-25). Its `LICENSE` file is
GPL-2.0; individual source files carry the upstream GPL notice.

PhyloBayes-MPI is vendored unmodified from upstream tag `v1.9`
(`e7ec4d5f6c325a6bdade2a0c01d1e65ef58f8d20`). The Windows x64 build uses the
Microsoft MPI SDK and runtime; Linux and macOS builds use `mpicxx`. Windows
arm64 is not supported because Microsoft MPI has no ARM64 SDK.

MrBayes is vendored from tag `v3.2.8` (`1d9acf0…`) with BEAGLE 4.0.0
(`1d4b21d…`). Three patches are applied: enable BEAGLE on `WIN_VERSION`,
adapt BEAGLE's CMake/Windows loader for MinGW, and cap BEAGLE CPU threads to
the number of physical cores. The generic BEAGLE CPU plugin is built; the SSE
plugin is skipped because its Windows source has a duplicate `check_sse2`
definition under MinGW. `beaglethreadcount=99` (auto) is resolved to the
physical core count; explicit values above that are capped, and smaller
values are kept.

### MPI runtime

Each PhyloBayes-MPI package carries its own MPI launcher and runtime:

- **Windows x64** — `mpiexec.exe`, `mpirun.exe`, `msmpi.dll`, `smpd.exe`,
  `msmpilaunchsvc.exe`, the redistributable EULA and `MSMpiSetup.exe`.
  If Windows refuses the portable launcher, install `MSMpiSetup.exe` as
  administrator.
- **Linux / macOS** — the OpenMPI installation used at build time is copied
  under `mpi/`, together with shell wrappers `mpiexec` and `mpirun`. The
  `pb_mpi`, `readpb_mpi`, `tracecomp`, `bpcomp` and `cvrep` launchers set
  `OPAL_PREFIX`, `PRTE_PREFIX` and the library path for the bundled runtime;
  the real executables are the corresponding `.bin` files. On macOS the
  bundled dylibs are rewritten to `@rpath` and ad-hoc signed.

Each package includes an `MPI-RUNTIME.txt` describing the exact launcher and
fallback. If the bundled runtime cannot start on a particular machine, install
OpenMPI/MS-MPI and run the `.bin` executable with the system `mpiexec`.

## Licensing

Each tool keeps its upstream license, included in both `tools/<name>/` and the
packaged archive. CYAN only adds build scripts and packaging metadata.
