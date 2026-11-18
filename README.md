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
   └─ lsd2/
      ├─ VERSION                 # tool version
      ├─ UPSTREAM                # upstream URL, commit, license
      ├─ build.sh                # compile and stage
      ├─ smoke.sh                # run a real example
      ├─ src/                    # vendored upstream source
      └─ examples/               # upstream example data
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

Each package is a single archive whose root is the tool name, so extracting it
into `YR_MPE/bin/` produces `YR_MPE/bin/<tool>/<binary>` directly:

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
2. Add `VERSION` and `UPSTREAM` (URL, commit, license).
3. Implement `build.sh`: compile into `build/<name>/`, stage the binary plus
   `LICENSE`, `README.md` and `VERSION` into `build/stage/<name>/`, then call
   `bash scripts/package_tool.sh <name> <stage-dir>`.
4. Implement `smoke.sh`: run the built binary against a small upstream example.
5. Commit. The workflow discovers `tools/*/build.sh` automatically; no matrix
   edit is needed.

## Tools

| Tool | Version | Upstream | License |
| --- | --- | --- | --- |
| LSD2 | 2.4.4 | [tothuhien/lsd2](https://github.com/tothuhien/lsd2) commit `c61110f` | GPL-2.0 |

LSD2 is vendored unmodified from upstream commit
`c61110f3a4fa05325b45c97b2134792ff9d55d4c` (2024-10-25). Its `LICENSE` file is
GPL-2.0; individual source files carry the upstream GPL notice.

## Licensing

Each tool keeps its upstream license, included in both `tools/<name>/` and the
packaged archive. CYAN only adds build scripts and packaging metadata.
