import Benchmark
import Distributions
import Foundation
import Generators

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let draws = 100_000

    // The hand-written forms the library must keep pace with: the same formulas on the
    // platform's math library, which is faster to call and differs between platforms.
    Benchmark("Distributions: BASELINE exponential with Foundation's log1p") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0.0
            for _ in 0 ..< draws { sum += -Foundation.log1p(-generator.uniform()) * 3 }
            blackHole(sum)
        }
    }

    Benchmark("Distributions: BASELINE Box–Muller with Foundation's log1p and cos") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0.0
            for _ in 0 ..< draws {
                let radius = (-2 * Foundation.log1p(-generator.uniform())).squareRoot()
                sum += radius * Foundation.cos(2 * Double.pi * generator.uniform())
            }
            blackHole(sum)
        }
    }

    func sampling<D: Distribution>(_ name: String, _ distribution: D, _ accumulate: @escaping @Sendable (inout Double, D.Value) -> Void) {
        Benchmark("Distributions: \(name)") { benchmark in
            for _ in benchmark.scaledIterations {
                var generator = Xoshiro256StarStar(seed: 42)
                var sum = 0.0
                for _ in 0 ..< draws { accumulate(&sum, distribution.sample(using: &generator)) }
                blackHole(sum)
            }
        }
    }

    sampling("exponential", ExponentialDistribution(mean: 3)) { $0 += $1 }
    sampling("normal", NormalDistribution(mean: 0, standardDeviation: 1)) { $0 += $1 }
    sampling("logNormal", LogNormalDistribution(mean: 0, standardDeviation: 1)) { $0 += $1 }
    sampling("triangular", TriangularDistribution(lowerBound: 0, mode: 1, upperBound: 4)) { $0 += $1 }
    sampling("gamma shape 2", GammaDistribution(shape: 2, scale: 1)) { $0 += $1 }
    sampling("gamma shape 0.5", GammaDistribution(shape: 0.5, scale: 1)) { $0 += $1 }
    sampling("poisson mean 4", PoissonDistribution(mean: 4)) { $0 += Double($1) }
    sampling("poisson mean 1000", PoissonDistribution(mean: 1000)) { $0 += Double($1) }
    sampling("geometric", GeometricDistribution(probability: 0.25)) { $0 += Double($1) }
    sampling("weightedChoice of 16", WeightedChoiceDistribution((0 ..< 16).map { (value: $0, weight: Double($0 + 1)) })) { $0 += Double($1) }
}
