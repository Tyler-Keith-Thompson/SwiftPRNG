// Property tests against naive references: the portable math within one ulp of the platform's,
// the weighted choice's binary search against a linear scan, and every sample inside its support.

import Distributions
import Foundation
import Generators
import PropertyBased
import Sampling
import SwiftPRNGTestSupport
import Testing

@Suite("Distributions: properties")
struct DistributionsPropertyTests {
    @Test("Fdlibm's log, log1p and exp are within one ulp of the platform's", .tags(.randomized))
    func portableMath() async {
        await propertyCheck(count: 2000, input: Gen.double(in: -300 ... 300), Gen.double(in: 0 ..< 1), Gen.double(in: -745 ... 709)) { exponent, unit, power in
            let x = Foundation.pow(10, exponent)
            let expectedLog = Foundation.log(x)
            let expectedLog1p = Foundation.log1p(-unit)
            let expectedLog1pLarge = Foundation.log1p(x)
            let expectedExp = Foundation.exp(power)

            let actualLog = Fdlibm.log(x)
            let actualLog1p = Fdlibm.log1p(-unit)
            let actualLog1pLarge = Fdlibm.log1p(x)
            let actualExp = Fdlibm.exp(power)

            #expect(abs(actualLog - expectedLog) <= expectedLog.ulp)
            #expect(abs(actualLog1p - expectedLog1p) <= expectedLog1p.ulp)
            #expect(abs(actualLog1pLarge - expectedLog1pLarge) <= expectedLog1pLarge.ulp)
            #expect(abs(actualExp - expectedExp) <= expectedExp.ulp)
        }
    }

    @Test("Fdlibm's cosPi agrees with the platform's cos(πx) to within the rounding of πx", .tags(.randomized))
    func portableCosine() async {
        await propertyCheck(count: 2000, input: Gen.double(in: 0 ..< 2)) { x in
            let expected = Foundation.cos(Double.pi * x)

            let actual = Fdlibm.cosPi(x)

            #expect(abs(actual - expected) <= 4 * Double.ulpOfOne)
        }
    }

    @Test("Fdlibm's special values: log of 0, 1 and negatives, log1p of −1, exp at its limits")
    func portableMathSpecialValues() {
        let negativeInfinity = -Double.infinity

        #expect(Fdlibm.log(0) == negativeInfinity)
        #expect(Fdlibm.log(1) == 0)
        #expect(Fdlibm.log(-1).isNaN)
        #expect(Fdlibm.log(.infinity) == .infinity)
        #expect(Fdlibm.log(.leastNonzeroMagnitude) == Foundation.log(Double.leastNonzeroMagnitude))
        #expect(Fdlibm.log1p(-1) == negativeInfinity)
        #expect(Fdlibm.log1p(-2).isNaN)
        #expect(Fdlibm.log1p(1e-20) == 1e-20)
        #expect(Fdlibm.exp(0) == 1)
        #expect(Fdlibm.exp(710) == .infinity)
        #expect(Fdlibm.exp(-746) == 0)
        #expect(Fdlibm.exp(-740) == Foundation.exp(-740))
        #expect(Fdlibm.exp(.nan).isNaN)
        #expect(Fdlibm.cosPi(0) == 1)
        #expect(Fdlibm.cosPi(1) == -1)
        #expect(Fdlibm.cosPi(0.5) == 0)
    }

    @Test("Fdlibm's log1p corrects for the rounding of 1 + x, matching the platform where the uncorrected value is an ulp off")
    func log1pCorrection() {
        let x = 1.8824886053307643
        let expected = 1.058654020102358

        let actual = Fdlibm.log1p(x)

        #expect(actual == expected)
        #expect(actual == Foundation.log1p(x))
    }

    @Test("The Poisson sampler's log-gamma is within 1e-12 of the platform's lgamma", .tags(.randomized))
    func logGamma() async {
        await propertyCheck(count: 500, input: Gen.int(in: 1 ... 1_000_000)) { n in
            let x = Double(n)
            let expected: Double = lgamma(x)

            let actual = PoissonDistribution.logGamma(x)

            #expect(abs(actual - expected) <= 1e-12 * max(1, abs(expected)))
        }
    }

    @Test("The log-gamma of 1 through 40 is within 1e-13 of the platform's lgamma, through the shifted recurrence below 7")
    func logGammaSmall() {
        for n in 1 ... 40 {
            let x = Double(n)
            let expected: Double = lgamma(x)

            let actual = PoissonDistribution.logGamma(x)

            #expect(abs(actual - expected) <= 1e-13 * max(1, abs(expected)))
        }
    }

    @Test("A weighted choice equals a linear scan over the running totals", .tags(.randomized))
    func weightedChoiceLinearScan() async {
        let weights = Gen.double(in: 0 ... 10).array(of: 1 ... 12).filter { $0.contains { $0 > 0 } }
        await propertyCheck(count: 500, input: Gen.uint64(), weights) { seed, weights in
            let largest = weights.max()!
            var totals: [(index: Int, total: Double)] = []
            var total = 0.0
            for (index, weight) in weights.enumerated() where weight > 0 {
                total += weight / largest
                totals.append((index: index, total: total))
            }
            var reference = Xoshiro256StarStar(seed: seed)
            let threshold = reference.uniform() * total
            let expected = totals.first { $0.total > threshold }?.index ?? totals[totals.count - 1].index
            let sut = WeightedChoiceDistribution(weights.enumerated().map { (value: $0.offset, weight: $0.element) })
            var generator = Xoshiro256StarStar(seed: seed)

            let actual = sut.sample(using: &generator)

            #expect(actual == expected)
            #expect(weights[actual] > 0)
        }
    }

    @Test("A triangular sample lies inside its bounds for any parameters", .tags(.randomized))
    func triangularInBounds() async {
        let parameters = Gen.double(in: -1e300 ... 1e300).array(of: 3).map { $0.sorted() }.filter { $0[0] < $0[2] }
        await propertyCheck(count: 500, input: Gen.uint64(), parameters) { seed, parameters in
            let sut = TriangularDistribution(lowerBound: parameters[0], mode: parameters[1], upperBound: parameters[2])
            var generator = Xoshiro256StarStar(seed: seed)

            let actual = sut.sample(using: &generator)

            #expect(actual >= parameters[0] && actual <= parameters[2])
        }
    }

    @Test("Gamma, exponential and log-normal samples are nonnegative; Poisson and geometric counts too", .tags(.randomized))
    func nonnegativeSupport() async {
        await propertyCheck(count: 500, input: Gen.uint64(), Gen.double(in: -2 ... 3), Gen.double(in: 0 ... 1)) { seed, exponent, unit in
            let parameter = Foundation.pow(10, exponent)
            var generator = Xoshiro256StarStar(seed: seed)

            let gamma = GammaDistribution(shape: parameter, scale: 1).sample(using: &generator)
            let exponential = ExponentialDistribution(mean: parameter).sample(using: &generator)
            let logNormal = LogNormalDistribution(mean: 0, standardDeviation: parameter.squareRoot()).sample(using: &generator)
            let poisson = PoissonDistribution(mean: parameter).sample(using: &generator)
            let geometric = GeometricDistribution(probability: max(unit, 1e-9)).sample(using: &generator)

            #expect(gamma >= 0 && !gamma.isNaN)
            #expect(exponential >= 0)
            #expect(logNormal >= 0)
            #expect(poisson >= 0)
            #expect(geometric >= 0)
        }
    }
}
