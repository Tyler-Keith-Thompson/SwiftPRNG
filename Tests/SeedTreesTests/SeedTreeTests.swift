// Each test is self-contained. Golden values come from the pure-Python reference in
// scripts/differential_seedtrees.py (SplitMix64 and FNV-1a written out).

import Distributions
import Generators
import SeedTrees
import SwiftPRNGTestSupport
import Testing

@Suite("SeedTree: hand-worked cases")
struct SeedTreeTests {
    @Test("Derivation matches the independent reference", .tags(.fixture))
    func reference() {
        let sut = SeedTree(42)

        #expect(sut["agent", 7].seed == 12_715_926_275_897_373_040)
        #expect(sut["agent", 7, "task", 0].seed == 12_789_505_777_390_384_311)
        #expect(SeedTree(0)[-1].seed == 5_215_283_969_826_668_975)
        #expect(sut[""].seed == 9_680_434_268_173_292_196)
        #expect(sut[7].seed == 14_703_663_905_098_698_677)
        #expect(sut["7"].seed == 7_321_779_313_188_775_780)
    }

    @Test("The root's seed is the seed it was made with")
    func root() {
        let sut = SeedTree(42)

        #expect(sut.seed == 42)
        #expect(sut.root == 42)
        #expect(sut.path.isEmpty)
        #expect(sut.overriddenSeeds.isEmpty)
    }

    @Test("Stepping down in one subscript or several reaches the same node")
    func stepping() {
        let sut = SeedTree(42)

        #expect(sut["agent", 7]["task", 0] == sut["agent", 7, "task", 0])
        #expect(sut["agent"][7] == sut["agent", 7])
        #expect(sut.descendant(["agent", 7]) == sut["agent", 7])
        #expect(sut.descendant([]) == sut)
        #expect(sut["agent", 7, "task", 0].path == ["agent", 7, "task", 0])
    }

    @Test("Siblings, key kinds and roots derive distinct seeds, whatever else was derived")
    func distinctness() {
        let sut = SeedTree(1)
        let seeds = [sut["a"].seed, sut["b"].seed, sut[0].seed, sut[1].seed, sut["0"].seed, sut.seed]

        _ = sut["unrelated", 3]

        #expect(Set(seeds).count == seeds.count)
        #expect(sut["a"].seed == seeds[0])
        #expect(SeedTree(2)["a"].seed != seeds[0])
        #expect(sut["a", "b"].seed != sut["b", "a"].seed)
    }

    @Test("Overriding a node reseeds its subtree as a root with that seed would, and leaves siblings alone", .tags(.fixture))
    func overriding() {
        let sut = SeedTree(42)

        let fitted = sut.overriding(["agent", 7], with: 99)

        #expect(fitted["agent", 7].seed == 99)
        #expect(fitted["agent", 7, "task", 0].seed == 8_087_410_402_386_367_481)
        #expect(fitted["agent", 7, "task", 0].seed == SeedTree(99)["task", 0].seed)
        #expect(fitted["agent", 6].seed == sut["agent", 6].seed)
        #expect(fitted["agent"].seed == sut["agent"].seed)
        #expect(fitted.seed == sut.seed)
        #expect(fitted.overriddenSeeds == [["agent", 7]: 99])
        #expect(fitted.root == 42)
    }

    @Test("Override paths are measured from the root, even when applied through a descendant")
    func overridingFromDescendant() {
        let sut = SeedTree(42)

        let fitted = sut["agent"].overriding(["agent", 7], with: 99)

        #expect(fitted.path == ["agent"])
        #expect(fitted[7].seed == 99)
        #expect(fitted == sut.overriding(["agent", 7], with: 99)["agent"])
    }

    @Test("The last override of a node wins, and several apply together")
    func overridingSeveral() {
        let sut = SeedTree(42)

        let twice = sut.overriding(["agent", 7], with: 99).overriding(["agent", 7], with: 5)
        let several = sut.overriding([["agent", 7]: 5, ["agent", 8]: 6])

        #expect(twice["agent", 7].seed == 5)
        #expect(several["agent", 7].seed == 5)
        #expect(several["agent", 8].seed == 6)
        #expect(several.overriddenSeeds == [["agent", 7]: 5, ["agent", 8]: 6])
    }

    @Test("The empty path overrides the root itself", .tags(.fixture))
    func overridingRoot() {
        let sut = SeedTree(42, overrides: [[]: 5])

        #expect(sut.seed == 5)
        #expect(sut.root == 42)
        #expect(sut["agent"].seed == SeedTree(5)["agent"].seed)
        #expect(sut["agent"].seed == 10_020_863_674_141_865_112)
        #expect(SeedTree(42).overriding([], with: 5) == sut)
    }

