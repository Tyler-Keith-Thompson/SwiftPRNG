// Golden values come from the pure-Python reference in scripts/differential_generators.py; the
// jumped values come from its transition matrix raised to 2⁶⁴ and 2⁹⁶ by squaring, a different
// method from the jump polynomials the library uses.

import Foundation
import Generators
import SwiftPRNGTestSupport
import Testing

@Suite("Xoroshiro128Plus")
struct Xoroshiro128PlusTests {
    @Test("The sequence for seed 42 matches the reference implementation", .tags(.fixture))
    func reference() {
        let expected: [UInt64] = [16_629_283_624_882_167_704, 14_158_568_844_310_674_298, 4_169_932_037_010_132_216]
        var sut = Xoroshiro128Plus(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.next() }

        #expect(actual == expected)
    }

    @Test("The sequence for seed 1 matches the reference implementation", .tags(.fixture))
    func referenceSeedOne() {
        let expected: [UInt64] = [5_761_717_516_557_699_368, 17_295_345_234_682_295_910]
        var sut = Xoroshiro128Plus(seed: 1)

        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("The state is both SplitMix64 words of the seed")
    func seeding() {
        var seeder = SplitMix64(seed: 42)
        let state0 = seeder.next()
        let state1 = seeder.next()
        let expected = state0 &+ state1
        var sut = Xoroshiro128Plus(seed: 42)

        let actual = sut.next()

        #expect(actual == expected)
    }

    @Test("jump() lands 2⁶⁴ steps on, where the transition matrix says", .tags(.fixture))
    func jump() {
        let expected: [UInt64] = [3_318_364_113_193_366_008, 3_514_532_291_771_507_262]
        var sut = Xoroshiro128Plus(seed: 42)

        sut.jump()
        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("longJump() lands 2⁹⁶ steps on, where the transition matrix says", .tags(.fixture))
    func longJump() {
        let expected: [UInt64] = [15_461_945_471_883_497_906, 3_646_316_638_641_052_783]
        var sut = Xoroshiro128Plus(seed: 42)

        sut.longJump()
        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("jumped() and longJumped() return what jump() and longJump() leave behind")
    func jumpedSpellings() {
        var jumped = Xoroshiro128Plus(seed: 9)
        jumped.jump()
        var longJumped = Xoroshiro128Plus(seed: 9)
        longJumped.longJump()
        let sut = Xoroshiro128Plus(seed: 9)

        #expect(sut.jumped() == jumped)
        #expect(sut.longJumped() == longJumped)
        #expect(sut == Xoroshiro128Plus(seed: 9))
    }

    @Test("Jumped streams differ from each other and from the original")
    func jumpedStreamsDiffer() {
        var sut = Xoroshiro128Plus(seed: 42)
        var streams: [Xoroshiro128Plus] = []
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
        var original = Xoroshiro128Plus(seed: 3)
        _ = original.next()
        var copy = original

        let fromCopy = copy.next()
        let fromOriginal = original.next()

        #expect(fromCopy == fromOriginal)
        #expect(copy == original)
    }

    @Test("Equal generators hash equally", .tags(.conformance))
    func hashing() {
        var advanced = Xoroshiro128Plus(seed: 5)
        _ = advanced.next()
        var alsoAdvanced = Xoroshiro128Plus(seed: 5)
        _ = alsoAdvanced.next()

        #expect(advanced == alsoAdvanced)
        #expect(advanced.hashValue == alsoAdvanced.hashValue)
        #expect(advanced != Xoroshiro128Plus(seed: 5))
    }

    @Test("A generator round-trips through Codable mid-sequence", .tags(.conformance))
    func codable() throws {
        var sut = Xoroshiro128Plus(seed: 11)
        _ = sut.next()
        var expected = sut

        let data = try JSONEncoder().encode(sut)
        var actual = try JSONDecoder().decode(Xoroshiro128Plus.self, from: data)

        let actualNext = actual.next()
        let expectedNext = expected.next()
        #expect(actual == expected)
        #expect(actualNext == expectedNext)
    }

    @Test("The encoding is the two state words", .tags(.conformance))
    func encoding() throws {
        let sut = Xoroshiro128Plus(seed: 42)
        let expected = "{\"state\":[13679457532755275413,2949826092126892291]}"

        let actual = String(decoding: try JSONEncoder().encode(sut), as: UTF8.self)

        #expect(actual == expected)
    }

    @Test("Decoding rejects an all-zero state and the wrong number of words")
    func decodingRejectsBadState() {
        let zero = Data("{\"state\":[0,0]}".utf8)
        let short = Data("{\"state\":[1]}".utf8)
        let long = Data("{\"state\":[1,2,3]}".utf8)

        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoroshiro128Plus.self, from: zero) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoroshiro128Plus.self, from: short) }
        #expect(throws: DecodingError.self) { try JSONDecoder().decode(Xoroshiro128Plus.self, from: long) }
    }

    @Test("Decoding accepts a state with one zero word")
    func decodingAcceptsOneZero() throws {
        let data = Data("{\"state\":[0,1]}".utf8)

        var actual = try JSONDecoder().decode(Xoroshiro128Plus.self, from: data)

        let first = actual.next()
        #expect(first == 1)
    }

    @Test("It drives the standard library's randomness API")
    func standardLibrary() {
        var sut = Xoroshiro128Plus(seed: 42)
        var again = Xoroshiro128Plus(seed: 42)

        let shuffled = Array(1 ... 10).shuffled(using: &sut)
        let shuffledAgain = Array(1 ... 10).shuffled(using: &again)

        #expect(shuffled == shuffledAgain)
        #expect(shuffled.sorted() == Array(1 ... 10))
    }
}
