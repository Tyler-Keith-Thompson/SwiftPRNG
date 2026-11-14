import Distributions
import Generators
import Sampling

/// A deterministic tree of seeds: every decision in a program draws from a node of its own.
///
/// Each node's seed is derived from its parent's seed and the node's key, so `tree["agent", 7,
/// "delay"]` has the same seed in every run with the same root, whatever else the program does.
/// Adding a draw, an entity or a decision elsewhere never shifts the numbers another node sees,
/// which a single shared generator cannot promise.
///
/// Overriding a node replaces its seed, and every descendant then derives from the override.
/// That makes subtrees independent: a seed that makes one agent behave as a test needs can be
/// searched for on its own (`fitting(_:in:where:)`) and combined with seeds fitted for others.
///
/// A `SeedTree` is a pure value. Sampling a node (``uniform()``, ``integer(in:)``) creates a fresh
/// generator each time and returns the same first draw; ``generator`` hands out a generator to
/// keep drawing from.
///
/// ```swift
/// let tree = SeedTree(42)
/// let delay = tree["agent", 7, "delay"].uniform(in: 1 ..< 5)
/// var generator = tree["agent", 7, "choices"].generator
/// let seeds = (0 ..< 3).map { index in tree["agent", index].seed }
/// ```
@frozen
public struct SeedTree: Hashable, Sendable, CustomStringConvertible {
    /// The keys from the root to this node, shared with the ancestors so a step down costs one link.
    @usableFromInline
    final class Link: Sendable {
        let key: SeedKey
        let parent: Link?
        let depth: Int

        init(_ key: SeedKey, parent: Link?) {
            self.key = key
            self.parent = parent
            depth = (parent?.depth ?? 0) + 1
        }
    }

    /// This node's seed.
    public let seed: UInt64
    /// The seed the tree was made with: the root's, unless the root is overridden.
    public let root: UInt64
    @usableFromInline let overrides: [SeedPath: UInt64]
    @usableFromInline let link: Link?

    /// The keys from the root to this node; empty at the root.
    public var path: SeedPath {
        var keys = [SeedKey]()
        keys.reserveCapacity(link?.depth ?? 0)
        var node = link
        while let current = node {
            keys.append(current.key)
            node = current.parent
        }
        return keys.reversed()
    }

    /// The root of a tree.
    ///
    /// - Parameters:
    ///   - root: The root's seed, from which every node derives.
    ///   - overrides: Seeds for nodes by their path from the root, as ``overriddenSeeds`` reports
    ///     them, so a fitted tree can be saved and rebuilt. The empty path overrides the root.
    public init(_ root: UInt64, overrides: [SeedPath: UInt64] = [:]) {
        self.init(link: nil, seed: overrides[[]] ?? root, root: root, overrides: overrides)
    }

    @usableFromInline
    init(link: Link?, seed: UInt64, root: UInt64, overrides: [SeedPath: UInt64]) {
        self.link = link
        self.seed = seed
        self.root = root
        self.overrides = overrides
    }

    /// Two nodes are equal when they sit at the same path of trees with the same root and
    /// overrides.
    public static func == (lhs: SeedTree, rhs: SeedTree) -> Bool {
        lhs.seed == rhs.seed && lhs.root == rhs.root && lhs.overrides == rhs.overrides && lhs.path == rhs.path
    }

    public func hash(into hasher: inout Hasher) {
        hasher.combine(seed)
        hasher.combine(root)
        hasher.combine(path)
    }

    /// The path from the root, slash-separated, and the seed: `/agent/7 (seed 1271…)`.
    public var description: String {
        "/" + path.map(\.description).joined(separator: "/") + " (seed \(seed))"
    }

    /// The descendant reached by following `keys` from this node: literals, or `Int` and `String`
    /// values, in any mix.
    ///
    /// - Complexity: O(*k*) for *k* keys, plus a dictionary lookup per key in a tree with overrides.
    @inlinable
    public subscript<each Key: SeedKeyConvertible>(_ keys: repeat each Key) -> SeedTree {
        var path = SeedPath()
        for key in repeat each keys {
            path.append(key.seedKey)
        }
        return descendant(path)
    }

