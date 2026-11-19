# DecentTree

DecentTree is a distance-matrix tree builder from the IQ-TREE project. It
implements neighbour joining (NJ), BIONJ, RapidNJ/RapidBIONJ variants, and an
auction-based heuristic for minimum-evolution trees. It reads PHYLIP distance
matrices (`.mldist`) and writes Newick trees.

- Upstream: <https://github.com/iqtree/decenttree>
- Version: 1.0.0 (upstream commit `c106c86a`, 2024-06-21; no algorithm
  changes since the v1.0.0 tag)
- License: GPL-2.0

## YR-MPE integration

The YR-MPE plugin invokes:

```text
decenttree -in distances.mldist -out tree.nwk -t ALGORITHM -no-banner
```

Algorithms exposed by YR-MPE:

| Name | Implementation |
| --- | --- |
| `BIONJ-R` | Rapid BIONJ (BoundingMatrix) |
| `BIONJ-V` | Vectorised BIONJ (x86) |
| `NJ-R-D` | Double-precision RapidNJ |
| `ONJ-R` | RapidNJ, alternative scanning |
| `ONJ-R-V` | Vectorised ONJ (x86) |
| `AUCTION` | Auction-based heuristic |

`NJ`, `NJ-R`, `NJ-R-V` and `BIONJ` are also available. The package root is
`decenttree/`, so extracting the archive into `YR_MPE/bin/` produces
`YR_MPE/bin/decenttree/decenttree(.exe)`.

## CYAN patches

`patches/decenttree-portability.patch` contains four fixes:

1. **Uninitialised rootedness flag** (`starttree.h`, `starttree.cpp`): the
   `Builder` constructors left `isRooted` uninitialised. Depending on the
   stack contents this made every algorithm except ONJ-R crash, or silently
   produced rooted trees. It is now initialised to `false`, so trees are
   unrooted (degree-3 root), the standard NJ representation.
2. **AUCTION leaf loss** (`auctionmatrix.h`): the second-best partner search
   never advanced past the best entry, and the reported pair was not the
   bidding row. This could drop a taxon from the output tree. The search now
   advances past the best entry, reports the actual row pair, and computes the
   bid from the second-best distance.
3. **Portability** (`utils/vectortypes.h`, `utils/hammingdistance.h`,
   `upgma.h`): add `<cstdint>`, replace the x86 `popcnt` inline assembly with
   `__builtin_popcountll`, fix a `copst` typo, and guard the vectorclass
   include numerically.
4. **ARM support** (`CMakeLists.txt`, `bionj2.cpp`): the bundled
   vectorclass library (Agner Fog 1.25) is x86-only. It is disabled on ARM,
   the examples/Python bindings are opt-in, and the `-V` algorithm names are
   aliased to their scalar equivalents so the YR-MPE command line is
   unchanged on all platforms.

## Build notes

- Windows and Linux builds are static. The macOS build uses the system
  libc++/libSystem.
- Windows x86-64 and Linux x86-64 build the vectorised implementations.
- Windows arm64, Linux arm64 and macOS arm64 use the scalar implementations
  and the `-V` aliases.
- OpenMP is used when the toolchain provides it.

## Files

| Path | Purpose |
| --- | --- |
| `src/` | Vendored upstream source (pruned prebuilt libraries and examples) |
| `patches/` | CYAN portability/correctness patch |
| `examples/example.mldist` | Six-taxon matrix used by the smoke test |
| `build.sh` | Configure, build, stage and package |
| `smoke.sh` | Run the six YR-MPE algorithms and check all taxa |
