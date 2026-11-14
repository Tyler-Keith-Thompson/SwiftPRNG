import Sampling

/// The Poisson distribution with a mean: the number of events in an interval when they arrive
/// independently at a constant rate, mean per interval.
///
/// Below a mean of 10 it is sampled by Knuth's multiplication method: uniform draws are
/// multiplied until the product falls to e^−mean or below, and the count is the draws taken
/// before that. From a mean of 10 it is sampled by Hörmann's transformed rejection with squeeze,
/// PTRS ("The transformed rejection method for generating Poisson random variables",
/// *Insurance: Mathematics and Economics* 12(1), 1993), two draws per attempt.
@frozen
public struct PoissonDistribution: Distribution, Hashable {
    /// The largest mean, 2³⁰, which keeps every sample within a 32-bit `Int`, so a seed gives
    /// the same counts on every platform.
    public static let maximumMean: Double = 1_073_741_824

    /// The mean, which is also the variance.
    public let mean: Double

    /// e^−mean for Knuth's method; the PTRS constants b, a, 1/α, v_r and ln(mean) otherwise.
    @usableFromInline let limit: Double
    @usableFromInline let b: Double
    @usableFromInline let a: Double
    @usableFromInline let inverseAlpha: Double
    @usableFromInline let acceptanceBound: Double
    @usableFromInline let logMean: Double

    /// The Poisson distribution with this mean.
    ///
    /// A mean of zero gives zero every time, drawing nothing.
    ///
    /// - Parameter mean: A mean in 0 ... ``maximumMean``.
    /// - Precondition: `mean` lies in 0 ... ``maximumMean``; use ``init(checkedMean:)`` to throw
    ///   instead.
    @inlinable
    public init(mean: Double) {
        precondition(mean >= 0 && mean <= Self.maximumMean, "A Poisson mean must lie in 0 ... 2³⁰")
        self.mean = mean
        limit = Fdlibm.exp(-mean)
        let root = mean.squareRoot()
        b = 0.931 + 2.53 * root
        a = -0.059 + 0.02483 * b
        inverseAlpha = 1.1239 + 1.1328 / (b - 3.4)
        acceptanceBound = 0.9277 - 3.6224 / (b - 2)
        logMean = Fdlibm.log(mean)
    }

    /// The Poisson distribution with this mean.
    ///
    /// - Throws: ``InvalidParameters`` when `mean` lies outside 0 ... ``maximumMean`` or is not a
    ///   number.
    @inlinable
    public init(checkedMean mean: Double) throws(InvalidParameters) {
        guard mean >= 0, mean <= Self.maximumMean else { throw InvalidParameters() }
        self.init(mean: mean)
    }

    /// One sample, a count of zero or more.
    ///
    /// - Complexity: O(mean) expected below a mean of 10, taking mean + 1 draws on average; O(1)
    ///   expected from 10, two draws per attempt and fewer than 1.33 attempts on average, falling
    ///   toward 1.12 as the mean grows.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Int {
        guard mean > 0 else { return 0 }
        guard mean >= 10 else { return multiplicationSample(using: &generator) }
        return transformedRejectionSample(using: &generator)
    }

    @inlinable
    func multiplicationSample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Int {
        var count = 0
        var product = generator.uniform()
        while product > limit {
            count += 1
            product *= generator.uniform()
        }
        return count
    }

    @inlinable
    func transformedRejectionSample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Int {
        while true {
            let u = generator.uniform() - 0.5
            let v = generator.uniform()
            let us = 0.5 - abs(u)
            let k = ((2 * a / us + b) * u + mean + 0.43).rounded(.down)
            if us >= 0.07, v <= acceptanceBound { return Int(k) }
            // k stays a Double until accepted: near |u| = ½ it can be ±∞, and the test below
            // rejects every k above 2³¹ long before it could be taken.
            guard k >= 0, k < 0x1p31, us >= 0.013 || v <= us else { continue }
            let left = Fdlibm.log(v) + Fdlibm.log(inverseAlpha) - Fdlibm.log(a / (us * us) + b)
            if left <= -mean + k * logMean - Self.logGamma(k + 1) { return Int(k) }
        }
    }

    /// ln Γ(`x`) for a whole number `x` ≥ 1, by Stirling's series from 7 up (recurrence below).
    @usableFromInline
    package static func logGamma(_ x: Double) -> Double {
        if x == 1 || x == 2 { return 0 }
        let shift = x < 7 ? (7 - x).rounded(.towardZero) : 0
        var shifted = x + shift
        let inverseSquare = (1 / shifted) * (1 / shifted)
        var series = -1.39243221690590e+00
        for coefficient in stirlingCoefficients {
            series = series * inverseSquare + coefficient
        }
        // The series' leading terms, with ln(2π) / 2.
        var result = series / shifted + 0.5 * 1.8378770664093453 + (shifted - 0.5) * Fdlibm.log(shifted) - shifted
        var remaining = shift
        while remaining > 0 {
            result -= Fdlibm.log(shifted - 1)
            shifted -= 1
            remaining -= 1
        }
        return result
    }

    /// Stirling's coefficients B₂ₙ / (2n(2n − 1)) for n = 9 down to 1; n = 10 starts the series.
    @usableFromInline
    static let stirlingCoefficients: [Double] = [
        1.796443723688307e-01, -2.955065359477124e-02, 6.410256410256410e-03,
        -1.917526917526918e-03, 8.417508417508418e-04, -5.952380952380952e-04,
        7.936507936507937e-04, -2.777777777777778e-03, 8.333333333333333e-02,
    ]
}

extension Distribution where Self == PoissonDistribution {
    /// The Poisson distribution with this mean; see ``PoissonDistribution/init(mean:)``.
    @inlinable
    public static func poisson(mean: Double) -> Self {
        PoissonDistribution(mean: mean)
    }
}
