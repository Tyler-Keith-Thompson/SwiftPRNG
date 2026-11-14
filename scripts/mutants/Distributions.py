# Planted bugs for Distributions; run with `just mutate Distributions`. See scripts/mutate.py.
#
# Not planted, because each is equivalent: Marsaglia and Tsang's squeeze `u < 1 − 0.0331x⁴` (every
# value it accepts, the logarithmic test accepts too, from the same draws) and its `root > 0`
# rejection (a nonpositive root needs x ≤ −3√d ≤ −2.45, where the squeeze is negative and the
# logarithmic test compares with NaN, so the attempt is rejected either way).
#
# Known equivalent mutants (they survive by design): ptrs_nosqueeze. Hörmann's squeeze region
# (us ≥ 0.07 and v ≤ v_r) lies inside the region the logarithmic test accepts: of 187,843 squeeze
# points over means from 10 to 10⁹, the test rejected none, so removing the squeeze only costs the
# logarithms it saves.

TESTS = ["DistributionsTests", "SeedTreesTests"]

MATH = "Fdlibm.swift"
NORMAL = "NormalDistribution.swift"
EXPONENTIAL = "ExponentialDistribution.swift"
TRIANGULAR = "TriangularDistribution.swift"
GAMMA = "GammaDistribution.swift"
POISSON = "PoissonDistribution.swift"
GEOMETRIC = "GeometricDistribution.swift"
CHOICE = "WeightedChoiceDistribution.swift"

