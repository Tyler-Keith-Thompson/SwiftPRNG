// Each test is self-contained: it builds its own values and states its own expectations.
// Golden values come from the pure-Python reference in scripts/differential_generators.py.

import Foundation
import Generators
import SwiftPRNGTestSupport
import Testing

@Suite("SplitMix64")
struct SplitMix64Tests {
    @Test("The sequence for seed 42 matches the reference implementation", .tags(.fixture))
    func reference() {
        let expected: [UInt64] = [13_679_457_532_755_275_413, 2_949_826_092_126_892_291, 5_139_283_748_462_763_858]
        var sut = SplitMix64(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.next() }

        #expect(actual == expected)
    }

    @Test("Seed zero is as good a seed as any", .tags(.fixture))
    func zeroSeed() {
        let expected: [UInt64] = [16_294_208_416_658_607_535, 7_960_286_522_194_355_700]
        var sut = SplitMix64(seed: 0)

        let actual = [sut.next(), sut.next()]

        #expect(actual == expected)
    }

    @Test("Two generators from one seed agree; different seeds differ")
    func determinism() {
        var first = SplitMix64(seed: 7)
        var second = SplitMix64(seed: 7)
        var third = SplitMix64(seed: 8)

        let firstValues = (0 ..< 10).map { _ in first.next() }
        let secondValues = (0 ..< 10).map { _ in second.next() }
        let thirdValues = (0 ..< 10).map { _ in third.next() }

        #expect(firstValues == secondValues)
        #expect(firstValues != thirdValues)
    }

    @Test("A copy continues from where it was copied, and the original is unaffected", .tags(.copyOnWrite))
    func valueSemantics() {
        var original = SplitMix64(seed: 3)
        _ = original.next()
        var copy = original

        let fromCopy = copy.next()
        let fromOriginal = original.next()

        #expect(fromCopy == fromOriginal)
        #expect(copy == original)
    }

    @Test("Equal generators hash equally", .tags(.conformance))
    func hashing() {
        var advanced = SplitMix64(seed: 5)
        _ = advanced.next()
        var alsoAdvanced = SplitMix64(seed: 5)
        _ = alsoAdvanced.next()

        #expect(advanced == alsoAdvanced)
        #expect(advanced.hashValue == alsoAdvanced.hashValue)
        #expect(advanced != SplitMix64(seed: 5))
    }

    @Test("A generator round-trips through Codable mid-sequence", .tags(.conformance))
    func codable() throws {
        var sut = SplitMix64(seed: 11)
        _ = sut.next()
        var expected = sut

        let data = try JSONEncoder().encode(sut)
        var actual = try JSONDecoder().decode(SplitMix64.self, from: data)

        let actualNext = actual.next()
        let expectedNext = expected.next()
        #expect(actual == expected)
        #expect(actualNext == expectedNext)
    }

    @Test("The sequence wraps at the seed's maximum rather than trapping")
    func wrapsAtMaximum() {
        var sut = SplitMix64(seed: .max)

        let first = sut.next()
        let second = sut.next()

        #expect(first != second)
    }
}
