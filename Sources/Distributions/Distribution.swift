/// A rule for turning draws from a random number generator into values.
///
/// A distribution holds parameters and no random state, so one value can be shared, stored and
/// sampled from many generators. Every conformer in this module fixes its algorithm and the number
/// of draws it consumes, and computes its logarithms, exponentials and cosines with a port of
/// fdlibm rather than the platform's math library, so a seeded generator gives the same samples on
/// every platform and in every release.
///
/// ```swift
/// var generator = Xoshiro256StarStar(seed: 42)
/// let delay = ExponentialDistribution(mean: 3).sample(using: &generator)
/// let height = NormalDistribution(mean: 170, standardDeviation: 8).sample(using: &generator)
/// ```
///
/// Conform a type of your own by implementing ``sample(using:)`` in terms of the generator's
/// draws and the samplers here; ``map(_:)`` derives one from another.
public protocol Distribution<Value>: Sendable {
    /// The type of a sample.
    associatedtype Value: Sendable

    /// One sample, drawn from `generator`.
    func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Value
}

extension Distribution {
    /// A distribution of `transform` applied to each of this distribution's samples, drawing what
    /// this one draws and nothing more.
    ///
    /// - Parameter transform: A pure function of the sample.
    @inlinable
    public func map<Mapped: Sendable>(
        _ transform: @escaping @Sendable (Value) -> Mapped
    ) -> MappedDistribution<Self, Mapped> {
        MappedDistribution(base: self, transform: transform)
    }
}
