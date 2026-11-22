# OrthoFinder 3

OrthoFinder is phylogenetic orthology inference for comparative genomics.
CYAN packages version 3.0.1b1 as a self-contained PyInstaller one-folder
application with its native search, clustering, alignment and tree tools.

- Upstream: <https://github.com/davidemms/OrthoFinder>
- Version: 3.0.1b1 (commit `43f9bc7`)
- License: LGPL-3.0; bundled MAFFT is BSD-3-Clause
- Platforms: Windows x64, Linux x64

## Package

```text
orthofinder/
├─ orthofinder(.exe)
├─ _internal/                 Python 3.12, numpy, scipy, scikit-learn, biopython
├─ bin/
│  ├─ diamond(.exe)
│  ├─ mcl(.exe)
│  ├─ FastTree(.exe)
│  ├─ fastme(.exe)
│  ├─ astral-pro(.exe)
│  ├─ famsa(.exe)             plus MinGW DLLs on Windows
│  └─ MAFFT                   mafft.bat + usr/ (Windows), mafft/ (Linux)
├─ config.json
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields
`YR_MPE/bin/orthofinder/orthofinder(.exe)`, matching YR-MPE's configured
`bin/orthofinder/orthofinder.exe` path.

## Why PyInstaller instead of a venv

A venv contains absolute paths and cannot be relocated after extraction.
PyInstaller freezes the interpreter and packages into `_internal/`, with a
small launcher at the package root. OrthoFinder reads `config.json` and
`bin/` relative to `sys.executable`, which is exactly this layout.

## Patches

`patches/orthofinder3-windows.patch` covers:

- `multiprocessing.freeze_support()` at the entry point and deferred creation
  of the parallel task manager, preventing recursive process spawning in a
  frozen Windows build.
- `os.pathsep` instead of a literal `:` when prepending `bin/` to PATH.
- Safe decoding of non-UTF-8 external-tool output.
- A `-oa` bug that unpacked `(i,)` from a list of integers.
- A `famsa` MSA entry in `config.json` (`-A famsa`), wired to the bundled
  binary.

## Build notes

- Dependencies are built first through `DEPENDS`: DIAMOND, MCL, FastTree,
  FastME, ASTER v1 (ASTRAL-Pro), FAMSA and MAFFT. `scripts/build_all.sh`
  orders them topologically.
- Windows uses CYAN's MAFFT package. Linux x64 extracts OrthoFinder's own
  MAFFT runtime from `vendor/mafft-linux-x64.tar.gz` into `bin/mafft/`, where
  OrthoFinder's packaged-MAFFT fallback expects it.
- macOS and Linux arm64 are not built yet because no portable MAFFT runtime
  is bundled for them.

## Smoke test

`smoke.sh` runs `-og` (DIAMOND + MCL + the frozen Python stack), then
`-M msa -A famsa -oa` to exercise the bundled FAMSA and the alignment path.
