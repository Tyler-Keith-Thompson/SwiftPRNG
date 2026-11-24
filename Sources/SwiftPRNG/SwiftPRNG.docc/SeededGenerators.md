# Seeded generators

Generators that are values, driving the standard library's randomness API.

## Overview

Every generator is `Hashable`, `Sendable` and `Codable`, so a position in a sequence can be copied,
compared, saved and restored.

```swift
import SwiftPRNG

var generator = Xoshiro256StarStar(seed: 42)
let roll = Int.random(in: 1 ... 6, using: &generator)
let hand = ["♠", "♥", "♦", "♣"].shuffled(using: &generator)
```

Use `Xoshiro256StarStar` unless you have a reason not to. `Xoroshiro128Plus` is a little faster
when you only draw `Double`s, and `SplitMix64` is what seeds the other two.

The standard library's `random(in:using:)` and `shuffled(using:)` can change their algorithms
between Swift releases. For numbers that must stay the same from one release to the next, draw
through <doc:PlatformStableDraws>.
