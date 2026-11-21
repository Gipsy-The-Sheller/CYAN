# BMGE

BMGE (Block Mapping and Gathering with Entropy) selects phylogenetically
informative blocks from multiple sequence alignments using entropy and gap
thresholds.

- Upstream: <https://gitlab.pasteur.fr/GIPhy/BMGE>
- Version: 2.0 (commit `4539aa6`, 2024-02-08)
- License: GPL-3.0-or-later

## Package

```text
BMGE/
├─ BMGE.jar
├─ BMGE.bat        Windows launcher
├─ bmge            Unix launcher
├─ example.fna     upstream 55-sequence nucleotide example
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

The jar is platform-neutral and compiled with `--release 11`. A Java 11+
runtime is required; CYAN does not bundle a JRE. The package root is
`BMGE/`, matching YR-MPE's `/bin/BMGE/` layout.

## Build notes

- BMGE v2 is a single Java source file; `javac --release 11` and `jar cfe`
  produce the jar.
- Only one package is built because the jar runs on Windows, Linux and
  macOS once Java is present.
- The Java 24 local build was verified against the upstream 55-sequence
  nucleotide example.

## Smoke test

`smoke.sh` checks the `BMGE v2.0` banner and runs the example through
`-i ... -t NT -o ...`, requiring 55 equal-length output sequences.
