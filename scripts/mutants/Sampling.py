# Planted bugs for Sampling; run with `just mutate Sampling`. See scripts/mutate.py.
#
# Known equivalent mutants (they survive by design): integer_noprecondition. Without the
# precondition an empty range reaches `% width` with a width of zero, which traps on its own; the
# precondition only names the cause.

TESTS = ["SamplingTests"]

F = "RandomNumberGenerator+Sampling.swift"

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
]
