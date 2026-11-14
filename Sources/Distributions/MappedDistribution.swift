/// A distribution's samples, each transformed: what ``Distribution/map(_:)`` returns.
@frozen
public struct MappedDistribution<Base: Distribution, Value: Sendable>: Distribution {
    /// The distribution whose samples are transformed.
    public let base: Base

    @usableFromInline
    let transform: @Sendable (Base.Value) -> Value

    @inlinable
    init(base: Base, transform: @escaping @Sendable (Base.Value) -> Value) {
        self.base = base
        self.transform = transform
    }

    /// The transform of one sample of ``base``.
    ///
    /// - Complexity: The draws ``base`` consumes.
    @inlinable
    public func sample<Generator: RandomNumberGenerator>(using generator: inout Generator) -> Value {
        transform(base.sample(using: &generator))
    }
}
