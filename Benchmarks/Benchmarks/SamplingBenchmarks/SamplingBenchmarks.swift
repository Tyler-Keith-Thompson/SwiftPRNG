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

    // The hand-written form the library must keep pace with: Fisher-Yates over integer(in:).
    Benchmark("Sampling: BASELINE Fisher-Yates loop") { benchmark in
        var elements = Array(0 ..< draws)
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            for i in stride(from: elements.count - 1, to: 0, by: -1) {
                elements.swapAt(i, generator.integer(in: 0 ... i))
            }
            blackHole(elements)
        }
    }

    Benchmark("Sampling: shuffle(_:)") { benchmark in
        var elements = Array(0 ..< draws)
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            generator.shuffle(&elements)
            blackHole(elements)
        }
    }

    Benchmark("Sampling: shuffled(_:)") { benchmark in
        let elements = Array(0 ..< draws)
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            blackHole(generator.shuffled(elements))
        }
    }

    // The hand-written pick with element(in:)'s contract: no draw for an empty array. A bare
    // subscript would trap on empty instead, which lets the optimizer hoist the rejection
    // threshold out of the loop, so it is not the same work.
    Benchmark("Sampling: BASELINE subscript at integer(in:)") { benchmark in
        let elements = Array(0 ..< 1000)
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0
            for _ in 0 ..< draws {
                sum &+= elements.isEmpty ? 0 : elements[generator.integer(in: 0 ..< elements.count)]
            }
            blackHole(sum)
        }
    }

    Benchmark("Sampling: element(in:)") { benchmark in
        let elements = Array(0 ..< 1000)
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum = 0
            for _ in 0 ..< draws { sum &+= generator.element(in: elements) ?? 0 }
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
