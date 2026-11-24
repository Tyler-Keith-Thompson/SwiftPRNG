# Planted bugs for Sampling; run with `just mutate Sampling`. See scripts/mutate.py.
#
# Known equivalent mutants (they survive by design): integer_noprecondition. Without the
# precondition an empty range reaches `% width` with a width of zero, which traps on its own; the
# precondition only names the cause. shuffle_noguard: without the guard, an empty or one-element
# collection starts the loop at offset -1 or 0, so it never runs and takes no draw; the guard only
# keeps `index(before: endIndex)` off an empty collection, which for an Array is plain arithmetic
# and doesn't trap.
#
# A *_fromend mutant comes before the mutant whose `old` lies inside its own, which then picks the
# second occurrence (`nth=1`): the original text, in the schema's else branch.

TESTS = ["SamplingTests"]

F = "RandomNumberGenerator+Sampling.swift"
C = "RandomNumberGenerator+Collections.swift"

MUTANTS = [
    Mutant("uniform_bits", F, "Double(next() >> 11) * 0x1.0p-53", "Double(next() >> 12) * 0x1.0p-52"),
    Mutant("uniform_noclamp", F, "max(range.lowerBound, min(value, range.upperBound.nextDown))", "value"),
    Mutant("uniform_noprecondition", F, 'precondition(range.lowerBound.isFinite && range.upperBound.isFinite && !range.isEmpty,\n                     "Uniform bounds must be finite and increasing")', "", mode="stmt"),
    Mutant("uniform_checkedfinite", F, "guard range.lowerBound.isFinite, range.upperBound.isFinite, !range.isEmpty else { throw InvalidInterval() }", "guard !range.isEmpty else { throw InvalidInterval() }", mode="stmt"),
    Mutant("integer_noprecondition", F, 'precondition(!range.isEmpty, "Uniform integer bounds must be increasing")', "", mode="stmt"),
    Mutant("integer_modulo", F, "return Int(truncatingIfNeeded: lower &+ offset(below: width))", "return Int(truncatingIfNeeded: lower &+ next() % width)", mode="stmt", nth=0),
    Mutant("integer_checkedaccepts", F, "guard !range.isEmpty else { throw EmptyRange() }", "", mode="stmt"),
    Mutant("closed_width", F, "UInt64(bitPattern: Int64(range.upperBound)) &- lower &+ 1", "UInt64(bitPattern: Int64(range.upperBound)) &- lower"),
    Mutant("closed_nofullrange", F, "guard width != 0 else { return Int(truncatingIfNeeded: next()) }", "", mode="stmt"),
    Mutant("bernoulli_inclusive", F, "return uniform() < probability", "return uniform() <= probability", mode="stmt"),
    Mutant("bernoulli_noprecondition", F, 'precondition(probability >= 0 && probability <= 1, "A probability lies in 0 ... 1")', "", mode="stmt"),
    Mutant("bernoulli_checkedupper", F, "guard probability >= 0, probability <= 1 else { throw InvalidProbability() }", "guard probability >= 0 else { throw InvalidProbability() }", mode="stmt"),
    Mutant("offset_nothreshold", F, "while value < threshold { value = next() }", "", mode="stmt"),
    Mutant("offset_threshold", F, "(0 &- width) % width", "width"),
    Mutant("shuffle_drawsatzero", C, "offset > 0", "offset >= 0", nth=1),
    Mutant("shuffle_noguard", C, "guard offset > 0 else { return }", "", mode="stmt"),
    Mutant("shuffle_noswap", C, "collection.swapAt(index, other)", "", mode="stmt"),
    Mutant("shuffle_nostep", C, "collection.formIndex(before: &index)", "", mode="stmt"),
    Mutant("shuffle_fromend", C, "collection.index(collection.startIndex, offsetBy: integer(in: 0 ... offset))", "collection.index(collection.endIndex, offsetBy: -1 - integer(in: 0 ... offset))"),
    Mutant("shuffle_sattolo", C, "integer(in: 0 ... offset)", "integer(in: 0 ..< offset)", nth=1),
    Mutant("shuffled_unshuffled", C, "shuffle(&elements)", "", mode="stmt"),
    Mutant("element_drawsonempty", C, "guard !collection.isEmpty else { return nil }", "guard !collection.isEmpty else { _ = next(); return nil }", mode="stmt"),
    Mutant("element_fromend", C, "collection.index(collection.startIndex, offsetBy: integer(in: 0 ..< collection.count))", "collection.index(collection.endIndex, offsetBy: -1 - integer(in: 0 ..< collection.count))"),
    Mutant("element_neverlast", C, "integer(in: 0 ..< collection.count)", "integer(in: 0 ..< max(collection.count - 1, 1))", nth=1),
]
