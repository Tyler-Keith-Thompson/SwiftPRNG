# Planted bugs for SeedTrees; run with `just mutate SeedTrees`. See scripts/mutate.py.
#
# Known equivalent mutants (they survive by design): none.

TESTS = ["SeedTreesTests"]

K = "SeedKey.swift"
T = "SeedTree.swift"
F = "SeedTree+Fitting.swift"

MUTANTS = [
    Mutant("key_indexconstant", K, "0x6A09_E667_F3BC_C908", "0x6A09_E667_F3BC_C909"),
    Mutant("key_fnvbasis", K, "0xCBF2_9CE4_8422_2325", "0xCBF2_9CE4_8422_2324"),
    Mutant("key_fnvprime", K, "0x0000_0100_0000_01B3", "0x0000_0100_0000_01B5"),
    Mutant("key_namesunmixed", K, "return SeedTree.derive(hash)", "return hash", mode="stmt"),
    Mutant("key_indexorder", K, "left < right", "left > right", nth=0),
    Mutant("key_nameorder", K, "left < right", "left > right", nth=1),
    Mutant("key_decodeall_names", K, "if let index = try? container.decode(Int.self) {\n            self = .index(index)\n        } else {\n            self = .name(try container.decode(String.self))\n        }", "self = .name(try container.decode(String.self))", mode="stmt"),
    Mutant("key_convertible_int", K, ".index(self)", ".name(String(self))"),
    Mutant("tree_subscript_dropslast", T, "path.append(key.seedKey)", "if path.isEmpty { path.append(key.seedKey) }", mode="stmt"),
    Mutant("tree_rootoverride", T, "overrides[[]] ?? root", "root"),
    Mutant("tree_noderive", T, "Self.derive(seed ^ key.mixingValue)", "seed ^ key.mixingValue"),
    Mutant("tree_overrideignored", T, "seed = overrides[path] ?? derived", "seed = derived", mode="stmt"),
    Mutant("tree_overridefromnode", T, "return SeedTree(root, overrides: overrides).descendant(self.path)", "return SeedTree(root, overrides: overrides)", mode="stmt"),
    Mutant("tree_equalityignoresoverrides", T, "lhs.seed == rhs.seed && lhs.root == rhs.root && lhs.overrides == rhs.overrides && lhs.path == rhs.path", "lhs.seed == rhs.seed && lhs.root == rhs.root && lhs.path == rhs.path"),
    Mutant("tree_pathreversed", T, "return keys.reversed()", "return keys", mode="stmt"),
    Mutant("tree_descriptionnoseed", T, '"/" + path.map(\\.description).joined(separator: "/") + " (seed \\(seed))"', '"/" + path.map(\\.description).joined(separator: "/")'),
    Mutant("tree_generatorroot", T, "Xoroshiro128Plus(seed: seed)", "Xoroshiro128Plus(seed: root)"),
    Mutant("tree_derivenostep", T, "var generator = SplitMix64(seed: value)\n        return generator.next()", "return value", mode="stmt"),
    Mutant("fit_nooverride", F, "return seed.map { overriding(path, with: $0) }", "return seed.map { _ in self }", mode="stmt", nth=0),
    Mutant("fit_predicateseesoriginal", F, "try predicate(overriding(path, with: seed))", "try predicate(self)"),
]
