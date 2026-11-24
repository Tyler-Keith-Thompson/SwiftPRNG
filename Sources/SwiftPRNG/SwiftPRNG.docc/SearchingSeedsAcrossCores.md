# Searching seeds across cores

The smallest seed a predicate accepts, found the same way on one core or many.

## Overview

`SeedSearch` returns the smallest seed that matches, so running the same search again finds the
same seed. `concurrent()` splits the search across every processor and still finds that seed.

```swift
let seed = await SeedSearch(0 ..< 10_000_000).concurrent().first { seed in
    var generator = Xoshiro256StarStar(seed: seed)
    return generator.uniform() > 0.999_99
}
```

`count(where:)` tells you how many seeds in a range match. That shows how rare a property is, and
so how wide a range you need to search for it.