MUTANTS = [
    # The portable math.
    Mutant("log_noreduce", MATH, "high &+= 0x3FF0_0000 - 0x3FE6_A09E", "", mode="stmt"),
    Mutant("log_nolow", MATH, "s * (hfsq + r) + dk * ln2Lo - hfsq + f + dk * ln2Hi", "s * (hfsq + r) - hfsq + f + dk * ln2Hi"),
    Mutant("log_nosubnormal", MATH, "x *= 0x1p54", "", mode="stmt"),
    Mutant("log1p_nocorrection", MATH, "c /= u", "c = 0", mode="stmt"),
    Mutant("exp_truncates", MATH, "k = Int32(invLn2 * x + (sign == 0 ? 0.5 : -0.5))", "k = Int32(invLn2 * x)", mode="stmt"),
    Mutant("exp_shortpoly", MATH, "xx * (p4 + xx * p5)", "xx * p4"),
    Mutant("scalbn_subnormal_scale", MATH, "0x1p-969", "0x1p-1022", nth=0),
    Mutant("cospi_floor", MATH, ".toNearestOrEven", ".down"),
    Mutant("cospi_quadrant", MATH, "return -sinKernel(y)", "return sinKernel(y)", mode="stmt"),
    Mutant("cos_shortpoly", MATH, "w * w * (c4 + z * (c5 + z * c6))", "w * w * c4"),
    Mutant("sin_shortpoly", MATH, "z * w * (s5 + z * s6)", "z * w * s5"),
    # Normal and log-normal.
    Mutant("normal_halfangle", NORMAL, "Fdlibm.cosPi(2 * generator.uniform())", "Fdlibm.cosPi(generator.uniform())"),
    Mutant("normal_radius", NORMAL, "(-2 * Fdlibm.log1p(-generator.uniform())).squareRoot()", "(-Fdlibm.log1p(-generator.uniform())).squareRoot()"),
    Mutant("normal_positivedeviation", NORMAL, "standardDeviation.isFinite && standardDeviation >= 0", "standardDeviation.isFinite && standardDeviation > 0"),
    Mutant("normal_noprecondition", NORMAL, 'precondition(Self.accepts(mean: mean, standardDeviation: standardDeviation),\n                     "Normal parameters must be finite with a nonnegative standard deviation")', "", mode="stmt"),
    Mutant("lognormal_noprecondition", "LogNormalDistribution.swift", 'precondition(NormalDistribution.accepts(mean: mean, standardDeviation: standardDeviation),\n                     "Log-normal parameters must be finite with a nonnegative standard deviation")', "", mode="stmt"),
    Mutant("lognormal_noexp", "LogNormalDistribution.swift", "Fdlibm.exp(mean + standardDeviation * NormalDistribution.standardSample(using: &generator))", "mean + standardDeviation * NormalDistribution.standardSample(using: &generator)"),
    # Exponential.
    Mutant("exponential_logu", EXPONENTIAL, "Fdlibm.log1p(-generator.uniform())", "Fdlibm.log(generator.uniform())"),
    Mutant("exponential_noprecondition", EXPONENTIAL, 'precondition(mean.isFinite && mean > 0, "An exponential mean must be finite and positive")', "", mode="stmt"),
    Mutant("exponential_checkedinfinite", EXPONENTIAL, "guard mean.isFinite, mean > 0 else { throw InvalidParameters() }", "guard mean > 0 else { throw InvalidParameters() }", mode="stmt"),
    # Triangular.
    Mutant("triangular_noclamp", TRIANGULAR, "max(lowerBound, min(value, upperBound))", "value"),
    Mutant("triangular_unscaled", TRIANGULAR, "width.isFinite", "true"),
    Mutant("triangular_modeabove", TRIANGULAR, "lowerBound <= mode && mode <= upperBound", "lowerBound <= mode"),
    Mutant("triangular_noprecondition", TRIANGULAR, 'precondition(Self.accepts(lowerBound: lowerBound, mode: mode, upperBound: upperBound),\n                     "Triangular bounds must be finite and increasing and contain the mode")', "", mode="stmt"),
    # Gamma.
    Mutant("gamma_third", GAMMA, "(shape < 1 ? shape + 1 : shape) - 1.0 / 3.0", "(shape < 1 ? shape + 1 : shape) - 0.5"),
    Mutant("gamma_alwaysboost", GAMMA, "guard shape < 1 else { return unscaled * scale }", "", mode="stmt"),
    Mutant("gamma_nologv", GAMMA, "0.5 * squared + d * (1 - v + Fdlibm.log(v))", "0.5 * squared + d * (1 - v)"),
    Mutant("gamma_noprecondition", GAMMA, 'precondition(Self.accepts(shape: shape, scale: scale), "Gamma parameters must be finite and positive")', "", mode="stmt"),
    # Poisson.
    Mutant("poisson_zero_draws", POISSON, "guard mean > 0 else { return 0 }", "", mode="stmt"),
    Mutant("poisson_threshold", POISSON, "mean >= 10", "mean > 10"),
    Mutant("ptrs_nosqueeze", POISSON, "if us >= 0.07, v <= acceptanceBound { return Int(k) }", "", mode="stmt"),
    Mutant("ptrs_offset", POISSON, "(2 * a / us + b) * u + mean + 0.43", "(2 * a / us + b) * u + mean"),
    Mutant("ptrs_loggamma", POISSON, "Self.logGamma(k + 1)", "Self.logGamma(k)"),
    Mutant("loggamma_noshift", POISSON, "x < 7 ? (7 - x).rounded(.towardZero) : 0", "0"),
    Mutant("loggamma_series", POISSON, "series = series * inverseSquare + coefficient", "series = series + coefficient", mode="stmt"),
    Mutant("poisson_noprecondition", POISSON, 'precondition(mean >= 0 && mean <= Self.maximumMean, "A Poisson mean must lie in 0 ... 2³⁰")', "", mode="stmt"),
    Mutant("poisson_checkedupper", POISSON, "guard mean >= 0, mean <= Self.maximumMean else { throw InvalidParameters() }", "guard mean >= 0 else { throw InvalidParameters() }", mode="stmt"),
    # Geometric.
    Mutant("geometric_nosaturation", GEOMETRIC, "failures < Double(Int.max) ? Int(failures) : .max", "Int(failures)"),
    Mutant("geometric_logp", GEOMETRIC, "Fdlibm.log1p(-probability)", "Fdlibm.log(probability)"),
    Mutant("geometric_noprecondition", GEOMETRIC, 'precondition(probability > 0 && probability <= 1, "A geometric probability must lie in (0, 1]")', "", mode="stmt"),
    Mutant("geometric_checkedzero", GEOMETRIC, "guard probability > 0, probability <= 1 else { throw InvalidParameters() }", "guard probability <= 1 else { throw InvalidParameters() }", mode="stmt"),
    # Weighted choice.
    Mutant("choice_unnormalized", CHOICE, "total += choice.weight / largest", "total += choice.weight", mode="stmt"),
    Mutant("choice_keepszero", CHOICE, "choice.weight > 0", "choice.weight >= 0"),
    Mutant("choice_search", CHOICE, "high = middle", "high = max(low, middle - 1)", mode="stmt"),
    Mutant("choice_acceptsallzero", CHOICE, "choices.allSatisfy { $0.weight.isFinite && $0.weight >= 0 } && choices.contains { $0.weight > 0 }", "choices.allSatisfy { $0.weight.isFinite && $0.weight >= 0 }"),
    Mutant("choice_noprecondition", CHOICE, 'precondition(Self.accepts(choices), "Choice weights must be finite and nonnegative, and one must be positive")', "", mode="stmt"),
    # Composition and seed trees.
    Mutant("tree_sample_fresh", "SeedTree.swift", "return distribution.sample(using: &generator)", "_ = generator.next()\n        return distribution.sample(using: &generator)", mode="stmt", module="SeedTrees"),
]
