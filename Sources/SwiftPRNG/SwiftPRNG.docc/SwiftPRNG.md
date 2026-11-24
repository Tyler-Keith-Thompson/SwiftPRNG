# ``SwiftPRNG``

Seeded random numbers whose seeds you can find, write down and hand to someone else.

## Overview

Every type is a value. The generators (``/Generators``) reproduce bit for bit on every platform
and in every Swift release, and are `Hashable`, `Sendable` and `Codable`, so a position in a
sequence can be copied, compared, saved and restored. The draws (``/Sampling``) fix their
algorithms, where the standard library's `random(in:using:)` promises only a correct distribution.
The distributions (``/Distributions``) do the same for normal, exponential, gamma, Poisson and
the rest, down to their logarithms and cosines. A seed tree (``/SeedTrees``) gives each decision in a program a seed of its own, derived from a
path of names and indices, so adding a draw anywhere never shifts the numbers elsewhere. A seed
search (``/SeedDiscovery``) finds the smallest seed in a range that does what a predicate asks,
sequentially or across cores, and a tree fits that seed into one subtree while the rest of the
program stays as it was.

Bounds that cannot be sampled trap, like an `Array` subscript; the `checked` spellings throw a
typed error instead.

`import SwiftPRNG` imports every module. Each module also has its own documentation and can be
imported on its own.

```swift
import SwiftPRNG

let tree = SeedTree(42)
let fitted = tree.fitting(["customer", 7], in: SeedSearch(0 ..< 100_000)) { tree in
    tree["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1
}
let overrides = fitted?.overriddenSeeds  // [["customer", 7]: 33]
```

## Topics

### Guides

- <doc:SeededGenerators>
- <doc:PlatformStableDraws>
- <doc:SamplingDistributions>
- <doc:NonOverlappingStreams>
- <doc:UsingSeedTrees>
- <doc:SearchingSeedsAcrossCores>

### Modules

- ``/Generators``
- ``/Sampling``
- ``/Distributions``
- ``/SeedDiscovery``
- ``/SeedTrees``
