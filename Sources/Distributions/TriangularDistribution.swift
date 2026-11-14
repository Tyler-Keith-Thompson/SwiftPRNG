import Sampling

/// The triangular distribution on an interval, whose density rises linearly from the lower bound
/// to the mode and falls linearly to the upper bound.
///
/// Sampled by inverting its distribution function from one uniform draw u: with
/// F = (mode − lowerBound) / (upperBound − lowerBound), the position is √(uF) when u < F and
/// 1 − √((1 − u)(1 − F)) otherwise, mapped onto the bounds and clamped inside them.
@frozen
public struct TriangularDistribution: Distribution, Hashable {
    /// The smallest value.
    public let lowerBound: Double
    /// The most likely value.
    public let mode: Double
    /// The largest value.
    public let upperBound: Double

    /// Where the mode lies between the bounds, from 0 at the lower bound to 1 at the upper.
    @usableFromInline
    let modeFraction: Double

    /// The triangular distribution on these bounds with this mode.
    ///
    /// Bounds whose difference overflows a `Double`, such as −1e308 and 1e308, still work.
    ///
    /// - Parameters:
    ///   - lowerBound: The finite smallest value.
    ///   - mode: The finite most likely value, which may equal either bound.
    ///   - upperBound: The finite largest value, above `lowerBound`.
    /// - Precondition: The parameters are finite and lowerBound ≤ mode ≤ upperBound with
    ///   lowerBound < upperBound; use ``init(checkedLowerBound:mode:upperBound:)`` to throw instead.
    @inlinable
    public init(lowerBound: Double, mode: Double, upperBound: Double) {
        precondition(Self.accepts(lowerBound: lowerBound, mode: mode, upperBound: upperBound),
                     "Triangular bounds must be finite and increasing and contain the mode")
        self.lowerBound = lowerBound
        self.mode = mode
        self.upperBound = upperBound
        let width = upperBound - lowerBound
        if width.isFinite {
            modeFraction = (mode - lowerBound) / width
        } else {
            // Scaled into [−1, 1] first, where the difference of the bounds cannot overflow.
            let scale = max(abs(lowerBound), abs(upperBound))
            modeFraction = (mode / scale - lowerBound / scale) / (upperBound / scale - lowerBound / scale)
        }
    }

    /// The triangular distribution on these bounds with this mode.
    ///
    /// - Throws: ``InvalidParameters`` when a parameter is not finite, the bounds are not
    ///   increasing, or the mode lies outside them.
    @inlinable
    public init(checkedLowerBound lowerBound: Double, mode: Double, upperBound: Double) throws(InvalidParameters) {
        guard Self.accepts(lowerBound: lowerBound, mode: mode, upperBound: upperBound) else { throw InvalidParameters() }
        self.init(lowerBound: lowerBound, mode: mode, upperBound: upperBound)
    }

    /// One sample, in lowerBound ... upperBound.
    ///
    /// - Complexity: O(1), one draw.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Double {
        let unit = generator.uniform()
        let position = unit < modeFraction
            ? (unit * modeFraction).squareRoot()
            : 1 - ((1 - unit) * (1 - modeFraction)).squareRoot()
        let value = (1 - position) * lowerBound + position * upperBound
        return max(lowerBound, min(value, upperBound))
    }

    @inlinable
    static func accepts(lowerBound: Double, mode: Double, upperBound: Double) -> Bool {
        lowerBound.isFinite && mode.isFinite && upperBound.isFinite
            && lowerBound < upperBound && lowerBound <= mode && mode <= upperBound
    }
}

extension Distribution where Self == TriangularDistribution {
    /// The triangular distribution on these bounds with this mode; see
    /// ``TriangularDistribution/init(lowerBound:mode:upperBound:)``.
    @inlinable
    public static func triangular(lowerBound: Double, mode: Double, upperBound: Double) -> Self {
        TriangularDistribution(lowerBound: lowerBound, mode: mode, upperBound: upperBound)
    }
}
