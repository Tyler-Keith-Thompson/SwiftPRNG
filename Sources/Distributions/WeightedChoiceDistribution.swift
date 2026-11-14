import Sampling

/// A choice among values, each in proportion to its weight.
///
/// Sampled from one uniform draw u: the weights are divided by the largest, and the choice is the
/// first value whose running total of weights exceeds u times their sum, found by binary search.
@frozen
public struct WeightedChoiceDistribution<Value: Sendable>: Distribution {
    /// The values with a positive weight, in the order given.
    public let values: [Value]

    /// The running totals of the values' weights, each divided by the largest weight.
    @usableFromInline
    let cumulativeWeights: [Double]

    /// A choice among `choices`, each in proportion to its weight.
    ///
    /// A zero weight is never chosen. Dividing by the largest weight first keeps the sum finite
    /// for weights up to the largest `Double`; a weight below the sum's precision may never be
    /// chosen.
    ///
    /// - Parameter choices: A value and a finite, nonnegative weight for each; at least one
    ///   weight is positive.
    /// - Precondition: `choices` has a positive weight and no negative or nonfinite weight; use
    ///   ``init(checked:)`` to throw instead.
    @inlinable
    public init(_ choices: [(value: Value, weight: Double)]) {
        precondition(Self.accepts(choices), "Choice weights must be finite and nonnegative, and one must be positive")
        // The precondition makes the maximum exist and be positive.
        let largest = choices.lazy.map(\.weight).max()!
        var values: [Value] = []
        var cumulativeWeights: [Double] = []
        var total = 0.0
        for choice in choices where choice.weight > 0 {
            total += choice.weight / largest
            values.append(choice.value)
            cumulativeWeights.append(total)
        }
        self.values = values
        self.cumulativeWeights = cumulativeWeights
    }

    /// A choice among `choices`, each in proportion to its weight.
    ///
    /// - Throws: ``InvalidParameters`` when `choices` has no positive weight or a negative or
    ///   nonfinite one.
    @inlinable
    public init(checked choices: [(value: Value, weight: Double)]) throws(InvalidParameters) {
        guard Self.accepts(choices) else { throw InvalidParameters() }
        self.init(choices)
    }

    /// One of ``values``.
    ///
    /// - Complexity: O(log *n*) for *n* values with a positive weight, one draw.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Value {
        let threshold = generator.uniform() * cumulativeWeights[cumulativeWeights.count - 1]
        var low = 0
        var high = cumulativeWeights.count - 1
        // The first total above the threshold; the last value when rounding leaves none above it.
        while low < high {
            let middle = low + (high - low) / 2
            if cumulativeWeights[middle] > threshold { high = middle } else { low = middle + 1 }
        }
        return values[low]
    }

    @inlinable
    static func accepts(_ choices: [(value: Value, weight: Double)]) -> Bool {
        choices.allSatisfy { $0.weight.isFinite && $0.weight >= 0 } && choices.contains { $0.weight > 0 }
    }
}

extension Distribution {
    /// A choice among `choices`, each in proportion to its weight; see
    /// ``WeightedChoiceDistribution/init(_:)``.
    @inlinable
    public static func weightedChoice<Choice>(
        _ choices: [(value: Choice, weight: Double)]
    ) -> Self where Self == WeightedChoiceDistribution<Choice> {
        WeightedChoiceDistribution(choices)
    }
}
