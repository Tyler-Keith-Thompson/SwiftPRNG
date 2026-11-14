// Golden values come from the pure-Python reference in scripts/differential_generators.py; the
// jumped values come from its transition matrix raised to 2¹²⁸ and 2¹⁹² by squaring.

import Foundation
import Generators
import SwiftPRNGTestSupport
import Testing

@Suite("Xoshiro256StarStar")
struct Xoshiro256StarStarTests {
    @Test("The sequence for seed 42 matches the reference implementation", .tags(.fixture))
    func reference() {
        let expected: [UInt64] = [1_546_998_764_402_558_742, 6_990_951_692_964_543_102, 12_544_586_762_248_559_009]
        var sut = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.next() }

        #expect(actual == expected)
    }

    @Test("The sequence for seed 1 matches the reference implementation", .tags(.fixture))
    func referenceSeedOne() {
        let expected: [UInt64] = [12_966_619_160_104_079_557, 9_600_361_134_598_540_522]
        var sut = Xoshiro256StarStar(seed: 1)

        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("The state is the first four SplitMix64 words of the seed", .tags(.conformance))
    func seeding() throws {
        var seeder = SplitMix64(seed: 42)
        let expected = (0 ..< 4).map { _ in seeder.next() }
        let sut = Xoshiro256StarStar(seed: 42)

        let encoded = try JSONDecoder().decode([String: [UInt64]].self, from: try JSONEncoder().encode(sut))

        #expect(encoded["state"] == expected)
    }

    @Test("jump() lands 2¹²⁸ steps on, where the transition matrix says", .tags(.fixture))
    func jump() {
        let expected: [UInt64] = [5_766_981_335_298_035_530, 13_414_075_677_763_163_907]
        var sut = Xoshiro256StarStar(seed: 42)

        sut.jump()
        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("longJump() lands 2¹⁹² steps on, where the transition matrix says", .tags(.fixture))
    func longJump() {
        let expected: [UInt64] = [11_575_600_654_643_926_073, 12_220_922_501_490_792_721]
        var sut = Xoshiro256StarStar(seed: 42)

        sut.longJump()
        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("jumped() and longJumped() return what jump() and longJump() leave behind")
    func jumpedSpellings() {
        var jumped = Xoshiro256StarStar(seed: 9)
        jumped.jump()
        var longJumped = Xoshiro256StarStar(seed: 9)
        longJumped.longJump()
        let sut = Xoshiro256StarStar(seed: 9)

        #expect(sut.jumped() == jumped)
        #expect(sut.longJumped() == longJumped)
        #expect(sut == Xoshiro256StarStar(seed: 9))
    }

    @Test("Jumped streams differ from each other and from the original")
    func jumpedStreamsDiffer() {
        var sut = Xoshiro256StarStar(seed: 42)
        var streams: [Xoshiro256StarStar] = []
        for _ in 0 ..< 4 {
            streams.append(sut)
            sut.jump()
        }

        let firstValues = streams.map { var stream = $0; return stream.next() }

        #expect(Set(firstValues).count == 4)
        #expect(Set(streams).count == 4)
    }

    @Test("A copy continues from where it was copied, and the original is unaffected", .tags(.copyOnWrite))
    func valueSemantics() {
        var original = Xoshiro256StarStar(seed: 3)
        _ = original.next()
        var copy = original

        let fromCopy = copy.next()
        let fromOriginal = original.next()

        #expect(fromCopy == fromOriginal)
        #expect(copy == original)
    }

    @Test("Equal generators hash equally", .tags(.conformance))
    func hashing() {
        var advanced = Xoshiro256StarStar(seed: 5)
        _ = advanced.next()
        var alsoAdvanced = Xoshiro256StarStar(seed: 5)
        _ = alsoAdvanced.next()

        #expect(advanced == alsoAdvanced)
        #expect(advanced.hashValue == alsoAdvanced.hashValue)
        #expect(advanced != Xoshiro256StarStar(seed: 5))
    }

    @Test("A generator round-trips through Codable mid-sequence", .tags(.conformance))
    func codable() throws {
        var sut = Xoshiro256StarStar(seed: 11)
        _ = sut.next()
        var expected = sut

        let data = try JSONEncoder().encode(sut)
        var actual = try JSONDecoder().decode(Xoshiro256StarStar.self, from: data)

        let actualNext = actual.next()
        let expectedNext = expected.next()
        #expect(actual == expected)
        #expect(actualNext == expectedNext)
    }

    @Test("Decoding rejects an all-zero state and the wrong number of words")
    func decodingRejectsBadState() {
        let zero = Data("{\"state\":[0,0,0,0]}".utf8)
        let short = Data("{\"state\":[1,2]}".utf8)
        let long = Data("{\"state\":[1,2,3,4,5]}".utf8)

        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoshiro256StarStar.self, from: zero) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoshiro256StarStar.self, from: short) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoshiro256StarStar.self, from: long) }
    }

    @Test("Decoding accepts a state with zero words among nonzero ones")
    func decodingAcceptsSomeZeros() throws {
        let data = Data("{\"state\":[0,1,0,0]}".utf8)

        var actual = try JSONDecoder().decode(Xoshiro256StarStar.self, from: data)

        // rotl(1 * 5, 7) * 9
        let first = actual.next()
        #expect(first == 5760)
    }

    @Test("It drives the standard library's randomness API")
    func standardLibrary() {
        var sut = Xoshiro256StarStar(seed: 42)
        var again = Xoshiro256StarStar(seed: 42)

        let shuffled = Array(1 ... 10).shuffled(using: &sut)
        let shuffledAgain = Array(1 ... 10).shuffled(using: &again)

        #expect(shuffled == shuffledAgain)
        #expect(shuffled.sorted() == Array(1 ... 10))
    }
}
