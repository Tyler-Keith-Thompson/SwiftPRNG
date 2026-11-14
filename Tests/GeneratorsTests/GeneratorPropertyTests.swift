// Property tests against naive references: SplitMix64 and the seeding of the other generators,
// written out step by step, must agree with the library for any seed.

import Foundation
import Generators
import PropertyBased
import SwiftPRNGTestSupport
import Testing

@Suite("Generators: properties")
struct GeneratorPropertyTests {
    @Test("SplitMix64 is the reference mixing of a counter stepped by the golden ratio", .tags(.randomized))
    func splitMixReference() async {
        await propertyCheck(count: 500, input: Gen.uint64()) { seed in
            func mix(_ value: UInt64) -> UInt64 {
                var mixed = value
                mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
                mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
                return mixed ^ (mixed >> 31)
            }
            let expected = (1 ... 4).map { step in mix(seed &+ UInt64(step) &* 0x9E37_79B9_7F4A_7C15) }
            var sut = SplitMix64(seed: seed)

            let actual = (0 ..< 4).map { _ in sut.next() }

            #expect(actual == expected)
        }
    }

    @Test("Xoroshiro128Plus's first output is the sum of its two SplitMix64 state words", .tags(.randomized))
    func xoroshiroSeeding() async {
        await propertyCheck(count: 500, input: Gen.uint64()) { seed in
            var seeder = SplitMix64(seed: seed)
            let expected = seeder.next() &+ seeder.next()
            var sut = Xoroshiro128Plus(seed: seed)

            let actual = sut.next()

            #expect(actual == expected)
        }
    }

    @Test("Xoshiro256StarStar's first output is its second SplitMix64 word scrambled", .tags(.randomized))
    func xoshiroSeeding() async {
        await propertyCheck(count: 500, input: Gen.uint64()) { seed in
            var seeder = SplitMix64(seed: seed)
            _ = seeder.next()
            let word = seeder.next() &* 5
            let expected = ((word << 7) | (word >> 57)) &* 9
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.next()

            #expect(actual == expected)
        }
    }

    @Test("Every generator round-trips through Codable from any seed and position", .tags(.randomized, .conformance))
    func codableRoundTrip() async {
        await propertyCheck(count: 200, input: Gen.uint64(), Gen.int(in: 0 ... 5)) { seed, steps in
            var splitMix = SplitMix64(seed: seed)
            var xoroshiro = Xoroshiro128Plus(seed: seed)
            var xoshiro = Xoshiro256StarStar(seed: seed)
            for _ in 0 ..< steps {
                _ = splitMix.next()
                _ = xoroshiro.next()
                _ = xoshiro.next()
            }

            let splitMixBack = try JSONDecoder().decode(SplitMix64.self, from: try JSONEncoder().encode(splitMix))
            let xoroshiroBack = try JSONDecoder().decode(Xoroshiro128Plus.self, from: try JSONEncoder().encode(xoroshiro))
            let xoshiroBack = try JSONDecoder().decode(Xoshiro256StarStar.self, from: try JSONEncoder().encode(xoshiro))

            #expect(splitMixBack == splitMix)
            #expect(xoroshiroBack == xoroshiro)
            #expect(xoshiroBack == xoshiro)
        }
    }

    @Test("Jumping twice is not the same as jumping once, for any seed", .tags(.randomized))
    func jumpsCompose() async {
        await propertyCheck(count: 100, input: Gen.uint64()) { seed in
            let xoroshiro = Xoroshiro128Plus(seed: seed)
            let xoshiro = Xoshiro256StarStar(seed: seed)

            #expect(xoroshiro.jumped() != xoroshiro)
            #expect(xoroshiro.jumped().jumped() != xoroshiro.jumped())
            #expect(xoroshiro.longJumped() != xoroshiro.jumped())
            #expect(xoshiro.jumped() != xoshiro)
            #expect(xoshiro.jumped().jumped() != xoshiro.jumped())
            #expect(xoshiro.longJumped() != xoshiro.jumped())
        }
    }
}
