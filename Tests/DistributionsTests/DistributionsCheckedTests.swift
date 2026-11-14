// The checked initializers: each throws InvalidParameters exactly where the plain one traps, and
// otherwise builds the same distribution.

import Distributions
import SwiftPRNGTestSupport
import Testing

@Suite("Distributions: checked spellings")
struct DistributionsCheckedTests {
    @Test("A checked normal throws on a negative or nonfinite parameter")
    func normal() throws {
        func negative() throws(InvalidParameters) { _ = try NormalDistribution(checkedMean: 0, standardDeviation: -1) }
        func nanMean() throws(InvalidParameters) { _ = try NormalDistribution(checkedMean: .nan, standardDeviation: 1) }
        func infiniteDeviation() throws(InvalidParameters) { _ = try NormalDistribution(checkedMean: 0, standardDeviation: .infinity) }
        let expected = NormalDistribution(mean: 2, standardDeviation: 0)

        let actual = try NormalDistribution(checkedMean: 2, standardDeviation: 0)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: negative)
        #expect(throws: InvalidParameters.self, performing: nanMean)
        #expect(throws: InvalidParameters.self, performing: infiniteDeviation)
    }

    @Test("A checked log-normal throws on a negative or nonfinite parameter")
    func logNormal() throws {
        func negative() throws(InvalidParameters) { _ = try LogNormalDistribution(checkedMean: 0, standardDeviation: -0.5) }
        func infiniteMean() throws(InvalidParameters) { _ = try LogNormalDistribution(checkedMean: -.infinity, standardDeviation: 1) }
        let expected = LogNormalDistribution(mean: 1, standardDeviation: 2)

        let actual = try LogNormalDistribution(checkedMean: 1, standardDeviation: 2)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: negative)
        #expect(throws: InvalidParameters.self, performing: infiniteMean)
    }

    @Test("A checked exponential throws on a mean that is not finite and positive")
    func exponential() throws {
        func zero() throws(InvalidParameters) { _ = try ExponentialDistribution(checkedMean: 0) }
        func negative() throws(InvalidParameters) { _ = try ExponentialDistribution(checkedMean: -1) }
        func infinite() throws(InvalidParameters) { _ = try ExponentialDistribution(checkedMean: .infinity) }
        func nan() throws(InvalidParameters) { _ = try ExponentialDistribution(checkedMean: .nan) }
        let expected = ExponentialDistribution(mean: .leastNonzeroMagnitude)

        let actual = try ExponentialDistribution(checkedMean: .leastNonzeroMagnitude)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: zero)
        #expect(throws: InvalidParameters.self, performing: negative)
        #expect(throws: InvalidParameters.self, performing: infinite)
        #expect(throws: InvalidParameters.self, performing: nan)
    }

    @Test("A checked triangular throws on bounds that are not increasing or a mode outside them")
    func triangular() throws {
        func equalBounds() throws(InvalidParameters) { _ = try TriangularDistribution(checkedLowerBound: 1, mode: 1, upperBound: 1) }
        func modeBelow() throws(InvalidParameters) { _ = try TriangularDistribution(checkedLowerBound: 0, mode: -1, upperBound: 1) }
        func modeAbove() throws(InvalidParameters) { _ = try TriangularDistribution(checkedLowerBound: 0, mode: 2, upperBound: 1) }
        func infinite() throws(InvalidParameters) { _ = try TriangularDistribution(checkedLowerBound: -.infinity, mode: 0, upperBound: 1) }
        func nanMode() throws(InvalidParameters) { _ = try TriangularDistribution(checkedLowerBound: 0, mode: .nan, upperBound: 1) }
        let expected = TriangularDistribution(lowerBound: 0, mode: 1, upperBound: 1)

        let actual = try TriangularDistribution(checkedLowerBound: 0, mode: 1, upperBound: 1)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: equalBounds)
        #expect(throws: InvalidParameters.self, performing: modeBelow)
        #expect(throws: InvalidParameters.self, performing: modeAbove)
        #expect(throws: InvalidParameters.self, performing: infinite)
        #expect(throws: InvalidParameters.self, performing: nanMode)
    }

    @Test("A checked gamma throws on a shape or scale that is not finite and positive")
    func gamma() throws {
        func zeroShape() throws(InvalidParameters) { _ = try GammaDistribution(checkedShape: 0, scale: 1) }
        func zeroScale() throws(InvalidParameters) { _ = try GammaDistribution(checkedShape: 1, scale: 0) }
        func infiniteShape() throws(InvalidParameters) { _ = try GammaDistribution(checkedShape: .infinity) }
        func nanScale() throws(InvalidParameters) { _ = try GammaDistribution(checkedShape: 1, scale: .nan) }
        let expected = GammaDistribution(shape: 0.1, scale: 1)

        let actual = try GammaDistribution(checkedShape: 0.1)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: zeroShape)
        #expect(throws: InvalidParameters.self, performing: zeroScale)
        #expect(throws: InvalidParameters.self, performing: infiniteShape)
        #expect(throws: InvalidParameters.self, performing: nanScale)
    }

    @Test("A checked Poisson throws on a mean outside 0 ... 2³⁰")
    func poisson() throws {
        func negative() throws(InvalidParameters) { _ = try PoissonDistribution(checkedMean: -0.5) }
        func tooLarge() throws(InvalidParameters) { _ = try PoissonDistribution(checkedMean: PoissonDistribution.maximumMean.nextUp) }
        func nan() throws(InvalidParameters) { _ = try PoissonDistribution(checkedMean: .nan) }
        let expectedZero = PoissonDistribution(mean: 0)
        let expectedLargest = PoissonDistribution(mean: PoissonDistribution.maximumMean)

        let actualZero = try PoissonDistribution(checkedMean: 0)
        let actualLargest = try PoissonDistribution(checkedMean: PoissonDistribution.maximumMean)

        #expect(actualZero == expectedZero)
        #expect(actualLargest == expectedLargest)
        #expect(throws: InvalidParameters.self, performing: negative)
        #expect(throws: InvalidParameters.self, performing: tooLarge)
        #expect(throws: InvalidParameters.self, performing: nan)
    }

    @Test("A checked geometric throws on a probability outside (0, 1]")
    func geometric() throws {
        func zero() throws(InvalidParameters) { _ = try GeometricDistribution(checkedProbability: 0) }
        func aboveOne() throws(InvalidParameters) { _ = try GeometricDistribution(checkedProbability: 1.nextUp) }
        func nan() throws(InvalidParameters) { _ = try GeometricDistribution(checkedProbability: .nan) }
        let expected = GeometricDistribution(probability: 1)

        let actual = try GeometricDistribution(checkedProbability: 1)

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: zero)
        #expect(throws: InvalidParameters.self, performing: aboveOne)
        #expect(throws: InvalidParameters.self, performing: nan)
    }

    @Test("A checked weighted choice throws on no positive weight or a negative or nonfinite one")
    func weightedChoice() throws {
        func empty() throws(InvalidParameters) { _ = try WeightedChoiceDistribution<Int>(checked: []) }
        func allZero() throws(InvalidParameters) { _ = try WeightedChoiceDistribution(checked: [(value: 1, weight: 0)]) }
        func negative() throws(InvalidParameters) { _ = try WeightedChoiceDistribution(checked: [(value: 1, weight: 1), (value: 2, weight: -1)]) }
        func nan() throws(InvalidParameters) { _ = try WeightedChoiceDistribution(checked: [(value: 1, weight: 1), (value: 2, weight: .nan)]) }
        func infinite() throws(InvalidParameters) { _ = try WeightedChoiceDistribution(checked: [(value: 1, weight: .infinity)]) }
        let expected = [2]

        let actual = try WeightedChoiceDistribution(checked: [(value: 1, weight: 0), (value: 2, weight: 1)]).values

        #expect(actual == expected)
        #expect(throws: InvalidParameters.self, performing: empty)
        #expect(throws: InvalidParameters.self, performing: allZero)
        #expect(throws: InvalidParameters.self, performing: negative)
        #expect(throws: InvalidParameters.self, performing: nan)
        #expect(throws: InvalidParameters.self, performing: infinite)
    }
}
