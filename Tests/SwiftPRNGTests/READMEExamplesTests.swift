// The README's examples, verbatim, so the README cannot drift from the code.

import SwiftPRNG
import Testing

@Suite("README examples", .timeLimit(.minutes(1)))
struct READMEExamplesTests {
    @Test("Seeded generators")
    func seededGenerators() {
        var generator = Xoshiro256StarStar(seed: 42)
        let roll = Int.random(in: 1 ... 6, using: &generator)
        let hand = ["♠", "♥", "♦", "♣"].shuffled(using: &generator)

        var again = Xoshiro256StarStar(seed: 42)
        #expect(roll == Int.random(in: 1 ... 6, using: &again))
        #expect(hand == ["♠", "♥", "♦", "♣"].shuffled(using: &again))
        #expect((1 ... 6).contains(roll))
        #expect(hand.sorted() == ["♠", "♣", "♥", "♦"].sorted())
    }

    @Test("Platform-stable draws")
    func platformStableDraws() {
        var generator = Xoshiro256StarStar(seed: 42)
        let unit = generator.uniform()                  // 0.08386297105988216, in [0, 1)
        let delay = generator.uniform(in: 0.5 ..< 2)    // seconds
        let lane = generator.integer(in: 0 ..< 4)
        let dropped = generator.bernoulli(0.01)

        #expect(unit == 0.08386297105988216)
        #expect((0.5 ..< 2).contains(delay))
        #expect((0 ..< 4).contains(lane))
        #expect(dropped == false || dropped == true)
    }

    @Test("Streams that never overlap")
    func streams() {
        var generator = Xoshiro256StarStar(seed: 42)
        var streams: [Xoshiro256StarStar] = []
        for _ in 0 ..< 4 {
            streams.append(generator)
            generator.jump()  // 2¹²⁸ steps on
        }

        #expect(Set(streams).count == 4)
        #expect(streams[0] == Xoshiro256StarStar(seed: 42))
        #expect(streams[1] == Xoshiro256StarStar(seed: 42).jumped())
    }

    @Test("Seed trees")
    func seedTrees() {
        let tree = SeedTree(42)
        let arrival = tree["customer", 7, "arrival"].uniform(in: 0 ..< 60)
        var choices = tree["customer", 7, "choices"].generator
        let aisle = choices.integer(in: 0 ..< 12)
        let arrivals = (0 ..< 3).map { customer in tree["customer", customer, "arrival"].uniform(in: 0 ..< 60) }

        #expect(arrivals[1] == tree["customer", 1, "arrival"].uniform(in: 0 ..< 60))
        #expect(Set(arrivals).count == 3)
        #expect(arrival == SeedTree(42)["customer", 7, "arrival"].uniform(in: 0 ..< 60))
        #expect(tree["customer", 7, "arrival"].seed == tree["customer"][7]["arrival"].seed)
        #expect(tree["customer", 8, "arrival"].seed != tree["customer", 7, "arrival"].seed)
        #expect((0 ..< 12).contains(aisle))
        #expect(tree["customer", 7].description == "/customer/7 (seed \(tree["customer", 7].seed))")
    }

    @Test("Fitting a subtree")
    func fitting() throws {
        let tree = SeedTree(42)
        let fitted = tree.fitting(["customer", 7], in: SeedSearch(0 ..< 100_000)) { tree in
            tree["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1
        }
        let overrides = fitted?.overriddenSeeds  // [["customer", 7]: 33]

        let rebuilt = SeedTree(42, overrides: try #require(overrides))
        #expect(overrides == [["customer", 7]: 33])
        #expect(rebuilt["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1)
        #expect(rebuilt["customer", 8] == tree["customer", 8].overriding(["customer", 7], with: 33))
        #expect(rebuilt["customer", 8].seed == tree["customer", 8].seed)
    }

    @Test("Searching seeds across cores")
    func concurrentSearch() async {
        let seed = await SeedSearch(0 ..< 10_000_000).concurrent().first { seed in
            var generator = Xoshiro256StarStar(seed: seed)
            return generator.uniform() > 0.999_99
        }

        #expect(seed == 84_282)
        var generator = Xoshiro256StarStar(seed: 84_282)
        let draw = generator.uniform()
        #expect(draw > 0.999_99)
    }
}
