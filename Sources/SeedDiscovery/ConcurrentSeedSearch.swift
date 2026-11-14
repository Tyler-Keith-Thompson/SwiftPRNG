import Foundation

/// A ``SeedSearch`` spread over several tasks, which finds the same seeds the sequential search
/// does: the smallest match, whatever order the tasks finish in.
///
/// The seeds are cut into batches of ``batchSize`` consecutive seeds, dispatched in order with
/// ``workers`` in flight. A match in one batch stops later batches from starting, and the batches
/// before it run to the end, so the answer is the lowest match. Made with
/// ``SeedSearch/concurrent(workers:batchSize:)``.
///
/// ```swift
/// let seed = await SeedSearch(0 ..< 10_000_000).concurrent().first { seed in
///     var generator = Xoshiro256StarStar(seed: seed)
///     return generator.uniform() > 0.999_999
/// }
/// ```
@frozen
public struct ConcurrentSeedSearch: Hashable, Sendable {
    /// The candidates, tried from the lowest up.
    public var seeds: Range<UInt64>
    /// How many batches are tried at once.
    public var workers: Int
    /// How many consecutive seeds each task tries before reporting.
    public var batchSize: UInt64

    /// The number of processors, the default for ``workers``.
    public static var defaultWorkers: Int { ProcessInfo.processInfo.activeProcessorCount }

    /// A search over `seeds` with `workers` batches of `batchSize` seeds in flight.
    ///
    /// Traps when `workers` or `batchSize` is below 1.
    public init(_ seeds: Range<UInt64>, workers: Int = Self.defaultWorkers, batchSize: UInt64 = 1024) {
        precondition(workers >= 1, "A concurrent search needs at least one worker")
        precondition(batchSize >= 1, "A batch holds at least one seed")
        self.seeds = seeds
        self.workers = workers
        self.batchSize = batchSize
    }

    /// The smallest seed in ``seeds`` the predicate accepts, or `nil` when it accepts none.
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the position of the match
    ///   rounded up to the batches in flight.
    public func first(where predicate: @Sendable @escaping (UInt64) -> Bool) async -> UInt64? {
        let scan: @Sendable (Batch) -> BatchMatch? = { batch in
            for seed in batch.seeds where predicate(seed) {
                return BatchMatch(index: batch.index, seed: seed)
            }
            return nil
        }
        return await withTaskGroup(of: BatchMatch?.self) { group in
            var batches = self.batches
            var best: BatchMatch?
            var inFlight = 0
            while inFlight < workers, let batch = batches.next() {
                inFlight += 1
                group.addTask { scan(batch) }
            }
            while let finished = await group.next() {
                inFlight -= 1
                if let finished, best.map({ finished.index < $0.index }) ?? true {
                    best = finished
                }
                // Batches past the best match so far are not worth starting; those already in
                // flight run to the end, and the lowest match among them all wins.
                let worthStarting = best?.index
                if let batch = batches.next(where: { batch in worthStarting.map { batch.index < $0 } ?? true }) {
                    inFlight += 1
                    group.addTask { scan(batch) }
                }
            }
            return best?.seed
        }
    }

    /// How many seeds in ``seeds`` the predicate accepts.
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the number of seeds.
    public func count(where predicate: @Sendable @escaping (UInt64) -> Bool) async -> Int {
        let scan: @Sendable (Batch) -> Int = { batch in
            var count = 0
            for seed in batch.seeds where predicate(seed) {
                count += 1
            }
            return count
        }
        return await withTaskGroup(of: Int.self) { group in
            var batches = self.batches
            var total = 0
            var inFlight = 0
            while inFlight < workers, let batch = batches.next() {
                inFlight += 1
                group.addTask { scan(batch) }
            }
            while let count = await group.next() {
                inFlight -= 1
                total += count
                if let batch = batches.next() {
                    inFlight += 1
                    group.addTask { scan(batch) }
                }
            }
            return total
        }
    }

    var batches: Batches { Batches(seeds: seeds, size: batchSize) }
}

/// One run of consecutive seeds, numbered from the start of the search.
struct Batch: Hashable, Sendable {
    let index: UInt64
    let seeds: Range<UInt64>
}

/// A seed a task matched, with its batch's number, so the lowest batch wins.
struct BatchMatch: Hashable, Sendable {
    let index: UInt64
    let seed: UInt64
}

/// The batches of a search in order, handed out one at a time. Arithmetic stays in UInt64, since a
/// search over the whole seed space has more batches than an Int can count.
struct Batches: Hashable, Sendable {
    let seeds: Range<UInt64>
    let size: UInt64
    private(set) var index: UInt64 = 0
    private(set) var start: UInt64

    init(seeds: Range<UInt64>, size: UInt64) {
        self.seeds = seeds
        self.size = size
        start = seeds.lowerBound
    }

    mutating func next() -> Batch? {
        guard start < seeds.upperBound else { return nil }
        let end = seeds.upperBound - start > size ? start + size : seeds.upperBound
        let batch = Batch(index: index, seeds: start ..< end)
        index += 1
        start = end
        return batch
    }

    /// The next batch when `wanted` accepts it; otherwise nil, and nothing is consumed.
    mutating func next(where wanted: (Batch) -> Bool) -> Batch? {
        var lookahead = self
        guard let batch = lookahead.next(), wanted(batch) else { return nil }
        self = lookahead
        return batch
    }
}
