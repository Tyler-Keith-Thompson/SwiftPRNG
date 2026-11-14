# Differential testing

Runs the library and independent reference implementations on the same random cases and compares
the answers. The references are pure Python; a reference package would be pinned in `scripts/differential.py`
(`REFERENCES`) and run through `uv`, so nothing is installed globally.

| Command | Does |
|---|---|
| `just diff` | 2,000 random cases with a random seed, every area |
| `just diff --cases 20000 --seed 7` | More cases, reproducibly |
| `just diff --module SeedTrees` | Only one module's comparisons; repeat the flag for several |
| `just diff --swiftpm` | Build the library side with SwiftPM instead of Bazel |

`SwiftPRNGDifferential` (this package) reads a batch of cases as JSON and answers them with the
library; `scripts/differential.py` generates the cases from a seed, asks each area's reference the
same questions, and compares. A disagreement is written to `Failures/` (not committed) with its
seed and the case; it becomes a regression test in the module's suite, then the file goes.

The executable is built through Bazel, `//Differential:SwiftPRNGDifferential` (a `manual`
`swift_binary`), with `--config=release` in the output base `just test-release` uses, so a run only
compiles what changed. `scripts/modules.py` writes its BUILD.bazel and Package.swift from one
list, `DIFFERENTIAL_DEPENDENCIES`. The SwiftPM package serves `--swiftpm`.

## Areas

| Area | Library | Reference |
|---|---|---|
| `distributions` | Three samples of each distribution from a fresh `Xoshiro256StarStar`, with parameters at their edges (no spread, modes at the bounds, bounds that overflow their width, the Poisson thresholds, weights from 10⁻³⁰⁰ to 10³⁰⁰), compared bit for bit | The same algorithms written out in Python over the reference sequence, with fdlibm's `log`, `log1p`, `exp` and sine and cosine kernels reimplemented on the bits of each double; the Swift tests separately hold the port within one ulp of the platform's math |
| `generators` | `SplitMix64`, `Xoroshiro128Plus` and `Xoshiro256StarStar` from a seed, then `jumped()` and `longJumped()` | The reference C written out in Python with 64-bit masks; the jumps by raising each generator's GF(2) transition matrix to 2⁶⁴, 2⁹⁶, 2¹²⁸ or 2¹⁹² by repeated squaring, a different method from the library's jump polynomials |
| `sampling` | `uniform()`, `integer(in:)` over half-open and closed ranges (including the whole `Int` domain), `uniform(in:)` and `bernoulli(_:)` on a fresh `Xoshiro256StarStar` | The same algorithms written out in Python over the reference sequence: top 53 bits scaled, rejection sampling, the affine map with `nextafter` clamp, the comparison |
| `seedtrees` | The seed at each of several paths of a tree with overrides | FNV-1a over UTF-8 and the index constant, one SplitMix64 step per key and per child, recomputed from the root with overrides looked up by full path |

## Adding an area

1. `scripts/differential_<area>.py`: `MODULE` (the library module it checks), `generate(rng)`
   (one case, a JSON value, drawn only from `rng`), `reference(case)` and
   `compare(case, mine, reference)` (a list of problems, empty when they agree). A reference
   package goes in `REFERENCES`, pinned.
2. `Sources/SwiftPRNGDifferential/<Area>.swift`: the case and answer types, and a field for
   each in `main.swift`'s `Case` and `Answer`, answered when `asked("<area>")`.
3. The module in `DIFFERENTIAL_DEPENDENCIES` (`scripts/modules.py`), then `just modules`.

Compare only what ties cannot change: where correct implementations may differ (an order among
equals, which of several valid answers), validate the library's answer instead of matching it.
