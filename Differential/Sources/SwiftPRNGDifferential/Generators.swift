// The generators section (scripts/differential_generators.py): a seed and a count, answered with
// the first values of every generator and the first two after a jump and a long jump. Values are
// strings, since JSON numbers lose 64-bit precision.

import Generators

struct GeneratorsCase: Decodable {
    let seed: UInt64
    let count: Int
}

struct GeneratorsAnswer: Encodable {
    var splitmix64: [String]
    var xoroshiro128plus: [String]
    var xoroshiro128plus_jumped: [String]
    var xoroshiro128plus_long_jumped: [String]
    var xoshiro256starstar: [String]
    var xoshiro256starstar_jumped: [String]
    var xoshiro256starstar_long_jumped: [String]

    init(_ input: GeneratorsCase) {
        func values<Generator: RandomNumberGenerator>(_ generator: inout Generator, _ count: Int) -> [String] {
            (0 ..< count).map { _ in String(generator.next()) }
        }
        var splitMix = SplitMix64(seed: input.seed)
        splitmix64 = values(&splitMix, input.count)
        var xoroshiro = Xoroshiro128Plus(seed: input.seed)
        xoroshiro128plus = values(&xoroshiro, input.count)
        var xoroshiroJumped = xoroshiro.jumped()
        xoroshiro128plus_jumped = values(&xoroshiroJumped, 2)
        var xoroshiroLongJumped = xoroshiro.longJumped()
        xoroshiro128plus_long_jumped = values(&xoroshiroLongJumped, 2)
        var xoshiro = Xoshiro256StarStar(seed: input.seed)
        xoshiro256starstar = values(&xoshiro, input.count)
        var xoshiroJumped = xoshiro.jumped()
        xoshiro256starstar_jumped = values(&xoshiroJumped, 2)
        var xoshiroLongJumped = xoshiro.longJumped()
        xoshiro256starstar_long_jumped = values(&xoshiroLongJumped, 2)
    }
}
