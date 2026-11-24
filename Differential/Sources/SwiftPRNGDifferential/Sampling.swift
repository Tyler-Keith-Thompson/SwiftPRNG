// The sampling section (scripts/differential_sampling.py): one Xoshiro256StarStar seed and the
// bounds of each draw, each answered from a fresh generator. Doubles are their shortest
// round-trip text, which Python's repr also produces. A shuffle and an element pick also report
// the generator's next value afterwards, which pins how many draws they took.

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
    let shuffleCount: Int
    let elementCount: Int
}

struct SamplingAnswer: Encodable {
    var uniform: String
    var integer: Int
    var closedInteger: Int
    var interval: String
    var bernoulli: Bool
    var shuffled: [Int]
    var afterShuffle: UInt64
    var element: Int?
    var afterElement: UInt64

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
        generator = Xoshiro256StarStar(seed: input.seed)
        shuffled = generator.shuffled(0 ..< input.shuffleCount)
        afterShuffle = generator.next()
        generator = Xoshiro256StarStar(seed: input.seed)
        element = generator.element(in: 0 ..< input.elementCount)
        afterElement = generator.next()
    }
}
