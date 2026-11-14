// Each test is self-contained. Golden values come from scripts/differential_sampling.py over the
// Xoshiro256StarStar sequence for seed 42.

import Generators
import Sampling
import SwiftPRNGTestSupport
import Testing

@Suite("Sampling: hand-worked cases")
struct SamplingTests {
    @Test("uniform() scales the top 53 bits of one draw into [0, 1)", .tags(.fixture))
    func uniformReference() {
        let expected = 0.08386297105988216
        var sut = Xoshiro256StarStar(seed: 42)

        let actual = sut.uniform()

        #expect(actual == expected)
    }

    @Test("uniform() is the first draw's top bits exactly")
    func uniformIsTopBits() {
        var reference = Xoshiro256StarStar(seed: 3)
        let expected = Double(reference.next() >> 11) * 0x1.0p-53
        var sut = Xoshiro256StarStar(seed: 3)

        let actual = sut.uniform()

        #expect(actual == expected)
    }

    @Test("uniform() from an all-ones draw is just below one")
    func uniformUpperEnd() {
        var sut = ConstantGenerator(value: .max)

        let actual = sut.uniform()

        #expect(actual == 1.0.nextDown)
        #expect(actual < 1)
    }

    @Test("uniform() from a zero draw is zero")
    func uniformLowerEnd() {
        var sut = ConstantGenerator(value: 0)

        let actual = sut.uniform()

        #expect(actual == 0)
    }

    @Test("integer(in:) for seed 42 matches the reference", .tags(.fixture))
    func integerReference() {
        var sut = Xoshiro256StarStar(seed: 42)
        var crossingZero = Xoshiro256StarStar(seed: 42)

        let actual = sut.integer(in: 0 ..< 10)
        let actualCrossingZero = crossingZero.integer(in: -5 ..< 5)

        #expect(actual == 2)
        #expect(actualCrossingZero == -3)
    }

    @Test("integer(in:) over a range of one value returns it without drawing")
    func integerSingleValue() {
        var sut = CountingGenerator()

        let actual = sut.integer(in: 7 ..< 8)

        #expect(actual == 7)
        #expect(sut.draws == 1)
    }

    @Test("integer(in:) stays inside ranges at the edges of Int")
    func integerExtremes() {
        var sut = Xoshiro256StarStar(seed: 1)

        for _ in 0 ..< 100 {
            let low = sut.integer(in: Int.min ..< Int.min + 3)
            let high = sut.integer(in: Int.max - 3 ..< Int.max)
            let wide = sut.integer(in: Int.min ..< Int.max)
            #expect((Int.min ..< Int.min + 3).contains(low))
            #expect((Int.max - 3 ..< Int.max).contains(high))
            #expect((Int.min ..< Int.max).contains(wide))
        }
    }

    @Test("integer(in:) over a closed range includes both bounds and the whole Int domain")
    func closedRange() {
        var sut = Xoshiro256StarStar(seed: 42)
        var whole = Xoshiro256StarStar(seed: 42)
        var reference = Xoshiro256StarStar(seed: 42)
        let expectedWhole = Int(truncatingIfNeeded: reference.next())

        let seen = Set((0 ..< 200).map { _ in sut.integer(in: 0 ... 3) })
        let actualWhole = whole.integer(in: Int.min ... Int.max)
        let single = sut.integer(in: 5 ... 5)

        #expect(seen == [0, 1, 2, 3])
        // The whole domain is one raw draw only where Int has 64 bits; a 32-bit Int takes the general path.
        if Int.bitWidth == 64 {
            #expect(actualWhole == expectedWhole)
        }
        #expect(single == 5)
    }

    @Test("integer(in:) rejects draws below the threshold, so every value is equally likely")
    func rejection() {
        // Width 3 leaves 2⁶⁴ mod 3 = 1 value to reject: a draw of 0 is drawn again.
        var sut = ScriptedGenerator(values: [0, 5])

        let actual = sut.integer(in: 0 ..< 3)

        #expect(actual == 2)
        #expect(sut.values.isEmpty)
    }

    @Test("integer(checkedIn:) throws EmptyRange for an empty range and agrees otherwise")
    func checkedInteger() throws {
        var sut = Xoshiro256StarStar(seed: 42)
        var plain = Xoshiro256StarStar(seed: 42)

        #expect(throws: EmptyRange()) { try sut.integer(checkedIn: 3 ..< 3) }
        let checked = try sut.integer(checkedIn: 0 ..< 10)
        let expected = plain.integer(in: 0 ..< 10)
        #expect(checked == expected)
    }

