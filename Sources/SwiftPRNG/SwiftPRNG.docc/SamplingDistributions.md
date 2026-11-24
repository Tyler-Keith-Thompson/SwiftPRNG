# Sampling distributions

Normal, exponential, triangular, log-normal, gamma, Poisson, geometric and weighted-choice samples
that match bit for bit on every platform.

## Overview

Each distribution fixes its algorithm and how many draws it takes. Its logarithms and cosines come
from a port of fdlibm, so a sample has the same bits on every platform. The port's
`Fdlibm.log`, `Fdlibm.log1p` and `Fdlibm.exp` are public, so your own seeded code can use them too.

```swift
var generator = Xoshiro256StarStar(seed: 42)
let height = NormalDistribution(mean: 170, standardDeviation: 8).sample(using: &generator)
let items = PoissonDistribution(mean: 3).sample(using: &generator)
let aisle = WeightedChoiceDistribution([
    (value: "produce", weight: 5), (value: "bakery", weight: 2), (value: "deli", weight: 1),
]).sample(using: &generator)

let service = SeedTree(42)["customer", 7, "service"].sample(.gamma(shape: 2, scale: 1.5))
```

A distribution is a value that holds its parameters, so you can store, compare and share it.
Invalid parameters trap. `init(checkedMean:standardDeviation:)` and the other `checked`
initializers throw `InvalidParameters` instead.

### Your own distributions

You add a distribution by writing an extension. `map` turns one distribution into another without
drawing any extra numbers.

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
