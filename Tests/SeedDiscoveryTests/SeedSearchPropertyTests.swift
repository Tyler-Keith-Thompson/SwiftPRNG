// Property tests against the naive reference: a linear scan of the range.

import PropertyBased
import SeedDiscovery
import SwiftPRNGTestSupport
import Testing

@Suite("SeedSearch: properties", .timeLimit(.minutes(1)))
struct SeedSearchPropertyTests {
    @Test("Sequential and concurrent searches agree with a linear scan", .tags(.randomized))
    func agreeWithScan() async {
        let start = Gen.uint64(in: 0 ... 1000)
        let length = Gen.uint64(in: 0 ... 300)
        let modulus = Gen.uint64(in: 1 ... 50)
        let workers = Gen.int(in: 1 ... 6)
        let batch = Gen.uint64(in: 1 ... 40)
        await propertyCheck(count: 100, input: start, length, modulus, workers, batch) { start, length, modulus, workers, batch in
            let range = start ..< start + length
            let expectedFirst = range.first { $0 % modulus == 0 }
            let expectedCount = range.filter { $0 % modulus == 0 }.count
            let sut = SeedSearch(range)
            let concurrent = sut.concurrent(workers: workers, batchSize: batch)

            let actualFirst = sut.first { seed in seed % modulus == 0 }
            let actualCount = sut.count { seed in seed % modulus == 0 }
            let concurrentFirst = await concurrent.first { seed in seed % modulus == 0 }
            let concurrentCount = await concurrent.count { seed in seed % modulus == 0 }

            #expect(actualFirst == expectedFirst)
            #expect(actualCount == expectedCount)
            #expect(concurrentFirst == expectedFirst)
            #expect(concurrentCount == expectedCount)
        }
    }
}
