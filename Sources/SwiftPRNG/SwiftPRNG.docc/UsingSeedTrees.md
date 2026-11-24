# Using seed trees

A seed for every decision, derived from a path, so adding a draw in one place never moves the
numbers in another.

## Overview

A `SeedTree` derives each node's seed from its parent's seed and a key, which is a name or an
index. Each decision draws from its own node. Customer 7 arrives at the same time whether or not
you add customer 6, and whether or not the code before it draws one more number.

```swift
let tree = SeedTree(42)
let arrival = tree["customer", 7, "arrival"].uniform(in: 0 ..< 60)
var choices = tree["customer", 7, "choices"].generator
let aisle = choices.integer(in: 0 ..< 12)
let arrivals = (0 ..< 3).map { customer in tree["customer", customer, "arrival"].uniform(in: 0 ..< 60) }
```

Keys can be literals or `String` and `Int` values.

A node's `description` gives its path and seed, as in `/customer/7 (seed 1271…)`. Print it when a
test fails.

To change one part of a tree, override a node: everything under it derives from the new seed,
and its siblings keep theirs. `fitting` searches for the override that makes a predicate true.
The overview of ``SwiftPRNG`` has an example.
