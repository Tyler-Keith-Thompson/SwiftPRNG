/// A distribution that always returns the same value.
@frozen
public struct ConstantDistribution<Value: Sendable>: Distribution {
    /// The value every sample returns.
    public let value: Value

    /// The distribution of `value` alone.
    @inlinable
    public init(_ value: Value) {
        self.value = value
    }

    /// ``value``.
    ///
    /// - Complexity: O(1), no draws.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Value {
        value
    }
}

extension ConstantDistribution: Equatable where Value: Equatable {}
extension ConstantDistribution: Hashable where Value: Hashable {}

extension Distribution {
    /// The distribution that always returns `value`, drawing nothing.
    @inlinable
    public static func constant<Constant>(_ value: Constant) -> Self where Self == ConstantDistribution<Constant> {
        ConstantDistribution(value)
    }
}
