// Fitting: searching a subtree's override seed. Seed 81 is the first under which
// SeedTree(42)["agent", 7, "delay"] draws below 0.01, by scripts/differential_seedtrees.py and
// the reference xoroshiro128+ sequence.

import SeedDiscovery
import SeedTrees
import SwiftPRNGTestSupport
import Testing

@Suite("SeedTree: fitting", .timeLimit(.minutes(1)))
struct SeedTreeFittingTests {
    @Test("fitting(_:in:where:) overrides the node with the smallest seed the predicate accepts", .tags(.fixture))
    func sequential() throws {
        let sut = SeedTree(42)

        let fitted = try #require(sut.fitting(["agent", 7], in: SeedSearch(0 ..< 10_000)) { tree in
            tree["agent", 7, "delay"].uniform() < 0.01
        })

        #expect(fitted.overriddenSeeds == [["agent", 7]: 81])
        #expect(fitted["agent", 7, "delay"].uniform() < 0.01)
        #expect(fitted["agent", 6] == sut["agent", 6].overriding(["agent", 7], with: 81))
        #expect(fitted["agent", 6].seed == sut["agent", 6].seed)
        #expect(fitted.path.isEmpty)
    }

    @Test("The concurrent spelling finds the same seed", .tags(.fixture))
    func concurrent() async throws {
        let sut = SeedTree(42)

        let fitted = try #require(await sut.fitting(["agent", 7], in: SeedSearch(0 ..< 10_000).concurrent(workers: 4, batchSize: 16)) { tree in
            tree["agent", 7, "delay"].uniform() < 0.01
        })

        #expect(fitted.overriddenSeeds == [["agent", 7]: 81])
    }

    @Test("fitting is nil when no seed in the range fits")
    func noFit() async {
        let sut = SeedTree(42)

        #expect(sut.fitting(["agent"], in: SeedSearch(0 ..< 100)) { _ in false } == nil)
        #expect(await sut.fitting(["agent"], in: SeedSearch(0 ..< 100).concurrent(workers: 2)) { _ in false } == nil)
        #expect(sut.fitting(["agent"], in: SeedSearch(0 ..< 0)) { _ in true } == nil)
    }

    @Test("The predicate sees the candidate positioned at the receiver")
    func predicateSeesCandidate() throws {
        let sut = SeedTree(42)["agent"]
        var seen: [SeedTree] = []

        let fitted = try #require(sut.fitting(["agent", 7], in: SeedSearch(0 ..< 3)) { tree in
            seen.append(tree)
            return tree[7].seed == 2
        })

        #expect(fitted.path == ["agent"])
        #expect(fitted[7].seed == 2)
        #expect(seen.map(\.path) == [["agent"], ["agent"], ["agent"]])
        #expect(seen.map { $0[7].seed } == [0, 1, 2])
    }

    @Test("Fits for different nodes compose, since each override reseeds only its subtree")
    func fitsCompose() throws {
        let sut = SeedTree(42)
        let search = SeedSearch(0 ..< 10_000)

        let first = try #require(sut.fitting(["agent", 1], in: search) { $0["agent", 1].uniform() < 0.1 })
        let both = try #require(first.fitting(["agent", 2], in: search) { $0["agent", 2].uniform() > 0.9 })

        #expect(both["agent", 1].uniform() < 0.1)
        #expect(both["agent", 2].uniform() > 0.9)
        #expect(both["agent", 1] == first["agent", 1].overriding(both.overriddenSeeds))
        #expect(both["agent", 1].seed == first["agent", 1].seed)
        #expect(both.overriddenSeeds.count == 2)
    }

    @Test("fitting rethrows the predicate's typed error")
    func rethrowsTypedError() {
        struct Stop: Error, Equatable {}
        let sut = SeedTree(42)

        func fit() throws(Stop) -> SeedTree? {
            try sut.fitting(["agent"], in: SeedSearch(0 ..< 10)) { (_) throws(Stop) in throw Stop() }
        }

        #expect(throws: Stop()) { try fit() }
    }

    @Test("Fitting the root is allowed")
    func fittingRoot() throws {
        let sut = SeedTree(42)

        let fitted = try #require(sut.fitting([], in: SeedSearch(0 ..< 100)) { $0.seed == 7 })

        #expect(fitted.seed == 7)
        #expect(fitted.root == 42)
        #expect(fitted["a"].seed == SeedTree(7)["a"].seed)
    }
}
