# SwiftPRNG

Seeded random numbers for Swift, built so that a seed is something you can find, write down and
hand to someone else. Generators reproduce bit for bit on every platform and in every Swift
release; a seed tree gives each decision in a program a seed of its own, so adding a draw anywhere
never shifts the numbers elsewhere; and a seed search finds the seed that does what you need, then
fits it into one subtree while the rest of the program stays as it was.

[Documentation](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/)

## Installation

SwiftPRNG requires Swift 6.3 and supports macOS 13, Mac Catalyst 15, iOS 15, tvOS 16, watchOS 9 and
visionOS 1 or later.

```swift
dependencies: [
    .package(url: "https://github.com/Tyler-Keith-Thompson/SwiftPRNG", from: "0.0.1"),
],
```

Then add a product to your target, either the umbrella or individual modules:

```swift
.target(name: "MyApp", dependencies: [
    .product(name: "SwiftPRNG", package: "SwiftPRNG"),
    // or, for example:
    // .product(name: "SeedTrees", package: "SwiftPRNG"),
]),
```

## Usage

Fit one subtree of a seed tree so that a scenario happens, with every other draw left as it was:

```swift
import SwiftPRNG

let tree = SeedTree(42)
let fitted = tree.fitting(["customer", 7], in: SeedSearch(0 ..< 100_000)) { tree in
    tree["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1
}
let overrides = fitted?.overriddenSeeds  // [["customer", 7]: 33]
```

The overrides are plain data. Write them into the test, and `SeedTree(42, overrides:)` rebuilds the
fitted tree anywhere.

The [documentation](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/) has a guide
for each part:
[seeded generators](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/seededgenerators),
[platform-stable draws](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/platformstabledraws),
[distributions](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/samplingdistributions),
[streams that never overlap](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/nonoverlappingstreams),
[seed trees](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/usingseedtrees)
and [searching seeds across cores](https://tyler-keith-thompson.github.io/SwiftPRNG/documentation/swiftprng/searchingseedsacrosscores).
Every example in the README and the guides is a test in `Tests/SwiftPRNGTests`.

## Modules

| Module | Holds |
|---|---|
| `Generators` | `SeedableRandomNumberGenerator`; `SplitMix64`, `Xoroshiro128Plus` and `Xoshiro256StarStar`, with `jump()` and `longJump()` |
| `Sampling` | `uniform()`, `uniform(in:)`, `integer(in:)`, `bernoulli(_:)`, `shuffle(_:)`, `shuffled(_:)` and `element(in:)` on any `RandomNumberGenerator`, with checked spellings |
| `Distributions` | `Distribution` and its samplers: `NormalDistribution`, `ExponentialDistribution`, `TriangularDistribution`, `LogNormalDistribution`, `GammaDistribution`, `PoissonDistribution`, `GeometricDistribution`, `WeightedChoiceDistribution`, `ConstantDistribution`, and `map`; `Fdlibm`'s platform-stable `log`, `log1p` and `exp` |
| `SeedDiscovery` | `SeedSearch` and `ConcurrentSeedSearch`: the smallest seed in a range a predicate accepts |
| `SeedTrees` | `SeedTree`, `SeedKey` and `SeedPath`: derived seeds by path, distributions sampled per node, overrides and `fitting` |

## Development

Bazel is the development build; SwiftPM is the published package. Both are generated from
`scripts/modules.py`.

| Command | Does |
|---|---|
| `just test` | Build and run every test |
| `just verify` | The tests under Bazel and under SwiftPM |
| `just modules` | Regenerate `Package.swift` and every `BUILD.bazel` |
| `just docs` | The DocC site into `.build/docs` |
| `just bench` | The benchmarks (`Benchmarks/README.md`) |
| `just diff` | The generators, draws, distributions and seed trees against pure-Python references (`Differential/README.md`) |
| `just fuzz` | The libFuzzer targets (`Fuzz/README.md`) |
| `just generate` | An Xcode project from the Bazel graph, in `xcode/` |

`AGENTS.md` describes the layout, the workflow and the house rules in full.

## License

Apache 2.0. See `LICENSE`.
