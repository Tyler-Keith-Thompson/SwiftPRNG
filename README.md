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

Every example here is a test in `Tests/SwiftPRNGTests`, so it cannot drift from the code.

### Seeded generators

Every generator is a value: `Hashable`, `Sendable` and `Codable`, so a position in a sequence can
be copied, compared, saved and restored. All of them drive the standard library's randomness API.

```swift
import SwiftPRNG

var generator = Xoshiro256StarStar(seed: 42)
let roll = Int.random(in: 1 ... 6, using: &generator)
let hand = ["♠", "♥", "♦", "♣"].shuffled(using: &generator)
```

`Xoshiro256StarStar` is the general-purpose choice. `Xoroshiro128Plus` is a little faster where
only `Double`s are drawn, and `SplitMix64` seeds the others.

### Platform-stable draws

The standard library's `random(in:using:)` promises a correct distribution, not the same answer
in every release. These draws fix the algorithm, so a seed means the same numbers everywhere.

```swift
var generator = Xoshiro256StarStar(seed: 42)
let unit = generator.uniform()                  // 0.08386297105988216, in [0, 1)
let delay = generator.uniform(in: 0.5 ..< 2)    // seconds
let lane = generator.integer(in: 0 ..< 4)
let dropped = generator.bernoulli(0.01)
```

Bounds that cannot be sampled trap, like an `Array` subscript; the `checked` spellings
(`integer(checkedIn:)`, `uniform(checkedIn:)`, `bernoulli(checked:)`) throw instead.

### Distributions

Normal, exponential, triangular, log-normal, gamma, Poisson, geometric and weighted choice. Each
fixes its algorithm and how many draws it takes, and computes its logarithms and cosines with a
portable port of fdlibm, so a sample is the same on every platform, not just close. The port's
`Fdlibm.log`, `Fdlibm.log1p` and `Fdlibm.exp` are public, for seeded code of your own.

```swift
var generator = Xoshiro256StarStar(seed: 42)
let height = NormalDistribution(mean: 170, standardDeviation: 8).sample(using: &generator)
let items = PoissonDistribution(mean: 3).sample(using: &generator)
let aisle = WeightedChoiceDistribution([
    (value: "produce", weight: 5), (value: "bakery", weight: 2), (value: "deli", weight: 1),
]).sample(using: &generator)

let service = SeedTree(42)["customer", 7, "service"].sample(.gamma(shape: 2, scale: 1.5))
```

A distribution is a value holding its parameters, so it can be stored, compared and shared.
Invalid parameters trap; `init(checkedMean:standardDeviation:)` and the other `checked`
initializers throw `InvalidParameters` instead.

Your own distributions are extensions: `map` derives one from another, drawing nothing more.

```swift
extension Distribution where Self == MappedDistribution<ExponentialDistribution, Duration> {
    /// Waiting times with this mean.
    static func exponential(mean: Duration) -> Self {
        let (seconds, attoseconds) = mean.components
        return ExponentialDistribution(mean: Double(seconds) + Double(attoseconds) * 1e-18).map { .seconds($0) }
    }
}

let wait = SeedTree(42)["customer", 7, "wait"].sample(.exponential(mean: .seconds(90)))
```

### Streams that never overlap

A jump advances a generator so far that the sequences before and after share nothing. One seed
gives one stream per thread, or one per entity, with no coordination.

```swift
var generator = Xoshiro256StarStar(seed: 42)
var streams: [Xoshiro256StarStar] = []
for _ in 0 ..< 4 {
    streams.append(generator)
    generator.jump()  // 2¹²⁸ steps on
}
```

### Seed trees

A `SeedTree` derives each node's seed from its parent's seed and a key, a name or an index. Every
decision reads from its own node, so the arrival time of customer 7 is the same whether or not
customer 6 was added, and whether or not the code before it drew one more number.

```swift
let tree = SeedTree(42)
let arrival = tree["customer", 7, "arrival"].uniform(in: 0 ..< 60)
var choices = tree["customer", 7, "choices"].generator
let aisle = choices.integer(in: 0 ..< 12)
let arrivals = (0 ..< 3).map { customer in tree["customer", customer, "arrival"].uniform(in: 0 ..< 60) }
```

Keys are names or indices: literals, or `String` and `Int` values.

A node's `description` is its path and seed, `/customer/7 (seed 1271…)`: the thing to print when a
test fails.

### Fitting a subtree

Overriding a node replaces its seed, and everything below it derives from the new one while
siblings keep theirs. `fitting` searches for the override that makes a predicate true, so a
scenario is built one requirement at a time: the customer who arrives in the first minute, the
request that times out, the shuffle that puts the ace on top. Each fit leaves every other node's
draws exactly as they were.

```swift
let tree = SeedTree(42)
let fitted = tree.fitting(["customer", 7], in: SeedSearch(0 ..< 100_000)) { tree in
    tree["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1
}
let overrides = fitted?.overriddenSeeds  // [["customer", 7]: 33]
```

The overrides are plain data: write them into the test, and `SeedTree(42, overrides:)` rebuilds
the fitted tree anywhere.

### Searching seeds across cores

`SeedSearch` returns the smallest matching seed, so a search reproduces. `concurrent()` spreads it
over every processor and finds the same seed.

```swift
let seed = await SeedSearch(0 ..< 10_000_000).concurrent().first { seed in
    var generator = Xoshiro256StarStar(seed: seed)
    return generator.uniform() > 0.999_99
}
```

`count(where:)` says how many seeds in a range match, which is how rare a property is and how wide
a range its search needs.

## Modules

| Module | Holds |
|---|---|
| `Generators` | `SeedableRandomNumberGenerator`; `SplitMix64`, `Xoroshiro128Plus` and `Xoshiro256StarStar`, with `jump()` and `longJump()` |
| `Sampling` | `uniform()`, `uniform(in:)`, `integer(in:)` and `bernoulli(_:)` on any `RandomNumberGenerator`, with checked spellings |
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
| `just generate` | An Xcode project from the Bazel graph |

`AGENTS.md` describes the layout, the workflow and the house rules in full.

## License

Apache 2.0. See `LICENSE`.
