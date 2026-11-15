// The concurrent search must find exactly what the sequential one finds, whatever the batch size
// and worker count, and whichever batch finishes first.

import Generators
import SeedDiscovery
import SwiftPRNGTestSupport
import Synchronization
import Testing

@Suite("ConcurrentSeedSearch", .timeLimit(.minutes(1)))
struct ConcurrentSeedSearchTests {
    @Test("first(where:) finds the same smallest seed as the sequential search", .tags(.fixture))
    func agreesWithSequential() async {
        let expected: UInt64 = 1774
        let sut = SeedSearch(0 ..< 100_000).concurrent(workers: 4, batchSize: 100)

        let actual = await sut.first { seed in
            var generator = Xoshiro256StarStar(seed: seed)
            return Double(generator.next() >> 11) * 0x1.0p-53 > 0.999
        }

        #expect(actual == expected)
    }

    @Test("A later batch finishing first does not win over an earlier match")
    func earliestBatchWins() async {
        // Batches of one seed; the batch holding seed 1 is slow, seed 5 matches at once.
        let sut = SeedSearch(0 ..< 100).concurrent(workers: 8, batchSize: 1)

        let actual = await sut.first { seed in
            if seed == 1 {
                var spin = Xoshiro256StarStar(seed: 0)
                for _ in 0 ..< 200_000 { _ = spin.next() }
                return true
            }
            return seed == 5
        }

        #expect(actual == 1)
    }

    @Test("first(where:) is nil when nothing matches, and over an empty range")
    func noMatch() async {
        let sut = SeedSearch(0 ..< 10_000).concurrent(workers: 2, batchSize: 64)
        let empty = SeedSearch(7 ..< 7).concurrent(workers: 2, batchSize: 64)

        #expect(await sut.first { _ in false } == nil)
        #expect(await empty.first { _ in true } == nil)
    }

    @Test("The last seed of the range is tried, and a batch is cut at the range's end")
    func lastSeed() async {
        let sut = SeedSearch(0 ..< 1001).concurrent(workers: 2, batchSize: 100)

        #expect(await sut.first { $0 == 1000 } == 1000)
        #expect(await sut.first { $0 == 1001 } == nil)
    }

    @Test("A single worker with a batch of one still finds the match")
    func minimalConfiguration() async {
        let sut = SeedSearch(0 ..< 50).concurrent(workers: 1, batchSize: 1)

        #expect(await sut.first { $0 == 37 } == 37)
    }

    @Test("Batches larger than the range work")
    func oversizedBatch() async {
        let sut = SeedSearch(0 ..< 10).concurrent(workers: 4, batchSize: 1_000_000)

        #expect(await sut.first { $0 == 9 } == 9)
        #expect(await sut.count { _ in true } == 10)
    }

    @Test("The search reaches the top of the seed space without overflowing")
    func topOfSeedSpace() async {
        let sut = SeedSearch(UInt64.max - 5000 ..< UInt64.max).concurrent(workers: 3, batchSize: 1000)
        let expected = UInt64.max - 1

        #expect(await sut.first { seed in seed == expected } == expected)
        #expect(await sut.count { $0 % 2 == 0 } == 2500)
    }

    @Test("A batch cut at the top of the seed space does not overflow")
    func batchAtTopOfSeedSpace() async {
        // The second batch starts 500 below the top; a start plus a full batch would wrap around.
        let sut = SeedSearch(UInt64.max - 1500 ..< UInt64.max).concurrent(workers: 2, batchSize: 1000)

        let expected = UInt64.max - 1

        let actual = await sut.first { seed in seed == expected }
        let count = await sut.count { _ in true }

        #expect(actual == expected)
        #expect(count == 1500)
    }

    // Mutex needs these OSes; the package's floors are lower, so only this test asks for them.
    @available(macOS 15, iOS 18, tvOS 18, watchOS 11, visionOS 2, *)
    @Test("Batches after a match are not started: one worker tries exactly the seeds up to the match")
    func laterBatchesSkipped() async {
        // One worker fixes the schedule: batch 0, then batch 1 (seeds 10 ..< 20), whose scan stops
        // at the match, and nothing after. With more workers, how many batches run before the match is received
        // depends on scheduling, so no count can be pinned.
        let tried = Mutex<Set<UInt64>>([])
        let sut = SeedSearch(0 ..< 100_000).concurrent(workers: 1, batchSize: 10)
        let expectedSeed: UInt64 = 15
        let expectedTried = Set<UInt64>(0 ... 15)

        let actual = await sut.first { seed in
            tried.withLock { _ = $0.insert(seed) }
            return seed == 15
        }

        let actualTried = tried.withLock { $0 }
        #expect(actual == expectedSeed)
        #expect(actualTried == expectedTried)
    }

    @Test("count(where:) sums the matches of every batch", .tags(.fixture))
    func count() async {
        let expected = 93
        let sut = SeedSearch(0 ..< 1000).concurrent(workers: 4, batchSize: 7)

        let actual = await sut.count { seed in
            var generator = Xoshiro256StarStar(seed: seed)
            return Double(generator.next() >> 11) * 0x1.0p-53 > 0.9
        }

        #expect(actual == expected)
        #expect(await sut.count { _ in true } == 1000)
        #expect(await sut.count { _ in false } == 0)
    }

    @Test("A concurrent search is a value", .tags(.conformance))
    func equality() {
        let sut = ConcurrentSeedSearch(0 ..< 10, workers: 2, batchSize: 3)

        #expect(sut == SeedSearch(0 ..< 10).concurrent(workers: 2, batchSize: 3))
        #expect(sut.hashValue == SeedSearch(0 ..< 10).concurrent(workers: 2, batchSize: 3).hashValue)
        #expect(sut != ConcurrentSeedSearch(0 ..< 10, workers: 3, batchSize: 3))
        #expect(sut != ConcurrentSeedSearch(0 ..< 10, workers: 2, batchSize: 4))
    }
}
