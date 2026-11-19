# IcyTree

IcyTree is a client-side JavaScript phylogenetic tree and network viewer. It
runs entirely in the browser; there is no server or native executable.

- Upstream: <https://github.com/tgvaughan/icytree>
- Hosted version: <https://icytree.org>
- Commit: `48ed43e9299ca8037d5b9efe41c69386c2b67057` (2025-05-19)
- License: GPL-3.0 (bundled libraries are MIT; their notices are under
  `src/js/libs/` and `src/jquery-ui/`)

CYAN vendors the complete static site, not a source checkout: `index.html`,
`css/`, `js/` (including the bundled Plotly, jQuery, jQuery UI, PapaParse and
FileSaver), `jquery-ui/`, `images/`, `manual/` and `examples/`.

## Package

```text
icytree/
├─ index.html
├─ css/
├─ js/
├─ jquery-ui/
├─ images/
├─ manual/
├─ examples/
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

The package is platform-neutral. CYAN builds it only in the `windows-x64`
job so the release matrix does not publish five identical copies; the same
archive works on Linux and macOS.

For YR-MPE, the expected location is `YR_MPE/src/icytree/` (see
`YR_MPE/icytree.py`). Copy this package's contents there. It is not a
`YR_MPE/bin/` tool.

## Build

No compilation. `build.sh` copies the checked-in static tree, adds the
license/readme/version, and calls `scripts/package_tool.sh`.

## Smoke test

`smoke.sh` verifies that `index.html` and every local `src=`/`href=` asset
referenced by it exist, that the main JavaScript/CSS files are present, and
that the package is large enough to contain the bundled Plotly library.
