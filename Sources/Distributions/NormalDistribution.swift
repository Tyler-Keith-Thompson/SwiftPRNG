import Sampling

/// The normal (Gaussian) distribution with a mean and a standard deviation.
///
/// Sampled by the Box–Muller transform, without caching its second value: two uniform draws u₁
/// and u₂ give mean + standardDeviation × √(−2 ln(1 − u₁)) × cos(2πu₂).
@frozen
public struct NormalDistribution: Distribution, Hashable {
    /// The mean, which is also the median.
    public let mean: Double
    /// The standard deviation.
    public let standardDeviation: Double

    /// The normal distribution with this mean and standard deviation.
    ///
    /// A standard deviation of zero gives the mean every time, still consuming two draws.
    ///
    /// - Parameters:
    ///   - mean: A finite mean.
    ///   - standardDeviation: A finite, nonnegative standard deviation.
    /// - Precondition: Both parameters are finite and the standard deviation is nonnegative;
    ///   use ``init(checkedMean:standardDeviation:)`` to throw instead.
    @inlinable
    public init(mean: Double = 0, standardDeviation: Double = 1) {
        precondition(Self.accepts(mean: mean, standardDeviation: standardDeviation),
                     "Normal parameters must be finite with a nonnegative standard deviation")
        self.mean = mean
        self.standardDeviation = standardDeviation
    }

    /// The normal distribution with this mean and standard deviation.
    ///
    /// - Throws: ``InvalidParameters`` when a parameter is not finite or the standard deviation
    ///   is negative.
    @inlinable
    public init(checkedMean mean: Double, standardDeviation: Double) throws(InvalidParameters) {
        guard Self.accepts(mean: mean, standardDeviation: standardDeviation) else { throw InvalidParameters() }
        self.init(mean: mean, standardDeviation: standardDeviation)
    }

    /// One sample.
    ///
    /// - Complexity: O(1), two draws.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        mean + standardDeviation * Self.standardSample(using: &generator)
    }

    /// A sample of the standard normal distribution, by Box–Muller from two draws.
    @inlinable
    static func standardSample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        let radius = (-2 * Fdlibm.log1p(-generator.uniform())).squareRoot()
        return radius * Fdlibm.cosPi(2 * generator.uniform())
    }

    @inlinable
    static func accepts(mean: Double, standardDeviation: Double) -> Bool {
        mean.isFinite && standardDeviation.isFinite && standardDeviation >= 0
    }
}

extension Distribution where Self == NormalDistribution {
    /// The normal distribution with this mean and standard deviation; see
    /// ``NormalDistribution/init(mean:standardDeviation:)``.
    @inlinable
    public static func normal(mean: Double = 0, standardDeviation: Double = 1) -> Self {
        NormalDistribution(mean: mean, standardDeviation: standardDeviation)
    }
}
