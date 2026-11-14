/// SplitMix64: a 64-bit counter passed through a mixing function, as in the reference
/// implementation.
///
/// Its period is 2⁶⁴ and its output is a bijection of the counter, so no value repeats within a
/// period. Its job here is seeding: the other generators fill their state from it, and a
/// `SeedTree` derives each node's seed with it. For the draws themselves, prefer
/// ``Xoshiro256StarStar``.
///
/// ```swift
/// var generator = SplitMix64(seed: 42)
/// generator.next()  // 13679457532755275413
/// ```
@frozen
public struct SplitMix64: SeedableRandomNumberGenerator {
    @usableFromInline var counter: UInt64

    /// A generator at the start of the sequence `seed` selects.
    @inlinable
    public init(seed: UInt64) {
        counter = seed
    }

    /// The next value in the sequence.
    ///
    /// - Complexity: O(1).
    @inlinable
    public mutating func next() -> UInt64 {
        counter &+= 0x9E37_79B9_7F4A_7C15
        var mixed = counter
        mixed = (mixed ^ (mixed >> 30)) &* 0xBF58_476D_1CE4_E5B9
        mixed = (mixed ^ (mixed >> 27)) &* 0x94D0_49BB_1331_11EB
        return mixed ^ (mixed >> 31)
    }
}
