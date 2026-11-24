/// Draws whose algorithm is fixed here, so a seeded generator reproduces them on every platform
/// and in every Swift release, where the standard library's `random(in:using:)` promises only a
/// correct distribution.
extension RandomNumberGenerator {
    /// A uniform value in [0, 1): one of 2⁵³ equally spaced values, from the top 53 bits of one
    /// draw.
    ///
    /// - Complexity: O(1), one draw.
    @inlinable
    public mutating func uniform() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    /// A uniform value in `range`, including its lower bound and excluding its upper bound.
    ///
    /// Works across bounds of opposite sign whose difference overflows. Rounding at the upper
    /// end is clamped back inside the range.
    ///
    /// - Parameter range: Finite, nonempty bounds. Traps otherwise; use ``uniform(checkedIn:)``
    ///   to throw instead.
    /// - Complexity: O(1), one draw.
    @inlinable
    public mutating func uniform(in range: Range<Double>) -> Double {
        precondition(range.lowerBound.isFinite && range.upperBound.isFinite && !range.isEmpty,
                     "Uniform bounds must be finite and increasing")
        let unit = uniform()
        let value = (1 - unit) * range.lowerBound + unit * range.upperBound
        return max(range.lowerBound, min(value, range.upperBound.nextDown))
    }

    /// A uniform value in `range`, including its lower bound and excluding its upper bound.
    ///
    /// - Throws: ``InvalidInterval`` when a bound is not finite or the range is empty.
    @inlinable
    public mutating func uniform(checkedIn range: Range<Double>) throws(InvalidInterval) -> Double {
        guard range.lowerBound.isFinite, range.upperBound.isFinite, !range.isEmpty else { throw InvalidInterval() }
        return uniform(in: range)
    }

    /// An unbiased integer in `range`, by rejection sampling rather than a biased modulo.
    ///
    /// - Parameter range: A nonempty range, which may cross zero or span nearly the whole `Int`
    ///   domain. Traps when empty; use ``integer(checkedIn:)`` to throw instead.
    /// - Complexity: O(1) expected: one draw, and another with probability below 2⁻⁶⁴ × width.
    @inlinable
    public mutating func integer(in range: Range<Int>) -> Int {
        precondition(!range.isEmpty, "Uniform integer bounds must be increasing")
        let lower = UInt64(bitPattern: Int64(range.lowerBound))
        let width = UInt64(bitPattern: Int64(range.upperBound)) &- lower
        return Int(truncatingIfNeeded: lower &+ offset(below: width))
    }

    /// An unbiased integer in `range`.
    ///
    /// - Throws: ``EmptyRange`` when `range` is empty.
    @inlinable
    public mutating func integer(checkedIn range: Range<Int>) throws(EmptyRange) -> Int {
        guard !range.isEmpty else { throw EmptyRange() }
        return integer(in: range)
    }

    /// An unbiased integer in `range`, which may be the whole `Int` domain.
    ///
    /// - Complexity: O(1) expected: one draw, and another with probability below 2⁻⁶⁴ × width.
    @inlinable
    public mutating func integer(in range: ClosedRange<Int>) -> Int {
        let lower = UInt64(bitPattern: Int64(range.lowerBound))
        let width = UInt64(bitPattern: Int64(range.upperBound)) &- lower &+ 1
        // Only Int.min ... Int.max on a 64-bit Int wraps the width to zero: every value is fair.
        guard width != 0 else { return Int(truncatingIfNeeded: next()) }
        return Int(truncatingIfNeeded: lower &+ offset(below: width))
    }

    /// Whether a trial with the given probability of success succeeds.
    ///
    /// A probability of 0 never succeeds and a probability of 1 always does.
    ///
    /// - Parameter probability: A value in 0 ... 1. Traps otherwise; use ``bernoulli(checked:)``
    ///   to throw instead.
    /// - Complexity: O(1), one draw.
    @inlinable
    public mutating func bernoulli(_ probability: Double) -> Bool {
        precondition(probability >= 0 && probability <= 1, "A probability lies in 0 ... 1")
        return uniform() < probability
    }

    /// Whether a trial with the given probability of success succeeds.
    ///
    /// - Throws: ``InvalidProbability`` when `probability` is outside 0 ... 1 or not a number.
    @inlinable
    public mutating func bernoulli(checked probability: Double) throws(InvalidProbability) -> Bool {
        guard probability >= 0, probability <= 1 else { throw InvalidProbability() }
        return bernoulli(probability)
    }

    /// A uniform value in 0 ..< `width`, for a positive width.
    ///
    /// Draws below 2⁶⁴ mod `width` are rejected, leaving a whole number of copies of 0 ..< width.
    @inlinable
    mutating func offset(below width: UInt64) -> UInt64 {
        var value = next()
        // The threshold is below width, so a draw at or above width is never rejected and never
        // needs it: computing it only then keeps a 64-bit division off the common path.
        if value < width {
            let threshold = (0 &- width) % width
            while value < threshold { value = next() }
        }
        return value % width
    }
}

/// The error ``Swift/RandomNumberGenerator/integer(checkedIn:)`` throws for an empty range.
@frozen
public struct EmptyRange: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}

/// The error ``Swift/RandomNumberGenerator/uniform(checkedIn:)`` throws for bounds that are not
/// finite or not increasing.
@frozen
public struct InvalidInterval: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}

/// The error ``Swift/RandomNumberGenerator/bernoulli(checked:)`` throws for a probability
/// outside 0 ... 1.
@frozen
public struct InvalidProbability: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
