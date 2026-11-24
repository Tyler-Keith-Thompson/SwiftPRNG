// Property tests against naive references: every draw lands in its range, and the integer
// algorithm written out step by step agrees with the library.

import Generators
import PropertyBased
import Sampling
import SwiftPRNGTestSupport
import Testing

@Suite("Sampling: properties")
struct SamplingPropertyTests {
    @Test("integer(in:) lands in the range and equals the rejection algorithm written out", .tags(.randomized))
    func integerInRange() async {
        let bounds = Gen.int().array(of: 2).map { $0.sorted() }.filter { $0[0] < $0[1] }
        await propertyCheck(count: 500, input: Gen.uint64(), bounds) { seed, bounds in
            let range = bounds[0] ..< bounds[1]
            var reference = Xoshiro256StarStar(seed: seed)
            let lower = UInt64(bitPattern: Int64(range.lowerBound))
            let width = UInt64(bitPattern: Int64(range.upperBound)) &- lower
            let threshold = (0 &- width) % width
            var draw = reference.next()
            while draw < threshold { draw = reference.next() }
            let expected = Int(truncatingIfNeeded: lower &+ draw % width)
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.integer(in: range)

            #expect(actual == expected)
            #expect(range.contains(actual))
        }
    }

    @Test("integer(in:) over a closed range lands in it", .tags(.randomized))
    func closedIntegerInRange() async {
        let bounds = Gen.int().array(of: 2).map { $0.sorted() }
        await propertyCheck(count: 500, input: Gen.uint64(), bounds) { seed, bounds in
            let range = bounds[0] ... bounds[1]
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.integer(in: range)

            #expect(range.contains(actual))
        }
    }

    @Test("uniform() lies in [0, 1) and is a multiple of 2⁻⁵³", .tags(.randomized))
    func uniformInUnit() async {
        await propertyCheck(count: 500, input: Gen.uint64()) { seed in
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.uniform()

            #expect(actual >= 0 && actual < 1)
            #expect((actual * 0x1.0p53).rounded() == actual * 0x1.0p53)
        }
    }

    @Test("uniform(in:) lies in the range for any finite increasing bounds", .tags(.randomized))
    func uniformInRange() async {
        let bounds = Gen.double(in: -1e300 ... 1e300).array(of: 2).map { $0.sorted() }.filter { $0[0] < $0[1] }
        await propertyCheck(count: 500, input: Gen.uint64(), bounds) { seed, bounds in
            let range = bounds[0] ..< bounds[1]
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.uniform(in: range)

            #expect(range.contains(actual))
        }
    }

    @Test("bernoulli(_:) is the unit draw compared with the probability", .tags(.randomized))
    func bernoulliReference() async {
        await propertyCheck(count: 500, input: Gen.uint64(), Gen.double(in: 0 ... 1)) { seed, probability in
            var reference = Xoshiro256StarStar(seed: seed)
            let expected = reference.uniform() < probability
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.bernoulli(probability)

            #expect(actual == expected)
        }
    }

    @Test("shuffle(_:) equals Fisher-Yates written out and leaves the generator where it does", .tags(.randomized))
    func shuffleReference() async {
        await propertyCheck(count: 300, input: Gen.uint64(), Gen.int(in: 0 ... 200)) { seed, count in
            var expected = Array(0 ..< count)
            var reference = Xoshiro256StarStar(seed: seed)
            var i = count - 1
            while i > 0 {
                let j = reference.integer(in: 0 ... i)
                let held = expected[i]
                expected[i] = expected[j]
                expected[j] = held
                i -= 1
            }
            var actual = Array(0 ..< count)
            var sut = Xoshiro256StarStar(seed: seed)

            sut.shuffle(&actual)

            #expect(actual == expected)
            #expect(sut == reference)
            #expect(actual.sorted() == Array(0 ..< count))
        }
    }

    @Test("shuffled(_:) is a permutation equal to shuffle(_:) on the array", .tags(.randomized))
    func shuffledReference() async {
        await propertyCheck(count: 300, input: Gen.uint64(), Gen.int(in: 0 ... 200)) { seed, count in
            var expected = Array(0 ..< count)
            var reference = Xoshiro256StarStar(seed: seed)
            reference.shuffle(&expected)
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.shuffled((0 ..< count).lazy.map { $0 })

            #expect(actual == expected)
            #expect(sut == reference)
        }
    }

    @Test("element(in:) is the element at one integer draw's offset, and nil without a draw when empty", .tags(.randomized))
    func elementReference() async {
        await propertyCheck(count: 500, input: Gen.uint64(), Gen.int(in: 0 ... 1_000)) { seed, count in
            let elements = Array(0 ..< count).map { $0 * 3 }
            var reference = Xoshiro256StarStar(seed: seed)
            let expected = count == 0 ? nil : elements[reference.integer(in: 0 ..< count)]
            var sut = Xoshiro256StarStar(seed: seed)

            let actual = sut.element(in: elements)

            #expect(actual == expected)
            #expect(sut == reference)
        }
    }

    @Test("Over many shuffles every permutation of three elements appears about equally often", .tags(.randomized))
    func shuffleFrequencies() {
        var sut = Xoshiro256StarStar(seed: 2024)
        var counts: [[Int]: Int] = [:]
        let shuffles = 60_000

        for _ in 0 ..< shuffles { counts[sut.shuffled([0, 1, 2]), default: 0] += 1 }

        // Each count is binomial with mean 10,000 and standard deviation about 91.
        #expect(counts.count == 6)
        #expect(counts.values.allSatisfy { abs($0 - 10_000) < 500 })
    }

    @Test("Over many draws every value of a small range appears about equally often", .tags(.randomized))
    func integerFrequencies() {
        var sut = Xoshiro256StarStar(seed: 2024)
        var counts = [Int](repeating: 0, count: 7)
        let draws = 70_000

        for _ in 0 ..< draws { counts[sut.integer(in: -3 ..< 4) + 3] += 1 }

        // Each count is binomial with mean 10,000 and standard deviation about 93.
        #expect(counts.allSatisfy { abs($0 - 10_000) < 500 })
    }
}
