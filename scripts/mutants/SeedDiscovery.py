# Planted bugs for SeedDiscovery; run with `just mutate SeedDiscovery`. See scripts/mutate.py.
#
# Known equivalent mutants (they survive by design): none.

TESTS = ["SeedDiscoveryTests"]

S = "SeedSearch.swift"
C = "ConcurrentSeedSearch.swift"

MUTANTS = [
    Mutant("first_returnslast", S, "for seed in seeds where try predicate(seed) {\n            return seed\n        }\n        return nil", "var found: UInt64?\n        for seed in seeds where try predicate(seed) { found = seed }\n        return found", mode="stmt"),
    Mutant("first_skipsfirst", S, "for seed in seeds where try predicate(seed) {\n            return seed\n        }", "for seed in seeds.dropFirst() where try predicate(seed) {\n            return seed\n        }", mode="stmt"),
    Mutant("count_bytwo", S, "count += 1", "count += 2"),
    Mutant("concurrent_noworkerprecondition", C, 'precondition(workers >= 1, "A concurrent search needs at least one worker")', "", mode="stmt"),
    Mutant("concurrent_nobatchprecondition", C, 'precondition(batchSize >= 1, "A batch holds at least one seed")', "", mode="stmt"),
    Mutant("concurrent_laterbatchwins", C, "best.map({ finished.index < $0.index }) ?? true", "true"),
    Mutant("concurrent_keepsstarting", C, "worthStarting.map { batch.index < $0 } ?? true", "true"),
    Mutant("concurrent_firstskipslast", C, "for seed in batch.seeds where predicate(seed) {\n                return BatchMatch(index: batch.index, seed: seed)\n            }", "for seed in batch.seeds.dropLast() where predicate(seed) {\n                return BatchMatch(index: batch.index, seed: seed)\n            }", mode="stmt"),
    Mutant("concurrent_countdrops", C, "total += count", "total = count", mode="stmt"),
    Mutant("batches_overlap", C, "start = end", "start = end - 1", mode="stmt"),
    Mutant("batches_lookaheadignores", C, "wanted(batch)", "true"),
    Mutant("batches_short", C, "seeds.upperBound - start > size ? start + size : seeds.upperBound", "seeds.upperBound - start > size ? start + size - 1 : seeds.upperBound"),
    Mutant("batches_overflow", C, "seeds.upperBound - start > size ? start + size : seeds.upperBound", "min(start &+ size, seeds.upperBound)"),
    Mutant("batches_noindex", C, "index += 1", "", mode="stmt"),
]
