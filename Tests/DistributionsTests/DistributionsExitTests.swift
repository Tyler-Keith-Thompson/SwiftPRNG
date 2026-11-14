// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Distributions
import SwiftPRNGTestSupport
import Testing

@Suite("Distributions: traps")
struct DistributionsExitTests {
    @Test("A normal traps on a negative standard deviation", .tags(.precondition))
    func normalNegativeDeviation() async {
        await #expect(processExitsWith: .failure) {
            _ = NormalDistribution(mean: 0, standardDeviation: -1)
        }
    }

    @Test("A normal traps on an infinite mean", .tags(.precondition))
    func normalInfiniteMean() async {
        await #expect(processExitsWith: .failure) {
            _ = NormalDistribution(mean: .infinity, standardDeviation: 1)
        }
    }

    @Test("A log-normal traps on a NaN standard deviation", .tags(.precondition))
    func logNormalNaN() async {
        await #expect(processExitsWith: .failure) {
            _ = LogNormalDistribution(mean: 0, standardDeviation: .nan)
        }
    }

    @Test("An exponential traps on a mean of zero", .tags(.precondition))
    func exponentialZeroMean() async {
        await #expect(processExitsWith: .failure) {
            _ = ExponentialDistribution(mean: 0)
        }
    }

    @Test("An exponential traps on an infinite mean", .tags(.precondition))
    func exponentialInfiniteMean() async {
        await #expect(processExitsWith: .failure) {
            _ = ExponentialDistribution(mean: .infinity)
        }
    }

    @Test("A triangular traps on a mode outside its bounds", .tags(.precondition))
    func triangularModeOutside() async {
        await #expect(processExitsWith: .failure) {
            _ = TriangularDistribution(lowerBound: 0, mode: 5, upperBound: 4)
        }
    }

    @Test("A triangular traps on equal bounds", .tags(.precondition))
    func triangularEqualBounds() async {
        await #expect(processExitsWith: .failure) {
            _ = TriangularDistribution(lowerBound: 1, mode: 1, upperBound: 1)
        }
    }

    @Test("A triangular traps on an infinite bound", .tags(.precondition))
    func triangularInfiniteBound() async {
        await #expect(processExitsWith: .failure) {
            _ = TriangularDistribution(lowerBound: 0, mode: 1, upperBound: .infinity)
        }
    }

    @Test("A gamma traps on a shape of zero", .tags(.precondition))
    func gammaZeroShape() async {
        await #expect(processExitsWith: .failure) {
            _ = GammaDistribution(shape: 0, scale: 1)
        }
    }

    @Test("A gamma traps on a negative scale", .tags(.precondition))
    func gammaNegativeScale() async {
        await #expect(processExitsWith: .failure) {
            _ = GammaDistribution(shape: 1, scale: -1)
        }
    }

    @Test("A Poisson traps on a negative mean", .tags(.precondition))
    func poissonNegativeMean() async {
        await #expect(processExitsWith: .failure) {
            _ = PoissonDistribution(mean: -1)
        }
    }

    @Test("A Poisson traps on a mean above 2³⁰", .tags(.precondition))
    func poissonMeanTooLarge() async {
        await #expect(processExitsWith: .failure) {
            _ = PoissonDistribution(mean: PoissonDistribution.maximumMean.nextUp)
        }
    }

    @Test("A geometric traps on a probability of zero", .tags(.precondition))
    func geometricZero() async {
        await #expect(processExitsWith: .failure) {
            _ = GeometricDistribution(probability: 0)
        }
    }

    @Test("A geometric traps on a probability above one", .tags(.precondition))
    func geometricAboveOne() async {
        await #expect(processExitsWith: .failure) {
            _ = GeometricDistribution(probability: 1.5)
        }
    }

    @Test("A weighted choice traps when every weight is zero", .tags(.precondition))
    func weightedChoiceAllZero() async {
        await #expect(processExitsWith: .failure) {
            _ = WeightedChoiceDistribution([(value: 1, weight: 0), (value: 2, weight: 0)])
        }
    }

    @Test("A weighted choice traps on no choices", .tags(.precondition))
    func weightedChoiceEmpty() async {
        await #expect(processExitsWith: .failure) {
            _ = WeightedChoiceDistribution<Int>([])
        }
    }

    @Test("A weighted choice traps on a negative weight", .tags(.precondition))
    func weightedChoiceNegative() async {
        await #expect(processExitsWith: .failure) {
            _ = WeightedChoiceDistribution([(value: 1, weight: 2), (value: 2, weight: -1)])
        }
    }

    @Test("A weighted choice traps on an infinite weight", .tags(.precondition))
    func weightedChoiceInfinite() async {
        await #expect(processExitsWith: .failure) {
            _ = WeightedChoiceDistribution([(value: 1, weight: .infinity)])
        }
    }
}
