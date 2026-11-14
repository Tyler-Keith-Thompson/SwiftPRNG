/// The error a distribution's `checked` initializer throws for parameters outside its domain.
@frozen
public struct InvalidParameters: Error, Hashable, Sendable {
    @inlinable
    public init() {}
}
