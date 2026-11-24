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

    @Test("integer(in:) rejects a first draw below the width and below the threshold, then accepts the next")
    func rejectionBelowWidth() {
        // Width 10 leaves 2⁶⁴ mod 10 = 6 values to reject: 3 is below both the width and the
        // threshold, so it is drawn again; 17 is accepted and gives 17 % 10.
        let range: Range<Int> = 0 ..< 10
        let expected = 7
        let expectedRemaining: [UInt64] = [99]
        var sut = ScriptedGenerator(values: [3, 17, 99])

        let actual = sut.integer(in: range)

        #expect(actual == expected)
        #expect(sut.values == expectedRemaining)
    }

    @Test("integer(in:) accepts a first draw below the width but not below the threshold, in one draw")
    func acceptanceBelowWidth() {
        // Width 10 rejects draws below 2⁶⁴ mod 10 = 6; 8 is below the width but not the threshold.
        let range: Range<Int> = 0 ..< 10
        let expected = 8
        let expectedRemaining: [UInt64] = [99]
        var sut = ScriptedGenerator(values: [8, 99])

        let actual = sut.integer(in: range)

        #expect(actual == expected)
        #expect(sut.values == expectedRemaining)
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

    @Test("shuffle(_:) for seed 42 matches the reference and takes n - 1 draws", .tags(.fixture))
    func shuffleReference() {
        let expected = [7, 3, 8, 9, 5, 6, 4, 1, 0, 2]
        let expectedNext: UInt64 = 10_760_895_422_300_929_085  // the tenth output: nine draws taken
        var elements = Array(0 ..< 10)
        var sut = Xoshiro256StarStar(seed: 42)

        sut.shuffle(&elements)

        #expect(elements == expected)
        #expect(sut.next() == expectedNext)
    }

    @Test("shuffle(_:) of 52 elements for seed 42 matches the reference", .tags(.fixture))
    func shuffleDeckReference() {
        let expected = [
            26, 19, 32, 28, 12, 44, 46, 15, 3, 24, 38, 45, 1, 10, 14, 43, 11, 23, 5, 40, 21, 17, 7, 31, 29, 51,
            34, 20, 39, 33, 41, 50, 16, 35, 6, 49, 18, 37, 47, 30, 8, 13, 0, 22, 42, 36, 27, 4, 25, 9, 48, 2,
        ]
        let expectedNext: UInt64 = 5_856_491_322_825_941_228
        var elements = Array(0 ..< 52)
        var sut = Xoshiro256StarStar(seed: 42)

        sut.shuffle(&elements)

        #expect(elements == expected)
        #expect(sut.next() == expectedNext)
    }

    @Test("shuffle(_:) is Fisher-Yates from the last index down over integer(in:)")
    func shuffleIsFisherYates() {
        var expected = Array(0 ..< 52)
        var reference = Xoshiro256StarStar(seed: 7)
        for i in stride(from: expected.count - 1, to: 0, by: -1) { expected.swapAt(i, reference.integer(in: 0 ... i)) }
        var actual = Array(0 ..< 52)
        var sut = Xoshiro256StarStar(seed: 7)

        sut.shuffle(&actual)

        #expect(actual == expected)
        #expect(sut == reference)
    }

    @Test("shuffle(_:) of an empty or one-element collection takes no draw")
    func shuffleTrivial() {
        let expected = Xoshiro256StarStar(seed: 42)
        let expectedEmpty: [Int] = []
        let expectedSingle = [9]
        var actualEmpty: [Int] = []
        var actualSingle = [9]
        var sut = Xoshiro256StarStar(seed: 42)

        sut.shuffle(&actualEmpty)
        sut.shuffle(&actualSingle)

        #expect(actualEmpty == expectedEmpty)
        #expect(actualSingle == expectedSingle)
        #expect(sut == expected)
    }

    @Test("shuffle(_:) of two elements takes one draw", .tags(.fixture))
    func shuffleTwo() {
        let expected = ["b", "a"]
        let expectedNext: UInt64 = 6_990_951_692_964_543_102  // the second output
        var elements = ["a", "b"]
        var sut = Xoshiro256StarStar(seed: 42)

        sut.shuffle(&elements)

        #expect(elements == expected)
        #expect(sut.next() == expectedNext)
    }

    @Test("shuffle(_:) counts offsets from a slice's start and leaves the rest alone")
    func shuffleSlice() {
        var whole = Array(0 ..< 20)
        var expectedMiddle = Array(5 ..< 15)
        var reference = Xoshiro256StarStar(seed: 42)
        reference.shuffle(&expectedMiddle)
        var sut = Xoshiro256StarStar(seed: 42)

        sut.shuffle(&whole[5 ..< 15])

        #expect(Array(whole[5 ..< 15]) == expectedMiddle)
        #expect(Array(whole[..<5]) == Array(0 ..< 5))
        #expect(Array(whole[15...]) == Array(15 ..< 20))
        #expect(sut == reference)
    }

    @Test("shuffle(_:) draws through integer(in:)'s rejection")
    func shuffleRejects() {
        // Offset 2 draws below 3: 2⁶⁴ mod 3 = 1 rejects the 0, and 5 picks offset 2. Offset 1 then
        // draws below 2 from the generator's 0, swapping the first two.
        let expected = ["b", "a", "c"]
        var actual = ["a", "b", "c"]
        var sut = ScriptedGenerator(values: [0, 5])

        sut.shuffle(&actual)

        #expect(actual == expected)
        #expect(sut.values.isEmpty)
    }

    @Test("shuffled(_:) returns what shuffle(_:) leaves, with the same draws", .tags(.fixture))
    func shuffledReference() {
        let expected = [7, 3, 8, 9, 5, 6, 4, 1, 0, 2]
        let expectedNext: UInt64 = 10_760_895_422_300_929_085
        var sut = Xoshiro256StarStar(seed: 42)

        let actual = sut.shuffled(0 ..< 10)

        #expect(actual == expected)
        #expect(sut.next() == expectedNext)
    }

    @Test("shuffled(_:) of an empty or one-element sequence takes no draw")
    func shuffledTrivial() {
        let expected = Xoshiro256StarStar(seed: 42)
        let expectedEmpty: [Int] = []
        let expectedSingle = ["x"]
        var sut = Xoshiro256StarStar(seed: 42)

        let actualEmpty = sut.shuffled([Int]())
        let actualSingle = sut.shuffled(CollectionOfOne("x"))

        #expect(actualEmpty == expectedEmpty)
        #expect(actualSingle == expectedSingle)
        #expect(sut == expected)
    }

    @Test("element(in:) for seed 42 matches the reference and takes one draw", .tags(.fixture))
    func elementReference() {
        let expected = 2
        let expectedNext: UInt64 = 6_990_951_692_964_543_102  // the second output
        var sut = Xoshiro256StarStar(seed: 42)

        let actual = sut.element(in: 0 ..< 10)

        #expect(actual == expected)
        #expect(sut.next() == expectedNext)
    }

    @Test("element(in:) of an empty collection is nil and takes no draw")
    func elementEmpty() {
        let expected = Xoshiro256StarStar(seed: 42)
        var sut = Xoshiro256StarStar(seed: 42)

        let actual = sut.element(in: [Int]())

        #expect(actual == nil)
        #expect(sut == expected)
    }

    @Test("element(in:) of one element returns it and takes one draw")
    func elementSingle() {
        let expected = "only"
        let expectedDraws = 1
        var sut = CountingGenerator()

        let actual = sut.element(in: ["only"])

        #expect(actual == expected)
        #expect(sut.draws == expectedDraws)
    }

    @Test("element(in:) counts the offset from the start of a slice and of a String")
    func elementOffsets() {
        // Seed 42's offset below 10 is 2.
        let expectedLetter: Character = "c"
        let expectedNumber = 112
        let letters = "abcdefghij"
        let numbers = Array(100 ..< 120)
        var fromString = Xoshiro256StarStar(seed: 42)
        var fromSlice = Xoshiro256StarStar(seed: 42)

        let actualLetter = fromString.element(in: letters)
        let actualNumber = fromSlice.element(in: numbers[10 ..< 20])

        #expect(actualLetter == expectedLetter)
        #expect(actualNumber == expectedNumber)
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
