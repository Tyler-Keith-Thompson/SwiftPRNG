import Sampling

/// The exponential distribution with a mean: the waiting time between events that arrive at a
/// constant rate of 1 / mean.
///
/// Sampled by inverting its distribution function: one uniform draw u gives −mean × ln(1 − u),
/// which is zero when u is.
@frozen
public struct ExponentialDistribution: Distribution, Hashable {
    /// The mean waiting time.
    public let mean: Double

    /// The exponential distribution with this mean.
    ///
    /// - Parameter mean: A finite, positive mean. Samples of a mean near the largest `Double`
    ///   may overflow to infinity.
    /// - Precondition: `mean` is finite and positive; use ``init(checkedMean:)`` to throw instead.
    @inlinable
    public init(mean: Double) {
        precondition(mean.isFinite && mean > 0, "An exponential mean must be finite and positive")
        self.mean = mean
    }

    /// The exponential distribution with this mean.
    ///
    /// - Throws: ``InvalidParameters`` when `mean` is not finite and positive.
    @inlinable
    public init(checkedMean mean: Double) throws(InvalidParameters) {
        guard mean.isFinite, mean > 0 else { throw InvalidParameters() }
        self.init(mean: mean)
    }

    /// One sample, nonnegative.
    ///
    /// - Complexity: O(1), one draw.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        -Fdlibm.log1p(-generator.uniform()) * mean
    }
}

extension Distribution where Self == ExponentialDistribution {
    /// The exponential distribution with this mean; see ``ExponentialDistribution/init(mean:)``.
    @inlinable
    public static func exponential(mean: Double) -> Self {
        ExponentialDistribution(mean: mean)
    }
}
