import Sampling

/// The gamma distribution with a shape and a scale: for a whole-number shape k, the waiting time
/// until the k-th event of a process whose events arrive at a rate of 1 / scale.
///
/// Sampled by Marsaglia and Tsang's method ("A Simple Method for Generating Gamma Variables",
/// *ACM Transactions on Mathematical Software* 26(3), 2000). With d = shape − ⅓ and
/// c = 1 / √(9d), each attempt draws a standard normal x (two draws, as ``NormalDistribution``
/// does) and, when v = (1 + cx)³ is positive, a uniform u (one draw), and accepts d·v when
/// u < 1 − 0.0331x⁴ or ln u < x²/2 + d(1 − v + ln v). Below a shape of 1 it samples shape + 1 that
/// way and multiplies by u^(1 / shape) for one more uniform draw u.
@frozen
public struct GammaDistribution: Distribution, Hashable {
    /// The shape, k.
    public let shape: Double
    /// The scale, θ; the mean is shape × scale.
    public let scale: Double

    @usableFromInline
    let d: Double

    @usableFromInline
    let c: Double

    /// The gamma distribution with this shape and scale.
    ///
    /// - Parameters:
    ///   - shape: A finite, positive shape.
    ///   - scale: A finite, positive scale. Samples of large parameters may overflow to infinity.
    /// - Precondition: Both parameters are finite and positive; use
    ///   ``init(checkedShape:scale:)`` to throw instead.
    @inlinable
    public init(shape: Double, scale: Double = 1) {
        precondition(Self.accepts(shape: shape, scale: scale), "Gamma parameters must be finite and positive")
        self.shape = shape
        self.scale = scale
        d = (shape < 1 ? shape + 1 : shape) - 1.0 / 3.0
        c = 1 / (9 * d).squareRoot()
    }

    /// The gamma distribution with this shape and scale.
    ///
    /// - Throws: ``InvalidParameters`` when a parameter is not finite and positive.
    @inlinable
    public init(checkedShape shape: Double, scale: Double = 1) throws(InvalidParameters) {
        guard Self.accepts(shape: shape, scale: scale) else { throw InvalidParameters() }
        self.init(shape: shape, scale: scale)
    }

    /// One sample, nonnegative.
    ///
    /// - Complexity: O(1) expected. Each attempt takes two draws, or three when it reaches the
    ///   acceptance test, and at least 95% of attempts are accepted; a shape below 1 takes one
    ///   draw more.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        let unscaled = d * acceptedCube(using: &generator)
        guard shape < 1 else { return unscaled * scale }
        // The boost, in [0, 1], before the scale: a sample that overflows to infinity times a
        // boost that underflows to zero would be NaN.
        return unscaled * Fdlibm.exp(Fdlibm.log(generator.uniform()) / shape) * scale
    }

    /// The v of the first attempt Marsaglia and Tsang's test accepts.
    @inlinable
    func acceptedCube<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        while true {
            let x = NormalDistribution.standardSample(using: &generator)
            let root = 1 + c * x
            guard root > 0 else { continue }
            let v = root * root * root
            let u = generator.uniform()
            let squared = x * x
            if u < 1 - 0.0331 * squared * squared { return v }
            if Fdlibm.log(u) < 0.5 * squared + d * (1 - v + Fdlibm.log(v)) { return v }
        }
    }

    @inlinable
    static func accepts(shape: Double, scale: Double) -> Bool {
        shape.isFinite && shape > 0 && scale.isFinite && scale > 0
    }
}

extension Distribution where Self == GammaDistribution {
    /// The gamma distribution with this shape and scale; see
    /// ``GammaDistribution/init(shape:scale:)``.
    @inlinable
    public static func gamma(shape: Double, scale: Double = 1) -> Self {
        GammaDistribution(shape: shape, scale: scale)
    }
}
