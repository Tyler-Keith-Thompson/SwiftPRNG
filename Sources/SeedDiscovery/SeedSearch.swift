/// A range of candidate seeds, searched in order for the first that does what a predicate asks.
///
/// Searching is how a seed is chosen on purpose: the seed under which a flaky test fails, the
/// seed whose first draw lands in a rare branch, the seed that makes a demo's data look right.
/// The answer is always the smallest matching seed, so a search reproduces, and a seed found once
/// can be written down. ``concurrent(workers:batchSize:)`` spreads the same search over cores
/// and finds the same seed.
///
/// ```swift
/// let seed = SeedSearch(0 ..< 1_000_000).first { seed in
///     var generator = Xoshiro256StarStar(seed: seed)
///     return generator.uniform() > 0.9999
/// }
/// ```
@frozen
public struct SeedSearch: Hashable, Sendable {
    /// The candidates, tried from the lowest up.
    public var seeds: Range<UInt64>

    /// A search over `seeds`.
    @inlinable
    public init(_ seeds: Range<UInt64>) {
        self.seeds = seeds
    }

    /// The smallest seed in ``seeds`` the predicate accepts, or `nil` when it accepts none.
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the position of the match.
    @inlinable
    public func first<Failure: Error>(where predicate: (UInt64) throws(Failure) -> Bool) throws(Failure) -> UInt64? {
        for seed in seeds where try predicate(seed) {
            return seed
        }
        return nil
    }

    /// How many seeds in ``seeds`` the predicate accepts: the rarity of what a search asks for,
    /// which says how wide a range the search needs.
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the number of seeds.
    @inlinable
    public func count<Failure: Error>(where predicate: (UInt64) throws(Failure) -> Bool) throws(Failure) -> Int {
        var count = 0
        for seed in seeds where try predicate(seed) {
            count += 1
        }
        return count
    }

    /// The same search spread over several tasks, with the same answers.
    ///
    /// - Parameters:
    ///   - workers: How many batches of seeds are tried at once. Defaults to the number of
    ///     processors. Traps when below 1.
    ///   - batchSize: How many consecutive seeds each task tries before reporting. Traps when
    ///     below 1.
    @inlinable
    public func concurrent(workers: Int = ConcurrentSeedSearch.defaultWorkers, batchSize: UInt64 = 1024) -> ConcurrentSeedSearch {
        ConcurrentSeedSearch(seeds, workers: workers, batchSize: batchSize)
    }
}