    /// The descendant reached by following `keys` from this node.
    ///
    /// - Complexity: O(*k*) for *k* keys, plus a dictionary lookup per key in a tree with overrides.
    public func descendant(_ keys: SeedPath) -> SeedTree {
        var link = self.link
        var seed = self.seed
        // Overrides are keyed by the full path, which is only worth building when there are any.
        var path = overrides.isEmpty ? [] : self.path
        for key in keys {
            link = Link(key, parent: link)
            let derived = Self.derive(seed ^ key.mixingValue)
            if overrides.isEmpty {
                seed = derived
            } else {
                path.append(key)
                seed = overrides[path] ?? derived
            }
        }
        return SeedTree(link: link, seed: seed, root: root, overrides: overrides)
    }

    /// A tree whose node at `path`, measured from the root, uses `seed`, positioned at this
    /// node.
    ///
    /// The node's descendants derive from the new seed exactly as a root with that seed would;
    /// its siblings and ancestors keep theirs.
    public func overriding(_ path: SeedPath, with seed: UInt64) -> SeedTree {
        var overrides = self.overrides
        overrides[path] = seed
        return SeedTree(root, overrides: overrides).descendant(self.path)
    }

    /// A tree with several nodes overridden, positioned at this node.
    public func overriding(_ seeds: [SeedPath: UInt64]) -> SeedTree {
        seeds.reduce(self) { tree, entry in tree.overriding(entry.key, with: entry.value) }
    }

    /// The overrides in force, by path from the root. Pass them to ``init(_:overrides:)`` to
    /// rebuild the tree.
    public var overriddenSeeds: [SeedPath: UInt64] { overrides }

    /// A generator at the start of this node's sequence. Two calls return generators that agree.
    @inlinable
    public var generator: Xoroshiro128Plus { Xoroshiro128Plus(seed: seed) }

    /// A generator of the given kind at the start of this node's sequence.
    @inlinable
    public func generator<Generator: SeedableRandomNumberGenerator>(_ kind: Generator.Type) -> Generator {
        Generator(seed: seed)
    }

    /// This node's first draw as a uniform value in [0, 1).
    @inlinable
    public func uniform() -> Double {
        var generator = generator
        return generator.uniform()
    }

    /// This node's first draw as a uniform value in `range`. Traps on bounds that are not finite
    /// or not increasing, like `RandomNumberGenerator.uniform(in:)`.
    @inlinable
    public func uniform(in range: Range<Double>) -> Double {
        var generator = generator
        return generator.uniform(in: range)
    }

    /// This node's first draw as an unbiased integer in `range`. Traps on an empty range, like
    /// `RandomNumberGenerator.integer(in:)`.
    @inlinable
    public func integer(in range: Range<Int>) -> Int {
        var generator = generator
        return generator.integer(in: range)
    }

    /// Whether a trial of the given probability succeeds on this node's first draw. Traps on a
    /// probability outside 0 ... 1, like `RandomNumberGenerator.bernoulli(_:)`.
    @inlinable
    public func bernoulli(_ probability: Double) -> Bool {
        var generator = generator
        return generator.bernoulli(probability)
    }

    /// A sample of `distribution` drawn from the start of this node's sequence. Two calls return
    /// the same value.
    ///
    /// ```swift
    /// let service = tree["customer", 7, "service"].sample(.exponential(mean: 4))
    /// ```
    @inlinable
    public func sample<Value>(_ distribution: some Distribution<Value>) -> Value {
        var generator = generator
        return distribution.sample(using: &generator)
    }

    /// One SplitMix64 step from `value`: the derivation of a child's seed from its parent's seed
    /// and key, and of a key's mixing value.
    @usableFromInline
    static func derive(_ value: UInt64) -> UInt64 {
        var generator = SplitMix64(seed: value)
        return generator.next()
    }
}
