// The seed trees section (scripts/differential_seedtrees.py): a root, overrides and paths, answered
// with the seed at each path. Keys arrive as JSON numbers (indices) or strings (names), which is
// SeedKey's own encoding.

import SeedTrees

struct SeedTreesCase: Decodable {
    struct Override: Decodable {
        let path: SeedPath
        let seed: UInt64
    }

    let root: UInt64
    let overrides: [Override]
    let paths: [SeedPath]
}

struct SeedTreesAnswer: Encodable {
    var seeds: [String]

    init(_ input: SeedTreesCase) {
        let tree = SeedTree(input.root, overrides: Dictionary(input.overrides.map { ($0.path, $0.seed) }, uniquingKeysWith: { $1 }))
        seeds = input.paths.map { String(tree.descendant($0).seed) }
    }
}
