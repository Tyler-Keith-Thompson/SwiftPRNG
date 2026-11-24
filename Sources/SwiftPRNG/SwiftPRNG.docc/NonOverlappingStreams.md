# Streams that never overlap

One seed, many independent streams: one per thread or one per entity.

## Overview

`jump()` moves a generator 2¹²⁸ steps ahead, so the numbers it gives afterwards never repeat the
ones it would have given before. Copy the generator, jump it, and repeat: each copy is a stream of
its own, and a thread or entity can draw from its copy without coordinating with the others.

```swift
var generator = Xoshiro256StarStar(seed: 42)
var streams: [Xoshiro256StarStar] = []
for _ in 0 ..< 4 {
    streams.append(generator)
    generator.jump()  // 2¹²⁸ steps on
}
```
