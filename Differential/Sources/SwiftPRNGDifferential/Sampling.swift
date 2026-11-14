// The sampling section (scripts/differential_sampling.py): one Xoshiro256StarStar seed and the
// bounds of each draw, each answered from a fresh generator. Doubles are their shortest
// round-trip text, which Python's repr also produces.

import Generators
import Sampling

struct SamplingCase: Decodable {
    let seed: UInt64
    let lower: Int
    let upper: Int
    let closedUpper: Int
    let intervalLower: Double
    let intervalUpper: Double
    let probability: Double
}

struct SamplingAnswer: Encodable {
    var uniform: String
    var integer: Int
    var closedInteger: Int
    var interval: String
    var bernoulli: Bool

    init(_ input: SamplingCase) {
        var generator = Xoshiro256StarStar(seed: input.seed)
        uniform = generator.uniform().description
        generator = Xoshiro256StarStar(seed: input.seed)
        integer = generator.integer(in: input.lower ..< input.upper)
        generator = Xoshiro256StarStar(seed: input.seed)
        closedInteger = generator.integer(in: input.lower ... input.closedUpper)
        generator = Xoshiro256StarStar(seed: input.seed)
        interval = generator.uniform(in: input.intervalLower ..< input.intervalUpper).description
        generator = Xoshiro256StarStar(seed: input.seed)
        bernoulli = generator.bernoulli(input.probability)
    }
}
