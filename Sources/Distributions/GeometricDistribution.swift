import Sampling

/// The geometric distribution with a probability of success: the number of failures before the
/// first success in independent trials.
///
/// Sampled by inverting its distribution function: one uniform draw u gives
/// ⌊ln(1 − u) / ln(1 − probability)⌋.
@frozen
public struct GeometricDistribution: Distribution, Hashable {
    /// The probability that each trial succeeds.
    public let probability: Double

    /// ln(1 − probability).
    @usableFromInline
    let logFailure: Double

    /// The geometric distribution with this probability of success.
    ///
    /// A probability of 1 gives zero every time, still consuming a draw.
    ///
    /// - Parameter probability: A probability in the half-open interval (0, 1].
    /// - Precondition: `probability` lies in (0, 1]; use ``init(checkedProbability:)`` to throw
    ///   instead.
    @inlinable
    public init(probability: Double) {
        precondition(probability > 0 && probability <= 1, "A geometric probability must lie in (0, 1]")
        self.probability = probability
        logFailure = Fdlibm.log1p(-probability)
    }

    /// The geometric distribution with this probability of success.
    ///
    /// - Throws: ``InvalidParameters`` when `probability` lies outside (0, 1] or is not a number.
    @inlinable
    public init(checkedProbability probability: Double) throws(InvalidParameters) {
        guard probability > 0, probability <= 1 else { throw InvalidParameters() }
        self.init(probability: probability)
    }

    /// One sample, a count of zero or more. A count beyond `Int.max`, which only a tiny
    /// probability makes possible, is `Int.max`.
    ///
    /// - Complexity: O(1), one draw.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Int {
        let failures = (Fdlibm.log1p(-generator.uniform()) / logFailure).rounded(.down)
        return failures < Double(Int.max) ? Int(failures) : .max
    }
}

extension Distribution where Self == GeometricDistribution {
    /// The geometric distribution with this probability of success; see
    /// ``GeometricDistribution/init(probability:)``.
    @inlinable
    public static func geometric(probability: Double) -> Self {
        GeometricDistribution(probability: probability)
    }
}
