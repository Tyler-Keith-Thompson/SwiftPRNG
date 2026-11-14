// Property tests against a naive reference: the derivation written out from the root for every
// node, with overrides looked up by full path.

import Generators
import PropertyBased
import SeedTrees
import SwiftPRNGTestSupport
import Testing

@Suite("SeedTree: properties")
struct SeedTreePropertyTests {
    @Test("Any node's seed is the reference derivation from the root", .tags(.randomized))
    func derivation() async {
        let names = ["agent", "delay", "", "7", "é", "👋🏽"]
        let key = Gen.int(in: -1000 ... 1000).array(of: 2).map { (drawn: [Int]) -> SeedKey in
            drawn[0] % 2 == 0 ? .index(drawn[1]) : .name(names[abs(drawn[1]) % names.count])
        }
        let path = key.array(of: 0 ... 4)
        let overridePath = key.array(of: 0 ... 2)
        await propertyCheck(count: 300, input: Gen.uint64(), path, overridePath, Gen.uint64()) { root, path, overridePath, override in
            func derive(_ value: UInt64) -> UInt64 {
                var generator = SplitMix64(seed: value)
                return generator.next()
            }
            func mixing(_ key: SeedKey) -> UInt64 {
                switch key {
                case let .index(index):
                    return derive(UInt64(bitPattern: Int64(index)) ^ 0x6A09_E667_F3BC_C908)
                case let .name(name):
                    var hash: UInt64 = 0xCBF2_9CE4_8422_2325
                    for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
                    return derive(hash)
                }
            }
            func expectedSeed(_ path: SeedPath, overrides: [SeedPath: UInt64]) -> UInt64 {
                var seed = overrides[[]] ?? root
                for depth in path.indices {
                    seed = overrides[Array(path[...depth])] ?? derive(seed ^ mixing(path[depth]))
                }
                return seed
            }
            let plain = SeedTree(root)
            let overridden = plain.overriding(overridePath, with: override)

            #expect(plain.descendant(path).seed == expectedSeed(path, overrides: [:]))
            #expect(overridden.descendant(path).seed == expectedSeed(path, overrides: [overridePath: override]))
            #expect(overridden.descendant(path).path == path)
        }
    }

    @Test("Stepping down one key at a time equals stepping down the whole path", .tags(.randomized))
    func stepwise() async {
        let names = ["a", "b", "c"]
        let key = Gen.int(in: -5 ... 5).array(of: 2).map { (drawn: [Int]) -> SeedKey in
            drawn[0] % 2 == 0 ? .index(drawn[1]) : .name(names[abs(drawn[1]) % names.count])
        }
        await propertyCheck(count: 200, input: Gen.uint64(), key.array(of: 1 ... 5)) { root, path in
            let sut = SeedTree(root)

            let stepwise = path.reduce(sut) { tree, key in tree.descendant([key]) }

            #expect(stepwise == sut.descendant(path))
            #expect(stepwise.seed == sut.descendant(path).seed)
        }
    }
}
