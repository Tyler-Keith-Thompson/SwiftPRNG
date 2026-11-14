import Sampling

/// The log-normal distribution: a value whose natural logarithm is normal with the given mean
/// and standard deviation.
///
/// Sampled as e raised to a ``NormalDistribution`` sample, so from two draws. Its median is
/// e^mean and its own mean e^(mean + standardDeviation² / 2).
@frozen
public struct LogNormalDistribution: Distribution, Hashable {
    /// The mean of the logarithm.
    public let mean: Double
    /// The standard deviation of the logarithm.
    public let standardDeviation: Double

    /// The log-normal distribution whose logarithm has this mean and standard deviation.
    ///
    /// - Parameters:
    ///   - mean: The finite mean of the logarithm.
    ///   - standardDeviation: The finite, nonnegative standard deviation of the logarithm.
    /// - Precondition: Both parameters are finite and the standard deviation is nonnegative;
    ///   use ``init(checkedMean:standardDeviation:)`` to throw instead.
    @inlinable
    public init(mean: Double = 0, standardDeviation: Double = 1) {
        precondition(NormalDistribution.accepts(mean: mean, standardDeviation: standardDeviation),
                     "Log-normal parameters must be finite with a nonnegative standard deviation")
        self.mean = mean
        self.standardDeviation = standardDeviation
    }

    /// The log-normal distribution whose logarithm has this mean and standard deviation.
    ///
    /// - Throws: ``InvalidParameters`` when a parameter is not finite or the standard deviation
    ///   is negative.
    @inlinable
    public init(checkedMean mean: Double, standardDeviation: Double) throws(InvalidParameters) {
        guard NormalDistribution.accepts(mean: mean, standardDeviation: standardDeviation) else { throw InvalidParameters() }
        self.init(mean: mean, standardDeviation: standardDeviation)
    }

    /// One sample, nonnegative; large parameters can overflow it to infinity.
    ///
    /// - Complexity: O(1), two draws.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        Fdlibm.exp(mean + standardDeviation * NormalDistribution.standardSample(using: &generator))
    }
}

extension Distribution where Self == LogNormalDistribution {
    /// The log-normal distribution whose logarithm has this mean and standard deviation; see
    /// ``LogNormalDistribution/init(mean:standardDeviation:)``.
    @inlinable
    public static func logNormal(mean: Double = 0, standardDeviation: Double = 1) -> Self {
        LogNormalDistribution(mean: mean, standardDeviation: standardDeviation)
    }
}
