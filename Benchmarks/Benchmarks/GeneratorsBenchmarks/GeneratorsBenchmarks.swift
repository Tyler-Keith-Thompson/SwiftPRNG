import Benchmark
import Generators

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let draws = 100_000

    // The hand-written form the library must keep pace with: xoroshiro128+ inlined, state in locals.
    Benchmark("Generators: BASELINE inlined xoroshiro128+") { benchmark in
        for _ in benchmark.scaledIterations {
            var state0: UInt64 = 0xBDD7_32E6_F04F_1E1B
            var state1: UInt64 = 0x28EF_1934_6C3A_8E1F
            var sum: UInt64 = 0
            for _ in 0 ..< draws {
                let result = state0 &+ state1
                let mixed = state1 ^ state0
                state0 = ((state0 << 55) | (state0 >> 9)) ^ mixed ^ (mixed << 14)
                state1 = (mixed << 36) | (mixed >> 28)
                sum &+= result
            }
            blackHole(sum)
        }
    }

    Benchmark("Generators: Xoroshiro128Plus.next()") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoroshiro128Plus(seed: 42)
            var sum: UInt64 = 0
            for _ in 0 ..< draws { sum &+= generator.next() }
            blackHole(sum)
        }
    }

    Benchmark("Generators: Xoshiro256StarStar.next()") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            var sum: UInt64 = 0
            for _ in 0 ..< draws { sum &+= generator.next() }
            blackHole(sum)
        }
    }

    Benchmark("Generators: SplitMix64.next()") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = SplitMix64(seed: 42)
            var sum: UInt64 = 0
            for _ in 0 ..< draws { sum &+= generator.next() }
            blackHole(sum)
        }
    }

    Benchmark("Generators: SystemRandomNumberGenerator.next(), for scale") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = SystemRandomNumberGenerator()
            var sum: UInt64 = 0
            for _ in 0 ..< draws { sum &+= generator.next() }
            blackHole(sum)
        }
    }

    Benchmark("Generators: Xoshiro256StarStar.jump()") { benchmark in
        for _ in benchmark.scaledIterations {
            var generator = Xoshiro256StarStar(seed: 42)
            for _ in 0 ..< 100 { generator.jump() }
            blackHole(generator)
        }
    }
}
