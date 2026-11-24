# Platform-stable draws

Uniform values, integers and coin flips that a seed fixes on every platform and Swift release.

## Overview

The standard library's `random(in:using:)` guarantees a correct distribution, but not the same
answer in every release. These draws pin the algorithm down, so a seed gives the same numbers
everywhere.

```swift
var generator = Xoshiro256StarStar(seed: 42)
let unit = generator.uniform()                  // 0.08386297105988216, in [0, 1)
let delay = generator.uniform(in: 0.5 ..< 2)    // seconds
let lane = generator.integer(in: 0 ..< 4)
let dropped = generator.bernoulli(0.01)
```

A bound that can't be sampled traps, the way an out-of-range `Array` subscript does. To get an
error instead, use the `checked` spellings: `integer(checkedIn:)`, `uniform(checkedIn:)` and
`bernoulli(checked:)` all throw.
