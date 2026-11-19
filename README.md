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
   ├─ pbmpi/
   │  ├─ VERSION
   │  ├─ UPSTREAM
   │  ├─ PACKAGE_DIR             # archive root (pbmpi-1.9)
   │  ├─ SUPPORTED_PLATFORMS     # Windows arm64 intentionally absent
   │  ├─ build.sh
   │  ├─ smoke.sh
   │  ├─ bundle_mpi.sh          # relocatable OpenMPI runtime (Linux/macOS)
   │  ├─ sources/
   │  └─ pb_mpiManual1.9.pdf
   └─ iqtree3/
      ├─ VERSION
      ├─ UPSTREAM                # main + cmaple/lsd2 submodule commits
      ├─ SUPPORTED_PLATFORMS     # Windows arm64 intentionally absent
      ├─ build.sh
      ├─ smoke.sh
      └─ src/                   # IQ-TREE 3.1.4 + cmaple + lsd2
```

## Build locally

On Windows use an MSYS2 **MINGW64** (x64) or **CLANGARM64** (arm64) shell; on
Linux/macOS use the system shell.

```bash
bash scripts/build_all.sh
bash scripts/smoke_all.sh
```

Build output goes to `build/`; packages go to `dist/`. Both directories are
ignored by git. On Windows, IQ-TREE must be built from an MSYS2 **CLANG64**
shell; a tool can declare this with `REQUIRES_MSYSTEM`.

ModelTest-NG and RAxML-NG additionally need Bison and Flex at configure time
(MSYS2 `bison`/`flex`, Debian/Ubuntu `bison`/`flex`, or Homebrew).
```bash
CYAN_TOOLS=iqtree3 bash scripts/build_all.sh
```

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
| MrBayes | 3.2.8 | Windows x64, Linux x64/arm64, macOS arm64 | [NBISweden/MrBayes](https://github.com/NBISweden/MrBayes) tag `v3.2.8` | GPL-3.0 |
| IQ-TREE | 3.1.4 | Windows x64, Linux x64/arm64, macOS arm64 | [iqtree/iqtree3](https://github.com/iqtree/iqtree3) tag `v3.1.4` | GPL-2.0 |
| TrimAl | 1.5.1 | Windows x64, Linux x64/arm64, macOS arm64 | [inab/trimal](https://github.com/inab/trimal) tag `v1.5.1` | GPL-3.0 |
| ModelTest-NG | 0.1.7 | Windows x64, Linux x64/arm64, macOS arm64 | [ddarriba/modeltest](https://github.com/ddarriba/modeltest) tag `v0.1.7` | GPL-3.0 (libpll AGPL-3.0) |
| RAxML-NG | 1.2.2 | Windows x64, Linux x64/arm64, macOS arm64 | [amkozlov/raxml-ng](https://github.com/amkozlov/raxml-ng) tag `1.2.2` | AGPL-3.0 |
| MPBoot | 1.1.1 | Windows x64, Linux x64 | [diepthihoang/mpboot](https://github.com/diepthihoang/mpboot) commit `2864869` | GPL-2.0 |
| DecentTree | 1.0.0 | all five targets | [iqtree/decenttree](https://github.com/iqtree/decenttree) commit `c106c86` | GPL-2.0 |
| YGBlocks | 1.0.0 | Windows x64, Linux x64/arm64, macOS arm64 | local MIT implementation | MIT |

LSD2 is vendored unmodified from upstream commit
`c61110f3a4fa05325b45c97b2134792ff9d55d4c` (2024-10-25). Its `LICENSE` file is
GPL-2.0; individual source files carry the upstream GPL notice.

PhyloBayes-MPI is vendored unmodified from upstream tag `v1.9`
(`e7ec4d5f6c325a6bdade2a0c01d1e65ef58f8d20`). The Windows x64 build uses the
Microsoft MPI SDK and runtime; Linux and macOS builds use `mpicxx`. Windows
arm64 is not supported because Microsoft MPI has no ARM64 SDK.

MrBayes is vendored from tag `v3.2.8` (`1d9acf0…`) with BEAGLE 4.0.0
(`1d4b21d…`). Patches enable BEAGLE on `WIN_VERSION`, adapt BEAGLE's
CMake/Windows loader for MinGW, fix the duplicate `check_sse2` definition,
and cap BEAGLE CPU threads to the number of physical cores.
`beaglethreadcount=99` (auto) is resolved to the physical core count;
explicit values above that are capped, and smaller values are kept.

The Windows build combines BEAGLE with MS-MPI: a small `mpicc` wrapper feeds
`mpi.h` and `msmpi.lib` to MrBayes' `--with-mpi` configure step. The package
bundles `mpiexec.exe`, `msmpi.dll`, `smpd.exe`, `msmpilaunchsvc.exe` and the
MS-MPI installer, so multi-instance runs use `mpiexec -n N mb.exe input.nex`
with BEAGLE threading per instance.

On Linux x64/arm64 and macOS arm64 the same BEAGLE CPU/SSE build is linked
with OpenMPI. The package bundles OpenMPI and the BEAGLE runtime; `mb` is a
wrapper that sets the BEAGLE/MPI paths and runs `mb.bin`:
`./mpiexec -n 4 ./mb input.nex`. The BEAGLE SSE plugin maps SSE2 intrinsics to
NEON on ARM64, and the CPU thread cap uses `sysconf`/`hw.physicalcpu` on Unix.

### ModelTest-NG and RAxML-NG on Windows

Both programs depend on libpll and pll-modules, which upstream has not
validated with native MinGW. CYAN configures them with CMake and applies
three patches under `tools/<name>/patches/`:

- the program-specific patch removes hard-coded cross compilers and adds a
  Windows system layer (`GlobalMemoryStatusEx`, `GetProcessTimes`, CPU
  count, `realpath`; ModelTest also needs an x86 CPUID guard for ARM64);
- `pll-modules` aligned allocations (`deriv_precomp`, branch-optimizer
  `precomp_buffers`, binary buffers) must be released with
  `pll_aligned_free`, not `free`, on Windows;
- libpll's Fisher-Yates starting-tree shuffle divides a 31-bit random value
  by `RAND_MAX`. On Windows `RAND_MAX` is 32767, so the shuffle index left
  the array and crashed parsimony tree construction. The patch uses the
  31-bit divisor.

The Windows builds of both tools are self-contained (`msvcrt.dll` only).
ModelTest's and RAxML-NG's compile-time SIMD is disabled, while libpll
keeps runtime SSE/AVX dispatch. On Linux and macOS the same sources build
without the MinGW layer; the libpll/pll-modules fixes apply everywhere.

Bison and Flex are needed at configure time; the CI jobs install them.

### MPBoot

MPBoot is an IQ-TREE 1.x-derived maximum-parsimony/bootstrapping program
with its own vendored libpll. CYAN builds the maintained upstream branch
head with `-DIQTREE_FLAGS=avx`; the binary reports version 1.1.1 although
the upstream release tag is `v1.2`. The vendored libpll needs two fixes:

- its hardware probe used MSVC's `__cpuid` on MinGW and called helpers with
  a pointer-to-pointer; the patch uses GCC inline assembly and
  `GetSystemInfo` for the Windows core count;
- `pllBaseFrequenciesInstance` allocates with `rax_malloc`, which is
  `_aligned_malloc` on Windows, so `optimizeModel.c` must release those
  arrays with `rax_free` rather than `free`.

Only x86-64 Windows and Linux are built. The IQ-TREE 1.x code uses x86
CPUID and AVX vector classes, so no ARM64 package is offered.

### DecentTree

DecentTree is the distance-matrix tree builder from the IQ-TREE project. It
reads `.mldist` matrices and writes Newick trees. YR-MPE invokes it with
`-in`, `-out`, `-t` and `-no-banner`; the algorithms it exposes are
`BIONJ-R`, `BIONJ-V`, `NJ-R-D`, `ONJ-R`, `ONJ-R-V` and `AUCTION`.

CYAN vendors upstream commit `c106c86a` (post-`v1.0.0`, README-only changes)
and applies `patches/decenttree-portability.patch`:

- the `Builder` constructors left `isRooted` uninitialised. Depending on the
  stack contents this crashed `BIONJ`, `NJ-R`, `BIONJ-R`, `BIONJ-V`,
  `NJ-R-D` and `AUCTION`, or made `ONJ-R` emit rooted trees by accident. It
  is now `false`, so output is unrooted (degree-3 root), as is standard for
  distance-based construction;
- the `AUCTION` second-best search never advanced past the best distance and
  reported the wrong row pair, which could drop a taxon from the tree. The
  bid and pair are now computed from the actual best and second-best
  partners;
- `<cstdint>` and `__builtin_popcountll` replace platform-specific
  assumptions, and the x86-only vectorclass library is disabled on ARM. The
  `-V` names are aliased to the scalar implementations there, so the YR-MPE
  command line is identical on every target.

Windows and Linux packages are static. The package root is `decenttree/`,
so extracting into `YR_MPE/bin/` yields
`YR_MPE/bin/decenttree/decenttree(.exe)`.

### YGBlocks

YGBlocks is an independent MIT-licensed reimplementation of GBlocks 0.91b,
written for YR-MPE. It reads FASTA and PHYLIP (interleaved or one-line
sequential) and produces the selected alignment plus a masked report. The
selected-alignment FASTA is byte-compatible with the original GBlocks binary
for nucleotide, codon and protein data; protein similarity uses the Gonnet 120
matrix.

The package root is `Gblocks/` and the binary is `Gblocks(.exe)`, so it
extracts directly over `YR_MPE/bin/Gblocks/`. The `-p=t` report is an
interleaved PHYLIP-style alignment of the original data: kept positions are
uppercase, removed positions lowercase, and `-` gaps become `.`.

### TrimAl

TrimAl 1.5.1 is a small C++ program built with its upstream makefiles. On
Windows the build passes the Windows `TMP`/`TEMP`/`TMPDIR` paths as make
variables because MSYS2 `make` strips them, which otherwise makes GCC fall
back to the unwritable `C:\WINDOWS` directory.

### IQ-TREE and AVX on Windows

IQ-TREE is vendored from tag `v3.1.4` (`63c330d…`) together with its
`cmaple` and `lsd2` submodules. The Windows build deliberately uses MSYS2
**CLANG64**, not the MINGW64/GCC job. IQ-TREE's CMake appends `novx` to
`IQTREE_FLAGS` for GCC on Windows (its comment cites GCC memory-alignment
problems); `novx` caps the runtime at SSE4.2 and drops the AVX/FMA kernels.
Clang does not take that branch, which matches the official Windows binaries.
The CLANG64 job is selected by `tools/iqtree3/REQUIRES_MSYSTEM`, so the
MINGW64 job skips IQ-TREE. On x86_64 the smoke test requires the `Kernel:`
line to contain `AVX`; a GCC build would fail it with `Kernel: SSE2`.

CMAPLE is disabled on Windows by upstream; it is built on Linux and macOS.
MUTSEL is disabled on every platform, so the build has no Rust dependency.
The 3.1.4 bump also picks up the iq2mc Hessian-orientation fix. Windows arm64
is intentionally absent: upstream ships no Windows ARM64 build and the
ClangARM64 combination has not been validated.

### BEAGLE CPU first

CYAN builds the generic BEAGLE CPU plugin and the SSE plugin only; CUDA,
OpenCL and JNI are disabled. On x86_64 the SSE plugin is compiled with
`-msse4.2`. On ARM64 the same SSE2 intrinsics map to NEON through BEAGLE's
`sse2neon.h` (the ARM guards are extended to `__aarch64__`). GPU plugins are
intentionally omitted: for laptop-sized datasets the CPU plugins are faster,
and they avoid a large CUDA/OpenCL runtime dependency.

### MPI runtime

PhyloBayes-MPI and MrBayes packages carry their own MPI launcher and runtime:

- **Windows x64** — `mpiexec.exe`, `mpirun.exe`, `msmpi.dll`, `smpd.exe`,
  `msmpilaunchsvc.exe`, the redistributable EULA and `MSMpiSetup.exe`.
  If Windows refuses the portable launcher, install `MSMpiSetup.exe` as
  administrator.
- **Linux / macOS** — the OpenMPI installation used at build time is copied
  under `mpi/`, together with shell wrappers `mpiexec` and `mpirun`. The
  `pb_mpi`, `readpb_mpi`, `tracecomp`, `bpcomp` and `cvrep` launchers, and
  MrBayes' `mb` wrapper, set `OPAL_PREFIX`, `PRTE_PREFIX` and the library
  path for the bundled runtime; the real executables are the corresponding
  `.bin` files. MrBayes' wrapper also sets `BEAGLE_LIBRARY_PATH` for the
  bundled plugins. On macOS the bundled dylibs are rewritten to `@rpath` and
  ad-hoc signed.

PhyloBayes-MPI includes an `MPI-RUNTIME.txt` describing the exact launcher
and fallback. If the bundled runtime cannot start on a particular machine,
install OpenMPI/MS-MPI and run the `.bin` executable with the system
`mpiexec`.

## Licensing

Each tool keeps its upstream license, included in both `tools/<name>/` and the
packaged archive. ModelTest-NG and RAxML-NG additionally ship the licenses of
their bundled `pll-modules`, `libpll` and (for RAxML-NG) `terraphast`
libraries. CYAN only adds build scripts and packaging metadata.
