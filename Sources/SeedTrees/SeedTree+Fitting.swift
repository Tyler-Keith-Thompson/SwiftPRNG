import SeedDiscovery

extension SeedTree {
    /// The tree with the node at `path`, measured from the root, overridden by the smallest seed
    /// in `search` under which the predicate accepts the tree, or `nil` when no seed does.
    ///
    /// The predicate sees the candidate tree positioned at this node, so it indexes from here.
    /// Because an override reseeds only its subtree, a fit for one node leaves every other node's
    /// draws as they were, and fits for several nodes compose: fit each in turn.
    ///
    /// ```swift
    /// let fitted = SeedTree(42).fitting(["agent", 7], in: SeedSearch(0 ..< 10_000)) { tree in
    ///     tree["agent", 7, "delay"].uniform() < 0.01
    /// }
    /// ```
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the position of the match.
    public func fitting<Failure: Error>(
        _ path: SeedPath, in search: SeedSearch, where predicate: (SeedTree) throws(Failure) -> Bool
    ) throws(Failure) -> SeedTree? {
        let seed = try search.first { (seed) throws(Failure) in try predicate(overriding(path, with: seed)) }
        return seed.map { overriding(path, with: $0) }
    }

    /// The tree with the node at `path`, measured from the root, overridden by the smallest seed
    /// in `search` under which the predicate accepts the tree, or `nil` when no seed does; the
    /// seeds are tried across tasks and the answer is the one the sequential search gives.
    ///
    /// - Complexity: O(*n*) calls of the predicate, where *n* is the position of the match
    ///   rounded up to the batches in flight.
    public func fitting(
        _ path: SeedPath, in search: ConcurrentSeedSearch, where predicate: @Sendable @escaping (SeedTree) -> Bool
    ) async -> SeedTree? {
        let seed = await search.first { seed in predicate(overriding(path, with: seed)) }
        return seed.map { overriding(path, with: $0) }
    }
}
