// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import Generators
import Sampling
import SwiftPRNGTestSupport
import Testing

@Suite("Sampling: traps")
struct SamplingExitTests {
    @Test("integer(in:) traps on an empty range", .tags(.precondition))
    func emptyIntegerRange() async {
        await #expect(processExitsWith: .failure) {
            var generator = Xoshiro256StarStar(seed: 1)
            _ = generator.integer(in: 5 ..< 5)
        }
    }

    @Test("uniform(in:) traps on an empty range", .tags(.precondition))
    func emptyInterval() async {
        await #expect(processExitsWith: .failure) {
            var generator = Xoshiro256StarStar(seed: 1)
            _ = generator.uniform(in: 5 ..< 5)
        }
    }

    @Test("uniform(in:) traps on an infinite bound", .tags(.precondition))
    func infiniteInterval() async {
        await #expect(processExitsWith: .failure) {
            var generator = Xoshiro256StarStar(seed: 1)
            _ = generator.uniform(in: 0 ..< .infinity)
        }
    }

    @Test("bernoulli(_:) traps on a probability above one", .tags(.precondition))
    func probabilityAboveOne() async {
        await #expect(processExitsWith: .failure) {
            var generator = Xoshiro256StarStar(seed: 1)
            _ = generator.bernoulli(1.5)
        }
    }

    @Test("bernoulli(_:) traps on a negative probability", .tags(.precondition))
    func negativeProbability() async {
        await #expect(processExitsWith: .failure) {
            var generator = Xoshiro256StarStar(seed: 1)
            _ = generator.bernoulli(-0.5)
        }
    }
}
