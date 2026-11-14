// Exit tests, in a file of their own: each runs its body in a child process, which some platforms
// (WASI) cannot start, and those builds leave out every file holding one.

import SeedDiscovery
import SwiftPRNGTestSupport
import Testing

@Suite("ConcurrentSeedSearch: traps")
struct ConcurrentSeedSearchExitTests {
    @Test("Zero workers trap", .tags(.precondition))
    func zeroWorkers() async {
        await #expect(processExitsWith: .failure) {
            _ = SeedSearch(0 ..< 10).concurrent(workers: 0)
        }
    }

    @Test("A batch size of zero traps", .tags(.precondition))
    func zeroBatchSize() async {
        await #expect(processExitsWith: .failure) {
            _ = ConcurrentSeedSearch(0 ..< 10, workers: 1, batchSize: 0)
        }
    }
}
