// The distributions against a model of their parameters and support: each checked initializer
// throws exactly where the model says the parameters are invalid, a valid one builds the same
// distribution as the plain spelling, every sample lands in its support, and each sampler takes
// the draws its documentation states.

import Distributions
import FuzzSupport
import Generators

@main
enum FuzzDistributions {
    static func main() { runFuzzer(fuzz) }

    // Parameters at the edges of every domain: signs, zero, subnormals, 10 and 2³⁰ (the Poisson
    // thresholds), the largest finite values, infinities and NaN.
    static let anchors: [Double] = [
        -.infinity, -1e308, -1, -0.0, 0, .leastNonzeroMagnitude, 1e-300, 1e-9, 0.25, 0.5, 1, 1.nextUp, 2, 9.999, 10,
        1000, 1_073_741_824, 1_073_741_824.nextUp, 1e308, .greatestFiniteMagnitude, .infinity, .nan,
    ]

    static func parameter(_ input: inout FuzzInput) -> Double {
        anchors[input.int(below: anchors.count)]
    }

    static func fuzz(_ input: inout FuzzInput) {
        var generator = Xoshiro256StarStar(seed: UInt64(input.byte()) | UInt64(input.byte()) << 8)
        while !input.isEmpty {
            let first = parameter(&input)
            let second = parameter(&input)
            let third = parameter(&input)
            switch input.int(below: 8) {
            case 0:
                let valid = first.isFinite && second.isFinite && second >= 0
                let checked = try? NormalDistribution(checkedMean: first, standardDeviation: second)
                check((checked != nil) == valid, "checked normal(\(first), \(second)) disagrees with the model")
                guard let checked else { continue }
                check(checked == NormalDistribution(mean: first, standardDeviation: second), "checked normal differs from plain")
                let value = sampled(checked, expectedDraws: 2, &generator)
                check(!value.isNaN, "normal sample is NaN")
            case 1:
                let valid = first.isFinite && first > 0
                let checked = try? ExponentialDistribution(checkedMean: first)
                check((checked != nil) == valid, "checked exponential(\(first)) disagrees with the model")
                guard let checked else { continue }
                let value = sampled(checked, expectedDraws: 1, &generator)
                check(value >= 0, "exponential sample \(value) is negative")
            case 2:
                let valid = first.isFinite && second.isFinite && second >= 0
                let checked = try? LogNormalDistribution(checkedMean: first, standardDeviation: second)
                check((checked != nil) == valid, "checked log-normal(\(first), \(second)) disagrees with the model")
                guard let checked else { continue }
                let value = sampled(checked, expectedDraws: 2, &generator)
                check(value >= 0, "log-normal sample \(value) is negative")
            case 3:
                let bounds = [first, second, third].sorted { $0 < $1 || ($0.isNaN && !$1.isNaN) }
                let (lower, mode, upper) = (bounds[0], bounds[input.int(below: 3)], bounds[2])
                let valid = lower.isFinite && mode.isFinite && upper.isFinite && lower < upper && lower <= mode && mode <= upper
                let checked = try? TriangularDistribution(checkedLowerBound: lower, mode: mode, upperBound: upper)
                check((checked != nil) == valid, "checked triangular(\(lower), \(mode), \(upper)) disagrees with the model")
                guard let checked else { continue }
                let value = sampled(checked, expectedDraws: 1, &generator)
                check(value >= lower && value <= upper, "triangular sample \(value) outside \(lower) ... \(upper)")
            case 4:
                let valid = first.isFinite && first > 0 && second.isFinite && second > 0
                let checked = try? GammaDistribution(checkedShape: first, scale: second)
                check((checked != nil) == valid, "checked gamma(\(first), \(second)) disagrees with the model")
                guard let checked, first >= 1e-9 else { continue }
                var counting = Counting(base: generator)
                let value = checked.sample(using: &counting)
                generator = counting.base
                check(value >= 0, "gamma sample \(value) is negative")
                check(counting.draws >= (first < 1 ? 3 : 2), "gamma took \(counting.draws) draws, too few for an attempt")
            case 5:
                let valid = first >= 0 && first <= 1_073_741_824
                let checked = try? PoissonDistribution(checkedMean: first)
                check((checked != nil) == valid, "checked Poisson(\(first)) disagrees with the model")
                guard let checked else { continue }
                var counting = Counting(base: generator)
                let value = checked.sample(using: &counting)
                generator = counting.base
                check(value >= 0, "Poisson sample \(value) is negative")
                if first == 0 {
                    check(counting.draws == 0, "Poisson(0) took \(counting.draws) draws")
                } else if first < 10 {
                    check(counting.draws == value + 1, "Poisson(\(first)) took \(counting.draws) draws for \(value)")
                } else {
                    check(counting.draws >= 2 && counting.draws % 2 == 0, "Poisson(\(first)) took \(counting.draws) draws")
                    check(abs(Double(value) - first) < 40 * first.squareRoot() + 40, "Poisson(\(first)) sample \(value) is implausible")
                }
            case 6:
                let valid = first > 0 && first <= 1
                let checked = try? GeometricDistribution(checkedProbability: first)
                check((checked != nil) == valid, "checked geometric(\(first)) disagrees with the model")
                guard let checked else { continue }
                let value = sampled(checked, expectedDraws: 1, &generator)
                check(value >= 0, "geometric sample \(value) is negative")
                if first == 1 { check(value == 0, "geometric(1) sample \(value) is not zero") }
            default:
                let weights = (0 ..< input.int(in: 0 ... 5)).map { _ in parameter(&input) }
                let valid = weights.allSatisfy { $0.isFinite && $0 >= 0 } && weights.contains { $0 > 0 }
                let checked = try? WeightedChoiceDistribution(checked: weights.enumerated().map { (value: $0.offset, weight: $0.element) })
                check((checked != nil) == valid, "checked weighted choice of \(weights) disagrees with the model")
                guard let checked else { continue }
                check(checked.values == weights.indices.filter { weights[$0] > 0 }, "weighted choice kept the wrong values")
                let value = sampled(checked, expectedDraws: 1, &generator)
                check(weights[value] > 0, "weighted choice picked \(value), whose weight is \(weights[value])")
            }
        }
    }

    /// One sample, checking that it took exactly the draws documented.
    static func sampled<D: Distribution>(_ distribution: D, expectedDraws: Int, _ generator: inout Xoshiro256StarStar) -> D.Value {
        var counting = Counting(base: generator)
        let value = distribution.sample(using: &counting)
        generator = counting.base
        check(counting.draws == expectedDraws, "\(D.self) took \(counting.draws) draws, not \(expectedDraws)")
        return value
    }
}

/// A generator that counts the draws it passes on.
struct Counting: RandomNumberGenerator {
    var base: Xoshiro256StarStar
    var draws = 0

    mutating func next() -> UInt64 {
        draws += 1
        return base.next()
    }
}
