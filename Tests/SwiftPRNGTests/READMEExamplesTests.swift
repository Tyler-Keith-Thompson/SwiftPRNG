// The README's example, verbatim, so the README cannot drift from the code. The same snippet opens
// the SwiftPRNG catalog's landing page (Sources/SwiftPRNG/SwiftPRNG.docc/SwiftPRNG.md).

import SwiftPRNG
import Testing

@Suite("README examples", .timeLimit(.minutes(1)))
struct READMEExamplesTests {
    @Test("README.md: fitting customer 7 gives an override that rebuilds anywhere")
    func fitting() throws {
        let tree = SeedTree(42)
        let fitted = tree.fitting(["customer", 7], in: SeedSearch(0 ..< 100_000)) { tree in
            tree["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1
        }
        let overrides = fitted?.overriddenSeeds  // [["customer", 7]: 33]

        let rebuilt = SeedTree(42, overrides: try #require(overrides))
        #expect(overrides == [["customer", 7]: 33])
        #expect(rebuilt["customer", 7, "arrival"].uniform(in: 0 ..< 60) < 1)
        #expect(rebuilt["customer", 8] == tree["customer", 8].overriding(["customer", 7], with: 33))
        #expect(rebuilt["customer", 8].seed == tree["customer", 8].seed)
    }
}
