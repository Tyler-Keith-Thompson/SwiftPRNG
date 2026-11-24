# Platform-stable draws

Uniform values, integers, coin flips, shuffles and picks that a seed fixes on every platform and
Swift release.

## Overview

The standard library's `random(in:using:)`, `shuffled(using:)` and `randomElement(using:)`
guarantee a correct distribution, but not the same answer in every release. These draws pin the
algorithm down, so a seed gives the same numbers everywhere.

```swift
var generator = Xoshiro256StarStar(seed: 42)
let unit = generator.uniform()                  // 0.08386297105988216, in [0, 1)
let delay = generator.uniform(in: 0.5 ..< 2)    // seconds
let lane = generator.integer(in: 0 ..< 4)
let dropped = generator.bernoulli(0.01)
let order = generator.shuffled(["north", "south", "east", "west"])
let pick = generator.element(in: order)        // nil only for an empty collection
```

`shuffled(_:)` copies any sequence into an array and shuffles it, and `shuffle(_:)` shuffles a
mutable random-access collection in place, such as an array or a slice of one. Both use
Fisher-Yates and take one integer draw per element after the first, so an empty or one-element
collection takes none. `element(in:)` takes one integer draw, or none for an empty collection.

A bound that can't be sampled traps, the way an out-of-range `Array` subscript does. To get an
error instead, use the `checked` spellings: `integer(checkedIn:)`, `uniform(checkedIn:)` and
`bernoulli(checked:)` all throw.
