// Each test is self-contained. Golden values come from scripts/differential_distributions.py over
// the Xoshiro256StarStar sequence for seed 42 (run it directly to print them).

import Distributions
import Generators
import Sampling
import SwiftPRNGTestSupport
import Testing

@Suite("Distributions: hand-worked cases")
struct DistributionsTests {
    @Test("A standard normal's first samples for seed 42 match the reference", .tags(.fixture))
    func normalReference() {
        let expected: [Double] = [-0.30326306467873804, 1.3438117634372808, 0.38346179126769414]
        let sut = NormalDistribution(mean: 0, standardDeviation: 1)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("An exponential's first samples for seed 42 match the reference", .tags(.fixture))
    func exponentialReference() {
        let expected: [Double] = [0.08758933058341757, 0.4763923950787724, 1.1395699518538775]
        let sut = ExponentialDistribution(mean: 1)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A log-normal's first samples for seed 42 match the reference", .tags(.fixture))
    func logNormalReference() {
        let expected: [Double] = [0.7384048225908847, 3.8336285755245294, 1.4673554855846849]
        let sut = LogNormalDistribution(mean: 0, standardDeviation: 1)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A log-normal sample is e raised to the normal sample with the same parameters", .tags(.fixture))
    func logNormalShifted() {
        let expected = 2.335832754681932
        let sut = LogNormalDistribution(mean: 1, standardDeviation: 0.5)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = sut.sample(using: &generator)

        #expect(actual == expected)
    }

    @Test("A triangular's first samples for seed 42 match the reference", .tags(.fixture))
    func triangularReference() {
        let expected: [Double] = [0.5791820821119458, 1.2701214327285588, 2.040541128866868]
        let sut = TriangularDistribution(lowerBound: 0, mode: 1, upperBound: 4)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A gamma's first samples for seed 42 match the reference", .tags(.fixture))
    func gammaReference() {
        let expected: [Double] = [1.3050117476166543, 6.6545510931173455, 3.1925109912692125]
        let sut = GammaDistribution(shape: 2, scale: 1)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A gamma with a shape below 1 boosts the shape and takes one more draw", .tags(.fixture))
    func gammaSmallShapeReference() {
        let expected: [Double] = [0.7428777669905297, 1.1789992763525554, 0.016186327781303623]
        let sut = GammaDistribution(shape: 0.5, scale: 1)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A gamma's scale multiplies the sample", .tags(.fixture))
    func gammaScale() {
        let expected = 1.3914318247661486
        let sut = GammaDistribution(shape: 1, scale: 3)
        var generator = Xoshiro256StarStar(seed: 7)

        let actual = sut.sample(using: &generator)

        #expect(actual == expected)
    }

    @Test("A small-shape gamma at the largest scale is zero, not NaN, when its boost underflows")
    func gammaBoostBeforeScale() {
        // Zero draws: a radius of zero, so x = 0 and v = 1, accepted by the squeeze, then a boost
        // of e^(ln 0 / shape) = 0. Scaling before boosting would give ∞ × 0.
        let sut = GammaDistribution(shape: 0.5, scale: .greatestFiniteMagnitude)
        var generator = ScriptedGenerator(values: [])

        let actual = sut.sample(using: &generator)

        #expect(actual == 0)
    }

    @Test("A gamma at the largest scale overflows to infinity, never NaN", .tags(.randomized))
    func gammaHugeScale() {
        let small = GammaDistribution(shape: 0.5, scale: .greatestFiniteMagnitude)
        let large = GammaDistribution(shape: 3, scale: .greatestFiniteMagnitude)
        var generator = Xoshiro256StarStar(seed: 4)

        for _ in 0 ..< 1000 {
            let smallSample = small.sample(using: &generator)
            let largeSample = large.sample(using: &generator)

            #expect(!smallSample.isNaN && smallSample >= 0)
            #expect(!largeSample.isNaN && largeSample >= 0)
        }
    }

    @Test("A Poisson below a mean of 10 uses the multiplication method", .tags(.fixture))
    func poissonSmallMeanReference() {
        let expected = [5, 7, 6]
        let expectedJustBelowTen = [19, 9, 16]
        let sut = PoissonDistribution(mean: 4)
        let justBelowTen = PoissonDistribution(mean: 9.999)
        var generator = Xoshiro256StarStar(seed: 42)
        var justBelowTenGenerator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }
        let actualJustBelowTen = (0 ..< 3).map { _ in justBelowTen.sample(using: &justBelowTenGenerator) }

        #expect(actual == expected)
        #expect(actualJustBelowTen == expectedJustBelowTen)
    }

    @Test("A Poisson from a mean of 10 uses transformed rejection", .tags(.fixture))
    func poissonLargeMeanReference() {
        let expectedAtTen = [5, 13, 12]
        let expectedAtHundred = [83, 105, 107]
        let atTen = PoissonDistribution(mean: 10)
        let atHundred = PoissonDistribution(mean: 100)
        var atTenGenerator = Xoshiro256StarStar(seed: 42)
        var atHundredGenerator = Xoshiro256StarStar(seed: 42)

        let actualAtTen = (0 ..< 3).map { _ in atTen.sample(using: &atTenGenerator) }
        let actualAtHundred = (0 ..< 3).map { _ in atHundred.sample(using: &atHundredGenerator) }

        #expect(actualAtTen == expectedAtTen)
        #expect(actualAtHundred == expectedAtHundred)
    }

    @Test("A Poisson at the largest mean stays near it")
    func poissonMaximumMean() {
        let mean = PoissonDistribution.maximumMean
        let sut = PoissonDistribution(mean: mean)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = sut.sample(using: &generator)

        #expect(Double(actual) > mean - 10 * mean.squareRoot())
        #expect(Double(actual) < mean + 10 * mean.squareRoot())
    }

    @Test("A geometric's first samples for seed 42 match the reference", .tags(.fixture))
    func geometricReference() {
        let expected = [0, 1, 3]
        let sut = GeometricDistribution(probability: 0.25)
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A weighted choice's first samples for seed 42 match the reference", .tags(.fixture))
    func weightedChoiceReference() {
        let expected = ["a", "b", "c"]
        let sut = WeightedChoiceDistribution([(value: "a", weight: 1), (value: "b", weight: 2), (value: "c", weight: 3)])
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = (0 ..< 3).map { _ in sut.sample(using: &generator) }

        #expect(actual == expected)
    }

    @Test("A normal with no spread returns its mean and still takes two draws")
    func normalZeroDeviation() {
        let expectedDraws = 2
        let sut = NormalDistribution(mean: 3.5, standardDeviation: 0)
        var generator = CountingGenerator()

        let actual = sut.sample(using: &generator)

        #expect(actual == 3.5)
        #expect(generator.draws == expectedDraws)
    }

    @Test("A normal sample from a zero first draw is the mean: the radius is zero")
    func normalZeroRadius() {
        let sut = NormalDistribution(mean: 2, standardDeviation: 5)
        var generator = ScriptedGenerator(values: [0, 1 << 62])

        let actual = sut.sample(using: &generator)

        #expect(actual == 2)
    }

    @Test("A normal sample's angle reads cos(2πu): a quarter turn gives the mean, a half turn the negative radius")
    func normalAngle() {
        let firstDraw: UInt64 = 1 << 63  // u₁ = ½, radius √(2 ln 2)
        let expectedRadius = (2 * 0.6931471805599453).squareRoot()
        let sut = NormalDistribution(mean: 0, standardDeviation: 1)
        var quarterTurn = ScriptedGenerator(values: [firstDraw, 1 << 62])
        var halfTurn = ScriptedGenerator(values: [firstDraw, 1 << 63])

        let actualQuarter = sut.sample(using: &quarterTurn)
        let actualHalf = sut.sample(using: &halfTurn)

        #expect(actualQuarter == 0)
        #expect(abs(actualHalf + expectedRadius) < 1e-15)
    }

    @Test("An exponential sample from a zero draw is zero")
    func exponentialZero() {
        let sut = ExponentialDistribution(mean: 5)
        var generator = ScriptedGenerator(values: [0])

        let actual = sut.sample(using: &generator)

        #expect(actual == 0)
        #expect(actual.sign == .plus)
    }

    @Test("An exponential sample from the largest draw is 53 ln 2 times its mean")
    func exponentialLargest() {
        let sut = ExponentialDistribution(mean: 2)
        var generator = ScriptedGenerator(values: [.max])

        let actual = sut.sample(using: &generator)

        #expect(abs(actual - 2 * 53 * 0.6931471805599453) < 1e-12)
    }

    @Test("A triangular with its mode at a bound stays inside the bounds")
    func triangularModeAtBounds() {
        let atLower = TriangularDistribution(lowerBound: -2, mode: -2, upperBound: 3)
        let atUpper = TriangularDistribution(lowerBound: -2, mode: 3, upperBound: 3)
        var generator = Xoshiro256StarStar(seed: 5)

        for _ in 0 ..< 1000 {
            let lower = atLower.sample(using: &generator)
            let upper = atUpper.sample(using: &generator)

            #expect(lower >= -2 && lower <= 3)
            #expect(upper >= -2 && upper <= 3)
        }
    }

    @Test("A triangular's bounds are its smallest and largest samples")
    func triangularEndpoints() {
        let sut = TriangularDistribution(lowerBound: 1, mode: 2, upperBound: 5)
        var lowest = ScriptedGenerator(values: [0])
        var highest = ScriptedGenerator(values: [.max])

        let actualLowest = sut.sample(using: &lowest)
        let actualHighest = sut.sample(using: &highest)

        #expect(actualLowest == 1)
        #expect(actualHighest < 5 && actualHighest > 4.99999)
    }

    @Test("A triangular clamps a value that rounds outside bounds one ulp apart")
    func triangularClampsRounding() {
        let lower = 0.0015423955548227576
        let upper = 0.0015423955548227578
        let sut = TriangularDistribution(lowerBound: lower, mode: upper, upperBound: upper)
        var generator = ScriptedGenerator(values: [0x1AC1_9345_3CAE_8000])  // u = 0.10451622429234853

        let actual = sut.sample(using: &generator)

        #expect(actual == lower)
    }

    @Test("A triangular across the whole Double range still samples inside it")
    func triangularOverflowingWidth() {
        let sut = TriangularDistribution(lowerBound: -1e308, mode: 0, upperBound: 1e308)
        var generator = Xoshiro256StarStar(seed: 9)

        var scaledSum = 0.0

        for _ in 0 ..< 1000 {
            let actual = sut.sample(using: &generator)

            #expect(actual.isFinite)
            #expect(actual >= -1e308 && actual <= 1e308)
            scaledSum += actual / 1e308
        }

        // Symmetric about a mode of zero, so the mean is near zero, not near a bound.
        #expect(abs(scaledSum / 1000) < 0.05)
    }

    @Test("A Poisson with a mean of zero returns zero without drawing")
    func poissonZero() {
        let sut = PoissonDistribution(mean: 0)
        var generator = CountingGenerator()

        let actual = sut.sample(using: &generator)

        #expect(actual == 0)
        #expect(generator.draws == 0)
    }

    @Test("A small-mean Poisson takes one draw more than its count")
    func poissonDraws() {
        let sut = PoissonDistribution(mean: 3)
        var generator = Xoshiro256StarStar(seed: 11)

        for _ in 0 ..< 100 {
            var counting = CountingWrapper(base: generator)

            let actual = sut.sample(using: &counting)

            #expect(counting.draws == actual + 1)
            generator = counting.base
        }
    }

    @Test("A geometric with a probability of 1 returns zero, taking one draw")
    func geometricCertain() {
        let sut = GeometricDistribution(probability: 1)
        var generator = CountingGenerator()

        let actual = (0 ..< 5).map { _ in sut.sample(using: &generator) }

        #expect(actual == [0, 0, 0, 0, 0])
        #expect(generator.draws == 5)
    }

    @Test("A geometric whose count passes Int.max reports Int.max")
    func geometricSaturates() {
        let sut = GeometricDistribution(probability: 1e-300)
        var generator = ScriptedGenerator(values: [.max])

        let actual = sut.sample(using: &generator)

        #expect(actual == .max)
    }

    @Test("A weighted choice never picks a zero weight")
    func weightedChoiceZeroWeight() {
        let sut = WeightedChoiceDistribution([(value: 0, weight: 0), (value: 1, weight: 1), (value: 2, weight: 0)])
        var generator = Xoshiro256StarStar(seed: 3)

        let actual = Set((0 ..< 500).map { _ in sut.sample(using: &generator) })

        #expect(actual == [1])
        #expect(sut.values == [1])
    }

    @Test("A weighted choice's last value covers the top of the unit interval")
    func weightedChoiceUpperEnd() {
        let sut = WeightedChoiceDistribution([(value: "a", weight: 1), (value: "b", weight: 1)])
        var lowest = ScriptedGenerator(values: [0])
        var highest = ScriptedGenerator(values: [.max])

        let actualLowest = sut.sample(using: &lowest)
        let actualHighest = sut.sample(using: &highest)

        #expect(actualLowest == "a")
        #expect(actualHighest == "b")
    }

    @Test("A weighted choice of weights near the largest Double stays finite and fair")
    func weightedChoiceHugeWeights() {
        let sut = WeightedChoiceDistribution([(value: 0, weight: .greatestFiniteMagnitude), (value: 1, weight: .greatestFiniteMagnitude)])
        var generator = Xoshiro256StarStar(seed: 1)

        let actual = (0 ..< 1000).map { _ in sut.sample(using: &generator) }.reduce(0, +)

        #expect(actual > 400 && actual < 600)
    }

    @Test("A constant returns its value without drawing")
    func constant() {
        let sut = ConstantDistribution("x")
        var generator = CountingGenerator()

        let actual = sut.sample(using: &generator)

        #expect(actual == "x")
        #expect(generator.draws == 0)
    }

    @Test("map transforms each sample and draws exactly what its base draws")
    func mapped() {
        let base = ExponentialDistribution(mean: 2)
        let sut = base.map { $0 * 10 }
        var baseGenerator = Xoshiro256StarStar(seed: 42)
        var generator = Xoshiro256StarStar(seed: 42)

        let expected = base.sample(using: &baseGenerator) * 10
        let actual = sut.sample(using: &generator)

        #expect(actual == expected)
        #expect(generator == baseGenerator)
    }

    @Test("The static factories build the same distributions as the initializers")
    func factories() {
        func sampled<D: Distribution>(_ distribution: D) -> D.Value {
            var generator = Xoshiro256StarStar(seed: 42)
            return distribution.sample(using: &generator)
        }
        let expectedNormal = NormalDistribution(mean: 1, standardDeviation: 2)
        let expectedExponential = ExponentialDistribution(mean: 3)
        let expectedLogNormal = LogNormalDistribution(mean: 0, standardDeviation: 0.5)
        let expectedTriangular = TriangularDistribution(lowerBound: 0, mode: 1, upperBound: 2)
        let expectedGamma = GammaDistribution(shape: 2, scale: 3)
        let expectedPoisson = PoissonDistribution(mean: 4)
        let expectedGeometric = GeometricDistribution(probability: 0.5)

        let normal: NormalDistribution = .normal(mean: 1, standardDeviation: 2)
        let exponential: ExponentialDistribution = .exponential(mean: 3)
        let logNormal: LogNormalDistribution = .logNormal(mean: 0, standardDeviation: 0.5)
        let triangular: TriangularDistribution = .triangular(lowerBound: 0, mode: 1, upperBound: 2)
        let gamma: GammaDistribution = .gamma(shape: 2, scale: 3)
        let poisson: PoissonDistribution = .poisson(mean: 4)
        let geometric: GeometricDistribution = .geometric(probability: 0.5)
        let constant: ConstantDistribution<Int> = .constant(7)
        let choice: WeightedChoiceDistribution<String> = .weightedChoice([(value: "only", weight: 1)])

        #expect(normal == expectedNormal)
        #expect(exponential == expectedExponential)
        #expect(logNormal == expectedLogNormal)
        #expect(triangular == expectedTriangular)
        #expect(gamma == expectedGamma)
        #expect(poisson == expectedPoisson)
        #expect(geometric == expectedGeometric)
        #expect(constant == ConstantDistribution(7))
        #expect(sampled(choice) == "only")
    }

    @Test("The default normal and log-normal are the standard ones")
    func defaults() {
        let expectedNormal = NormalDistribution(mean: 0, standardDeviation: 1)
        let expectedLogNormal = LogNormalDistribution(mean: 0, standardDeviation: 1)
        let expectedGamma = GammaDistribution(shape: 2, scale: 1)

        let actualNormal = NormalDistribution()
        let actualLogNormal = LogNormalDistribution()
        let actualGamma = GammaDistribution(shape: 2)

        #expect(actualNormal == expectedNormal)
        #expect(actualLogNormal == expectedLogNormal)
        #expect(actualGamma == expectedGamma)
    }

    @Test("A generic caller can store any distribution of a value type")
    func existential() {
        let expected: [Double] = [1, 1]
        let sut: [any Distribution<Double>] = [NormalDistribution(mean: 1, standardDeviation: 0), ConstantDistribution(1.0)]
        var generator = Xoshiro256StarStar(seed: 42)

        let actual = sut.map { $0.sample(using: &generator) }

        #expect(actual == expected)
    }
}

/// A generator that returns its values in order, then zero.
private struct ScriptedGenerator: RandomNumberGenerator {
    var values: [UInt64]
    mutating func next() -> UInt64 { values.isEmpty ? 0 : values.removeFirst() }
}

/// A generator that counts its draws, each one above the last.
private struct CountingGenerator: RandomNumberGenerator {
    var draws = 0
    mutating func next() -> UInt64 {
        draws += 1
        return UInt64(draws)
    }
}

/// A generator that counts the draws it passes on from another.
private struct CountingWrapper<Base: RandomNumberGenerator>: RandomNumberGenerator {
    var base: Base
    var draws = 0
    mutating func next() -> UInt64 {
        draws += 1
        return base.next()
    }
}
