# MAFFT

MAFFT is a multiple sequence alignment program. The Windows distribution is
a prebuilt native payload driven by a bash script and a bundled MSYS2
environment.

- Upstream: <https://mafft.cbrc.jp/alignment/software/>
- Windows bundle: <https://mafft.cbrc.jp/alignment/software/mafft-7.505-mingw64-signed.tar>
- Version: 7.505 (2022/Apr/10)
- License: BSD-3-Clause (MAFFT core); the bundled runtime keeps its own
  GPL/LGPL/BSD licenses, listed in `LICENSE-MSYS2.txt`

CYAN does not compile MAFFT. The official Windows payload is repacked with a
reduced runtime because upstream's `usr/bin` contains a complete 20 MB MSYS2
installation while the MAFFT driver needs only a small subset.

## Package

```text
mafft/
├─ mafft.bat                   official Windows launcher
├─ usr/
│  ├─ bin/
│  │  ├─ mafft                 official shell driver (unmodified)
│  │  ├─ bash.exe
│  │  ├─ awk.exe
│  │  ├─ sed.exe
│  │  ├─ grep.exe
│  │  ├─ basename.exe … wc.exe
│  │  └─ msys-*.dll
│  └─ lib/mafft/
│     ├─ tbfast.exe
│     ├─ dvtditr.exe
│     ├─ mafft-distance.exe
│     └─ … (native MAFFT engines)
├─ LICENSE-MAFFT
├─ LICENSE-MSYS2.txt
├─ COPYING-GPL-3
├─ README.md
└─ VERSION
```

Extracting the archive into `YR_MPE/bin/` yields
`YR_MPE/bin/mafft/mafft.bat`, matching `YR_MPE/config.json`.

## Runtime whitelist

`usr/bin` contains exactly these 27 files:

```text
awk.exe basename.exe bash.exe cat.exe cp.exe dirname.exe env.exe
expr.exe grep.exe head.exe mafft mkdir.exe mktemp.exe
msys-2.0.dll msys-gmp-10.dll msys-iconv-2.dll msys-intl-8.dll
msys-mpfr-4.dll msys-pcre-1.dll msys-readline6.dll
mv.exe rm.exe sed.exe tail.exe tr.exe uname.exe wc.exe
```

The `mktemp`/`env`/`expr` helpers are invoked by the driver; `awk` is used
for FASTA/Clustal post-processing; the DLLs are the transitive dependencies
of those executables (`awk.exe` needs `msys-mpfr-4.dll`, for example).

## Build

`build.sh` verifies the SHA-256 checksums in `src/SHA256SUMS`, unpacks the
payload and runtime archives, checks the exact `usr/bin` file set, and calls
`scripts/package_tool.sh`. There is no compilation and no source patch.

The two archives preserve what git's text normalization would otherwise
change: `mafft.bat` keeps its CRLF line endings, and the native helpers keep
their executable bits.

## Smoke test

`smoke.sh` runs 12 cases through `mafft.bat`:

- `--auto`, default (high speed), `--localpair`, `--genafpair`,
  `--globalpair`, `--retree 1`;
- `--adjustdirection` and `--adjustdirectionaccurately` on a reversed record;
- `--clustalout`, `--reorder`, `--op/--ep`, and `--thread 2`.

FASTA output must contain five equal-length records; Clustal output must
contain five names; reversed records must receive MAFFT's `_R_` prefix; and
the two-thread output must be byte-identical to `--auto`.
