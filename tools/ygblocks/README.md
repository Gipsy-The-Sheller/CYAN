# YGBlocks

YGBlocks is an independent, MIT-licensed implementation of the GBlocks
0.91b conserved-block selection. It reads FASTA and PHYLIP alignments and
produces:

- `<input><ext>.fa` — the selected alignment in FASTA;
- `<input><ext>.txt` — a masked report in interleaved PHYLIP form.

The selected alignment is byte-compatible with the GBlocks 0.91b binary for
nucleotide, codon and protein alignments. Protein similarity uses the Gonnet
120 matrix.

## Package

```text
Gblocks/
├─ bin/Gblocks(.exe)
├─ LICENSE
├─ README.md
├─ README-CYAN.txt
└─ VERSION
```

The `Gblocks/` archive root and `Gblocks.exe` name match
`YR_MPE/config.json`, so the package extracts directly into `YR_MPE/bin/`.

## Input formats

- FASTA, including wrapped sequences, spaces inside sequence lines, and CRLF.
- PHYLIP, interleaved or one-line sequential, strict 10-column names or
  relaxed names. Names containing a single space are supported when the name
  is followed by two or more padding spaces.

## Report

The report is an interleaved PHYLIP-style alignment of the **original**
alignment:

- kept positions are uppercase;
- removed positions are lowercase;
- every `-` gap is written as `.`;
- the first line is `<ntaxa> <nchar>`;
- 60 alignment columns per block, with a space every 10 columns.

`-p=n` disables the report; `-p=t` (or the default) enables it.

## CLI

```text
Gblocks <alignment> [options]
  -t=p|d|c      protein, DNA or codon
  -b1=N         minimum sequences for a conserved position
  -b2=N         minimum sequences for a flank position
  -b3=N         maximum contiguous nonconserved positions
  -b4=N         minimum block length after gap cleaning
  -b0=N         minimum initial block length
  -b5=n|h|a     allowed gap positions
  -b6=y|n       protein similarity matrix
  -e=EXT        output extension (default -gb)
  -s=y|n        write selected alignment
  -p=y|t|s|n    write masked report
```

The parser also accepts the YR-MPE invocation
`-p=n -q=n -r=n -e=-gb`.

## Algorithm

GBlocks-compatible block selection:

1. remove all-gap columns (`-` and `.`);
2. classify each column as nonconserved, conserved or highly conserved
   using `b1`, `b2` and, for protein, the Gonnet 120 matrix;
3. reject runs of nonconserved columns longer than `b3`;
4. trim each region to its first and last highly conserved columns;
5. apply the initial block length `b0`;
6. remove gap positions and adjacent nonconserved columns;
7. apply the final block length `b4`;
8. for codon data, trim blocks inwards to complete codons.