    @Test("A tree rebuilt from its root and overrides is the same tree")
    func rebuilding() {
        let fitted = SeedTree(42).overriding(["agent", 7], with: 99).overriding(["b"], with: 1)

        let rebuilt = SeedTree(fitted.root, overrides: fitted.overriddenSeeds)

        #expect(rebuilt == fitted)
        #expect(rebuilt["agent", 7, "x"].seed == fitted["agent", 7, "x"].seed)
    }

    @Test("Equality covers the position, the root and the overrides; equal nodes hash equally", .tags(.conformance))
    func equality() {
        let sut = SeedTree(42)

        #expect(sut["a"] == SeedTree(42)["a"])
        #expect(sut["a"].hashValue == SeedTree(42)["a"].hashValue)
        #expect(sut["a"] != sut["b"])
        #expect(sut["a"] != SeedTree(43)["a"])
        #expect(sut != sut.overriding(["b"], with: 1))
        #expect(Set([sut["a"], SeedTree(42)["a"], sut["b"]]).count == 2)
    }

    @Test("The description is the path and the seed")
    func description() {
        let sut = SeedTree(42)

        #expect(sut.description == "/ (seed 42)")
        #expect(sut["agent", 7].description == "/agent/7 (seed 12715926275897373040)")
    }

    @Test("Sampling a node is pure: every call gives the first draw of a fresh generator", .tags(.fixture))
    func sampling() {
        let node = SeedTree(3)["delay"]
        var generator = node.generator
        var integers = node.generator
        var interval = node.generator
        var trial = node.generator

        let unit = generator.uniform()
        let integer = integers.integer(in: 3 ..< 9)
        let inInterval = interval.uniform(in: 2 ..< 4)
        let success = trial.bernoulli(0.5)

        #expect(node.uniform() == node.uniform())
        #expect(node.uniform() == unit)
        #expect(node.integer(in: 3 ..< 9) == integer)
        #expect(node.uniform(in: 2 ..< 4) == inInterval)
        #expect(node.bernoulli(0.5) == success)
        #expect(Set((0 ..< 200).map { SeedTree(UInt64($0)).integer(in: 0 ..< 4) }) == [0, 1, 2, 3])
        #expect((0 ..< 100).filter { SeedTree(UInt64($0)).bernoulli(0.25) }.count == 14)
    }

    @Test("Sampling a distribution from a node is pure: every call gives the first sample of a fresh generator")
    func samplingDistribution() {
        let node = SeedTree(42)["customer", 7, "service"]
        let distribution = GammaDistribution(shape: 2, scale: 3)
        var generator = node.generator
        let expected = distribution.sample(using: &generator)

        let first = node.sample(distribution)
        let second = node.sample(distribution)
        let viaFactory = node.sample(.gamma(shape: 2, scale: 3))

        #expect(first == second)
        #expect(first == expected)
        #expect(viaFactory == expected)
        #expect(node.sample(.normal(mean: 1, standardDeviation: 0)) == 1)
    }

    @Test("The generator is Xoroshiro128Plus seeded with the node's seed, and other kinds are available")
    func generators() {
        let node = SeedTree(42)["agent", 7]
        var expected = Xoroshiro128Plus(seed: node.seed)
        var expectedXoshiro = Xoshiro256StarStar(seed: node.seed)
        var expectedSplitMix = SplitMix64(seed: node.seed)

        var actual = node.generator
        var actualXoshiro = node.generator(Xoshiro256StarStar.self)
        var actualSplitMix = node.generator(SplitMix64.self)

        let (first, expectedFirst) = (actual.next(), expected.next())
        let (firstXoshiro, expectedFirstXoshiro) = (actualXoshiro.next(), expectedXoshiro.next())
        let (firstSplitMix, expectedFirstSplitMix) = (actualSplitMix.next(), expectedSplitMix.next())
        #expect(first == expectedFirst)
        #expect(firstXoshiro == expectedFirstXoshiro)
        #expect(firstSplitMix == expectedFirstSplitMix)
        #expect(node.generator == node.generator)
    }

    @Test("Stepping down never changes the node stepped from", .tags(.copyOnWrite))
    func valueSemantics() {
        let sut = SeedTree(42)
        let before = sut

        _ = sut["agent", 7]
        _ = sut.overriding(["agent"], with: 1)

        #expect(sut == before)
        #expect(sut.overriddenSeeds.isEmpty)
    }
}
