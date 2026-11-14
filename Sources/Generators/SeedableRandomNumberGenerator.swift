/// A random number generator whose whole sequence follows from a 64-bit seed.
///
/// Two generators made from the same seed produce the same values on every platform and in every
/// release, so a randomized result reproduces from its seed alone. The state is a value: copying a
/// generator copies its position in the sequence, and `Codable` saves and restores it.
public protocol SeedableRandomNumberGenerator: RandomNumberGenerator, Hashable, Sendable, Codable {
    /// A generator at the start of the sequence `seed` selects.
    init(seed: UInt64)
}
