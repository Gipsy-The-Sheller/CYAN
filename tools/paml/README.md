# PAML

PAML (Phylogenetic Analysis by Maximum Likelihood) is Ziheng Yang's suite
for codon, amino-acid and Bayesian phylogenetic analysis. The package
includes `codeml`, `baseml`, `mcmctree`, `yn00`, `evolver` and the remaining
programs from the 4.10 series.

- Upstream: <https://github.com/abacus-gene/paml>
- Version: 4.10.10 (tag `v4.10.10`, commit `4c7902f`, 2026-01-29)
- License: GPL-3.0

## Package

```text
paml/
├─ baseml(.exe)
├─ basemlg(.exe)
├─ codeml(.exe)
├─ evolver(.exe)
├─ mcmctree(.exe)
├─ pamp(.exe)
├─ yn00(.exe)
├─ chi2(.exe)
├─ ds(.exe)
├─ infinitesites(.exe)
├─ dat/                 model tables (codon, WAG, etc.)
├─ examples/            yn00 abglobin and codeml lysozyme inputs
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

Extracting into `YR_MPE/bin/` yields `YR_MPE/bin/paml/`.

## Build notes

- Plain upstream Makefile; no patches.
- Windows and Linux builds are static; macOS uses the system C runtime.
- `dat/` is shipped because `codeml`/`baseml` read model tables such as
  `dat/wag.dat` relative to the working directory.
- `make all infinitesites` builds the full program set.

## Smoke test

`smoke.sh` runs the upstream `yn00` abglobin example (checks the omega
table) and the `codeml` lysozyme branch-model example (checks `lnL` and
clean completion).
