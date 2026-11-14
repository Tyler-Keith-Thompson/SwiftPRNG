import Benchmark
import SeedTrees

let benchmarks: @Sendable () -> Void = {
    Benchmark.defaultConfiguration.metrics = [.wallClock, .mallocCountTotal]
    Benchmark.defaultConfiguration.maxDuration = .seconds(2)

    let agents = 10_000

    // The hand-written form the library must keep pace with: the derivation chain inlined, with
    // the name's mixing value computed once and the index's each time.
    Benchmark("SeedTrees: BASELINE inlined SplitMix64 chain") { benchmark in
        func derive(_ value: UInt64) -> UInt64 {
            var mixed = value &+ 0x9E37_79B9_7F4A_7C15
            mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
            mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
            return mixed ^ (mixed >> 31)
        }
        func nameMixing(_ name: String) -> UInt64 {
            var hash: UInt64 = 0xCBF2_9CE4_8422_2325
            for byte in name.utf8 { hash = (hash ^ UInt64(byte)) &* 0x0000_0100_0000_01B3 }
            return derive(hash)
        }
        for _ in benchmark.scaledIterations {
            let agent = derive(42 ^ nameMixing("agent"))
            let delay = nameMixing("delay")
            var sum: UInt64 = 0
            for index in 0 ..< agents {
                let node = derive(agent ^ derive(UInt64(bitPattern: Int64(index)) ^ 0x6A09_E667_F3BC_C908))
                sum &+= derive(node ^ delay)
            }
            blackHole(sum)
        }
    }

    Benchmark("SeedTrees: tree[\"agent\", index, \"delay\"].seed") { benchmark in
        for _ in benchmark.scaledIterations {
            let tree = SeedTree(42)
            var sum: UInt64 = 0
            for index in 0 ..< agents { sum &+= tree["agent", index, "delay"].seed }
            blackHole(sum)
        }
    }

    Benchmark("SeedTrees: tree[\"agent\"][index][\"delay\"].seed, stepwise") { benchmark in
        for _ in benchmark.scaledIterations {
            let agent = SeedTree(42)["agent"]
            var sum: UInt64 = 0
            for index in 0 ..< agents { sum &+= agent[index]["delay"].seed }
            blackHole(sum)
        }
    }

    Benchmark("SeedTrees: tree[\"agent\", index, \"delay\"].seed with one override") { benchmark in
        for _ in benchmark.scaledIterations {
            let tree = SeedTree(42).overriding(["agent", 7], with: 99)
            var sum: UInt64 = 0
            for index in 0 ..< agents { sum &+= tree["agent", index, "delay"].seed }
            blackHole(sum)
        }
    }

    Benchmark("SeedTrees: node.uniform()") { benchmark in
        for _ in benchmark.scaledIterations {
            let agent = SeedTree(42)["agent"]
            var sum = 0.0
            for index in 0 ..< agents { sum += agent[index].uniform() }
            blackHole(sum)
        }
    }
}
