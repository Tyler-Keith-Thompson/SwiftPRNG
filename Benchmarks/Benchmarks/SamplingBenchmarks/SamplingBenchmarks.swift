import Benchmark
import Generators
import Sampling

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let draws = 100_000

    // The hand-written form the library must keep pace with: the standard library's range draw.
    Benchmark("Sampling: BASELINE Int.random(in:using:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0
            for _ in 0 ..< draws { sum &+= Int.random(in: -1000 ..< 1000, using: &generator) }
            blackHole(sum)
        }
    }

    Benchmark("Sampling: integer(in:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0
            for _ in 0 ..< draws { sum &+= generator.integer(in: -1000 ..< 1000) }
            blackHole(sum)
        }
    }

    // The standard library's unit draw, for comparison with uniform().
    Benchmark("Sampling: BASELINE Double.random(in:using:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0.0
            for _ in 0 ..< draws { sum += Double.random(in: 0 ..< 1, using: &generator) }
            blackHole(sum)
        }
    }

    Benchmark("Sampling: uniform()") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0.0
            for _ in 0 ..< draws { sum += generator.uniform() }
            blackHole(sum)
        }
    }

    Benchmark("Sampling: uniform(in:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0.0
            for _ in 0 ..< draws { sum += generator.uniform(in: -1000 ..< 1000) }
            blackHole(sum)
        }
    }

    Benchmark("Sampling: bernoulli(_:)") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var successes = 0
            for _ in 0 ..< draws where generator.bernoulli(0.3) { successes += 1 }
            blackHole(successes)
        }
    }
}
