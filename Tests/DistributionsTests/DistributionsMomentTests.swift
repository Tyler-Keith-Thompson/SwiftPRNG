// Fixed-seed sample moments: 100,000 samples from Xoshiro256StarStar(seed: 1) put each
// distribution's mean and variance within the tolerances stated, about six standard errors of
// each estimate. A fixed seed makes every result deterministic; the tolerances say how far an
// honest sampler could land, so a changed algorithm that still passes is still a correct one.

import Distributions
import Generators
import SwiftPRNGTestSupport
import Testing

@Suite("Distributions: moments")
struct DistributionsMomentTests {
    @Test("A normal's sample mean and variance match its parameters", arguments: [
        (mean: 5.0, standardDeviation: 2.0, meanTolerance: 0.04, varianceTolerance: 0.11),
        (mean: -100.0, standardDeviation: 0.1, meanTolerance: 0.002, varianceTolerance: 0.0003),
    ])
    func normal(_ parameters: (mean: Double, standardDeviation: Double, meanTolerance: Double, varianceTolerance: Double)) {
        let expectedVariance = parameters.standardDeviation * parameters.standardDeviation
        let sut = NormalDistribution(mean: parameters.mean, standardDeviation: parameters.standardDeviation)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in sut.sample(using: &generator) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - parameters.mean) < parameters.meanTolerance)
        #expect(abs(actualVariance - expectedVariance) < parameters.varianceTolerance)
    }

    @Test("An exponential's sample mean and variance are its mean and its mean squared")
    func exponential() {
        let expectedMean = 3.0
        let expectedVariance = 9.0
        let sut = ExponentialDistribution(mean: 3)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in sut.sample(using: &generator) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - expectedMean) < 0.06)
        #expect(abs(actualVariance - expectedVariance) < 0.6)
    }

    @Test("A triangular's sample mean is (a + b + c) / 3 and its variance (a² + b² + c² − ab − ac − bc) / 18")
    func triangular() {
        let expectedMean = 5.0 / 3.0
        let expectedVariance = 13.0 / 18.0
        let sut = TriangularDistribution(lowerBound: 0, mode: 1, upperBound: 4)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in sut.sample(using: &generator) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - expectedMean) < 0.02)
        #expect(abs(actualVariance - expectedVariance) < 0.02)
    }

    @Test("A log-normal's sample mean is e^(μ + σ²/2) and its variance (e^σ² − 1)e^(2μ + σ²)")
    func logNormal() {
        let expectedMean = 1.1331484530668263   // e^0.125
        let expectedVariance = 0.36468328289848  // (e^0.25 − 1) e^0.25
        let sut = LogNormalDistribution(mean: 0, standardDeviation: 0.5)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in sut.sample(using: &generator) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - expectedMean) < 0.012)
        #expect(abs(actualVariance - expectedVariance) < 0.03)
    }

    @Test("A gamma's sample mean is kθ and its variance kθ², above and below a shape of 1", arguments: [
        (shape: 2.5, scale: 2.0, meanTolerance: 0.06, varianceTolerance: 0.6),
        (shape: 0.5, scale: 1.0, meanTolerance: 0.015, varianceTolerance: 0.04),
        (shape: 1.0, scale: 3.0, meanTolerance: 0.06, varianceTolerance: 0.6),
    ])
    func gamma(_ parameters: (shape: Double, scale: Double, meanTolerance: Double, varianceTolerance: Double)) {
        let expectedMean = parameters.shape * parameters.scale
        let expectedVariance = parameters.shape * parameters.scale * parameters.scale
        let sut = GammaDistribution(shape: parameters.shape, scale: parameters.scale)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in sut.sample(using: &generator) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - expectedMean) < parameters.meanTolerance)
        #expect(abs(actualVariance - expectedVariance) < parameters.varianceTolerance)
    }

    @Test("A Poisson's sample mean and variance are both its mean, by either method", arguments: [
        (mean: 4.0, meanTolerance: 0.04, varianceTolerance: 0.15),
        (mean: 10.0, meanTolerance: 0.06, varianceTolerance: 0.3),
        (mean: 250.0, meanTolerance: 0.3, varianceTolerance: 7.0),
    ])
    func poisson(_ parameters: (mean: Double, meanTolerance: Double, varianceTolerance: Double)) {
        let sut = PoissonDistribution(mean: parameters.mean)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in Double(sut.sample(using: &generator)) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - parameters.mean) < parameters.meanTolerance)
        #expect(abs(actualVariance - parameters.mean) < parameters.varianceTolerance)
    }

    @Test("A geometric's sample mean is (1 − p) / p and its variance (1 − p) / p²")
    func geometric() {
        let expectedMean = 3.0
        let expectedVariance = 12.0
        let sut = GeometricDistribution(probability: 0.25)
        var generator = Xoshiro256StarStar(seed: 1)

        let samples = (0 ..< 100_000).map { _ in Double(sut.sample(using: &generator)) }

        let actualMean = samples.reduce(0, +) / Double(samples.count)
        let actualVariance = samples.reduce(0) { $0 + ($1 - actualMean) * ($1 - actualMean) } / Double(samples.count - 1)
        #expect(abs(actualMean - expectedMean) < 0.07)
        #expect(abs(actualVariance - expectedVariance) < 0.8)
    }

    @Test("A weighted choice picks each value in proportion to its weight")
    func weightedChoice() {
        let expected: [Double] = [1.0 / 6.0, 2.0 / 6.0, 3.0 / 6.0]
        let sut = WeightedChoiceDistribution([(value: 0, weight: 1), (value: 1, weight: 2), (value: 2, weight: 3)])
        var generator = Xoshiro256StarStar(seed: 1)
        var counts = [0, 0, 0]

        for _ in 0 ..< 100_000 { counts[sut.sample(using: &generator)] += 1 }

        let actual = counts.map { Double($0) / 100_000 }
        for (actualShare, expectedShare) in zip(actual, expected) {
            #expect(abs(actualShare - expectedShare) < 0.01)
        }
    }
}
