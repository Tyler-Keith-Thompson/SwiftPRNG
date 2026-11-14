// A seed tree against a model: a dictionary of overrides and the derivation recomputed from the
// root for every path (one SplitMix64 step per key, FNV-1a for names), under any sequence of
// steps down, overrides and rebuilds. Keys come from a small alphabet so paths collide often.

import FuzzSupport
import Generators
import SeedTrees

@main
enum FuzzSeedTrees {
    static func main() { runFuzzer(fuzz) }

    static let keys: [SeedKey] = ["a", "b", "", "0", 0, 1, -1, 7]

    static func derive(_ value: UInt64) -> UInt64 {
        var generator = SplitMix64(seed: value)
        return generator.next()
    }

    static func mixing(_ key: SeedKey) -> UInt64 {
        switch key {
        case let .index(index):
            return derive(UInt64(bitPattern: Int64(index)) ^ 0x6A09_E667_F3BC_C908)
        case let .name(name):
            var hash: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
            return derive(hash)
        }
    }

    static func expectedSeed(root: UInt64, overrides: [SeedPath: UInt64], path: SeedPath) -> UInt64 {
        var seed = overrides[[]] ?? root
        for depth in path.indices {
            seed = overrides[Array(path[...depth])] ?? derive(seed ^ mixing(path[depth]))
        }
        return seed
    }

    static func fuzz(_ input: inout FuzzInput) {
        let root = UInt64(input.byte())
        var tree = SeedTree(root)
        var overrides: [SeedPath: UInt64] = [:]
        var position: SeedPath = []
        var snapshot: (SeedTree, UInt64)?

        func randomPath(_ input: inout FuzzInput) -> SeedPath {
            (0 ..< input.int(in: 0 ... 3)).map { _ in keys[input.int(below: keys.count)] }
        }

        while !input.isEmpty {
            switch input.int(below: 5) {
            case 0:
                let steps = randomPath(&input)
                tree = input.int(below: 2) == 0 ? tree.descendant(steps) : steps.reduce(tree) { $0[$1] }
                position += steps
            case 1:
                let path = randomPath(&input)
                let seed = UInt64(input.byte())
                tree = tree.overriding(path, with: seed)
                overrides[path] = seed
            case 2:
                tree = SeedTree(tree.root, overrides: tree.overriddenSeeds).descendant(tree.path)
            case 3:
                snapshot = (tree, tree.seed)
            default:
                let rebuilt = SeedTree(root, overrides: overrides).descendant(position)
                check(rebuilt == tree, "a tree rebuilt from its parts differs: \(rebuilt) vs \(tree)")
                check(rebuilt.hashValue == tree.hashValue, "equal trees hash differently")
            }
            check(tree.root == root, "the root changed")
            check(tree.path == position, "path \(tree.path), model \(position)")
            check(tree.overriddenSeeds == overrides, "overrides \(tree.overriddenSeeds), model \(overrides)")
            check(tree.seed == expectedSeed(root: root, overrides: overrides, path: position), "seed at \(position)")
            let probe = randomPath(&input)
            check(tree.descendant(probe).seed == expectedSeed(root: root, overrides: overrides, path: position + probe), "seed at \(position + probe)")
            if let (copy, seed) = snapshot {
                check(copy.seed == seed, "a copy taken earlier changed")
            }
        }
    }
}