    @Test("uniform(in:) maps the unit draw onto the range and never reaches the upper bound")
    func uniformInRange() {
        var sut = Xoshiro256StarStar(seed: 42)
        var top = ConstantGenerator(value: .max)
        var bottom = ConstantGenerator(value: 0)
        let expected = 10 + 0.08386297105988216 * 10

        let actual = sut.uniform(in: 10 ..< 20)
        let fromTop = top.uniform(in: 10 ..< 20)
        let fromBottom = bottom.uniform(in: 10 ..< 20)

        #expect(actual == expected)
        #expect(fromTop == 20.0.nextDown)
        #expect(fromBottom == 10)
    }

    @Test("uniform(in:) clamps the top draw back inside the range where rounding would reach the upper bound")
    func uniformClampsRounding() {
        // (1 - unit) * 1 + unit * 2 with unit = 1 - 2⁻⁵³ rounds to exactly 2 in floating point.
        var sut = ConstantGenerator(value: .max)
        let expected = 2.0.nextDown

        let actual = sut.uniform(in: 1 ..< 2)

        #expect(actual == expected)
        #expect(actual < 2)
    }

    @Test("uniform(in:) handles bounds whose difference overflows")
    func uniformOverflowingBounds() {
        var sut = Xoshiro256StarStar(seed: 42)
        let range = -Double.greatestFiniteMagnitude ..< Double.greatestFiniteMagnitude

        let actual = sut.uniform(in: range)

        #expect(actual.isFinite)
        #expect(range.contains(actual))
    }

    @Test("uniform(checkedIn:) throws InvalidInterval for empty or non-finite bounds")
    func checkedUniform() throws {
        var sut = Xoshiro256StarStar(seed: 42)
        var plain = Xoshiro256StarStar(seed: 42)

        #expect(throws: InvalidInterval()) { try sut.uniform(checkedIn: 2 ..< 2) }
        #expect(throws: InvalidInterval()) { try sut.uniform(checkedIn: 0 ..< .infinity) }
        #expect(throws: InvalidInterval()) { try sut.uniform(checkedIn: -.infinity ..< 0) }
        let checked = try sut.uniform(checkedIn: 1 ..< 2)
        let expected = plain.uniform(in: 1 ..< 2)
        #expect(checked == expected)
    }

    @Test("bernoulli(_:) succeeds when the unit draw falls below the probability")
    func bernoulli() {
        var sut = Xoshiro256StarStar(seed: 42)  // uniform 0.0838…
        var again = Xoshiro256StarStar(seed: 42)

        let likely = sut.bernoulli(0.1)
        let unlikely = again.bernoulli(0.05)

        #expect(likely)
        #expect(!unlikely)
    }

    @Test("A probability of zero never succeeds and one always does")
    func bernoulliEnds() {
        var zeroDraw = ConstantGenerator(value: 0)
        var topDraw = ConstantGenerator(value: .max)

        let never = zeroDraw.bernoulli(0)
        let always = topDraw.bernoulli(1)

        #expect(!never)
        #expect(always)
    }

    @Test("bernoulli(checked:) throws InvalidProbability outside 0 ... 1, including NaN")
    func checkedBernoulli() throws {
        var sut = Xoshiro256StarStar(seed: 42)
        var plain = Xoshiro256StarStar(seed: 42)

        #expect(throws: InvalidProbability()) { try sut.bernoulli(checked: -0.1) }
        #expect(throws: InvalidProbability()) { try sut.bernoulli(checked: 1.1) }
        #expect(throws: InvalidProbability()) { try sut.bernoulli(checked: .nan) }
        let checked = try sut.bernoulli(checked: 0.5)
        let expected = plain.bernoulli(0.5)
        #expect(checked == expected)
    }
}

/// A generator that always returns one value.
private struct ConstantGenerator: RandomNumberGenerator {
    var value: UInt64
    mutating func next() -> UInt64 { value }
}

/// A generator that returns its values in order, then zero.
private struct ScriptedGenerator: RandomNumberGenerator {
    var values: [UInt64]
    mutating func next() -> UInt64 { values.isEmpty ? 0 : values.removeFirst() }
}

/// A generator that counts its draws.
private struct CountingGenerator: RandomNumberGenerator {
    var draws = 0
    mutating func next() -> UInt64 {
        draws += 1
        return UInt64(draws)
    }
}
