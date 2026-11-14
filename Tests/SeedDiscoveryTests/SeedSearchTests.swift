// Each test is self-contained. Golden values come from scripts/differential_sampling.py's
// reference over the Xoshiro256StarStar sequence: seed 1774 is the first whose uniform draw
// exceeds 0.999, and 93 of the seeds below 1000 draw above 0.9.

import Generators
import SeedDiscovery
import SwiftPRNGTestSupport
import Testing

@Suite("SeedSearch")
struct SeedSearchTests {
    @Test("first(where:) returns the smallest seed the predicate accepts", .tags(.fixture))
    func firstMatch() {
        let expected: UInt64 = 1774
        let sut = SeedSearch(0 ..< 100_000)

        let actual = sut.first { seed in
            var generator = Xoshiro256StarStar(seed: seed)
            return Double(generator.next() >> 11) * 0x1.0p-53 > 0.999
        }

        #expect(actual == expected)
    }

    @Test("first(where:) is nil when no seed in the range matches")
    func noMatch() {
        let sut = SeedSearch(0 ..< 100)

        #expect(sut.first { _ in false } == nil)
    }

    @Test("first(where:) over an empty range is nil without calling the predicate")
    func emptyRange() {
        let sut = SeedSearch(10 ..< 10)
        var calls = 0

        let actual = sut.first { _ in
            calls += 1
            return true
        }

        #expect(actual == nil)
        #expect(calls == 0)
    }

    @Test("first(where:) stops at the match")
    func stopsAtMatch() {
        let sut = SeedSearch(0 ..< 1000)
        var tried: [UInt64] = []

        let actual = sut.first { seed in
            tried.append(seed)
            return seed == 3
        }

        #expect(actual == 3)
        #expect(tried == [0, 1, 2, 3])
    }

    @Test("first(where:) searches from the range's lower bound and reaches its last seed")
    func bounds() {
        let sut = SeedSearch(5 ..< 8)

        #expect(sut.first { _ in true } == 5)
        #expect(sut.first { $0 == 7 } == 7)
        #expect(sut.first { $0 == 8 } == nil)
    }

    @Test("first(where:) searches up to the top of the seed space")
    func topOfSeedSpace() {
        let sut = SeedSearch(UInt64.max - 2 ..< UInt64.max)
        let expected = UInt64.max - 1

        let actual = sut.first { seed in seed == expected }
        let beyond = sut.first { seed in seed == UInt64.max }

        #expect(actual == expected)
        #expect(beyond == nil)
    }

    @Test("first(where:) rethrows the predicate's typed error")
    func rethrowsTypedError() {
        struct Stop: Error, Equatable {}
        let sut = SeedSearch(0 ..< 10)

        func search() throws(Stop) -> UInt64? {
            try sut.first { (seed) throws(Stop) in
                if seed == 2 { throw Stop() }
                return false
            }
        }

        #expect(throws: Stop()) { try search() }
    }

    @Test("count(where:) is the number of matching seeds: how rare a property is", .tags(.fixture))
    func count() {
        let expected = 93
        let sut = SeedSearch(0 ..< 1000)

        let actual = sut.count { seed in
            var generator = Xoshiro256StarStar(seed: seed)
            return Double(generator.next() >> 11) * 0x1.0p-53 > 0.9
        }

        #expect(actual == expected)
        #expect(sut.count { _ in true } == 1000)
        #expect(sut.count { _ in false } == 0)
        #expect(SeedSearch(3 ..< 3).count { _ in true } == 0)
    }

    @Test("A search is a value: equal ranges are equal searches", .tags(.conformance))
    func equality() {
        let sut = SeedSearch(0 ..< 10)

        #expect(sut == SeedSearch(0 ..< 10))
        #expect(sut.hashValue == SeedSearch(0 ..< 10).hashValue)
        #expect(sut != SeedSearch(0 ..< 11))
        #expect(sut.seeds == 0 ..< 10)
    }

    @Test("concurrent() keeps the seeds and takes the workers and batch size")
    func concurrentSpelling() {
        let sut = SeedSearch(0 ..< 10)

        let concurrent = sut.concurrent(workers: 3, batchSize: 4)

        #expect(concurrent.seeds == 0 ..< 10)
        #expect(concurrent.workers == 3)
        #expect(concurrent.batchSize == 4)
        #expect(sut.concurrent().workers == ConcurrentSeedSearch.defaultWorkers)
        #expect(sut.concurrent().batchSize == 1024)
        #expect(ConcurrentSeedSearch.defaultWorkers >= 1)
    }
}
