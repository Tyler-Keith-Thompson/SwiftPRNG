// The distributions section (scripts/differential_distributions.py): one Xoshiro256StarStar seed
// and every distribution's parameters, three samples of each from a fresh generator, so the draws
// a sample consumes are compared as well as its value. Doubles are their shortest round-trip text.

import Distributions
import Generators

struct DistributionsCase: Decodable {
    let seed: UInt64
    let mean: Double
    let standardDeviation: Double
    let exponentialMean: Double
    let logMean: Double
    let logStandardDeviation: Double
    let lowerBound: Double
    let mode: Double
    let upperBound: Double
    let shape: Double
    let scale: Double
    let poissonMean: Double
    let probability: Double
    let weights: [Double]
}

struct DistributionsAnswer: Encodable {
    var normal: [String]
    var exponential: [String]
    var logNormal: [String]
    var triangular: [String]
    var gamma: [String]
    var poisson: [Int]
    var geometric: [Int]
    var weightedChoice: [Int]

    init(_ input: DistributionsCase) {
        func samples<D: Distribution>(_ distribution: D) -> [D.Value] {
            var generator = Xoshiro256StarStar(seed: input.seed)
            return (0 ..< 3).map { _ in distribution.sample(using: &generator) }
        }
        normal = samples(NormalDistribution(mean: input.mean, standardDeviation: input.standardDeviation)).map(\.description)
        exponential = samples(ExponentialDistribution(mean: input.exponentialMean)).map(\.description)
        logNormal = samples(LogNormalDistribution(mean: input.logMean, standardDeviation: input.logStandardDeviation)).map(\.description)
        triangular = samples(TriangularDistribution(lowerBound: input.lowerBound, mode: input.mode, upperBound: input.upperBound)).map(\.description)
        gamma = samples(GammaDistribution(shape: input.shape, scale: input.scale)).map(\.description)
        poisson = samples(PoissonDistribution(mean: input.poissonMean))
        geometric = samples(GeometricDistribution(probability: input.probability))
        weightedChoice = samples(WeightedChoiceDistribution(input.weights.enumerated().map { (value: $0.offset, weight: $0.element) }))
    }
}
