/// xoroshiro128+ in its 2016 form (rotations 55, 14 and 36), seeded through ``SplitMix64``.
///
/// Fast, with a period of 2¹²⁸ − 1. The lowest bits of its output are weaker than the rest, which
/// a `Double` drawn from the top 53 bits never sees; code that uses the low bits of raw values
/// should prefer ``Xoshiro256StarStar``. This is the generator a `SeedTree` node hands out.
///
/// ``jump()`` advances the sequence by 2⁶⁴ steps, so one seed yields up to 2⁶⁴ sequences that
/// never overlap: one per thread, or one per entity in a simulation.
///
/// ```swift
/// var generator = Xoroshiro128Plus(seed: 42)
/// var streams: [Xoroshiro128Plus] = []
/// for _ in 0 ..< 4 {
///     streams.append(generator)
///     generator.jump()
/// }
/// ```
@frozen
public struct Xoroshiro128Plus: SeedableRandomNumberGenerator {
    @usableFromInline var state0: UInt64
    @usableFromInline var state1: UInt64

    /// A generator at the start of the sequence `seed` selects.
    ///
    /// Both state words are filled from ``SplitMix64``, so a seed of zero, or seeds that differ in
    /// one bit, start sequences as far apart as any others.
    @inlinable
    public init(seed: UInt64) {
        var seeder = SplitMix64(seed: seed)
        state0 = seeder.next()
        state1 = seeder.next()
    }

    /// The next value in the sequence.
    ///
    /// - Complexity: O(1).
    @inlinable
    public mutating func next() -> UInt64 {
        let result = state0 &+ state1
        let mixed = state1 ^ state0
        state1 = (mixed << 36) | (mixed >> 28)
        state0 = ((state0 << 55) | (state0 >> 9)) ^ mixed ^ (mixed << 14)
        return result
    }

    /// Advances the sequence by 2⁶⁴ steps.
    ///
    /// - Complexity: O(1): 128 steps, whatever the distance.
    public mutating func jump() {
        advance(by: (0xBEAC_0467_EBA5_FACB, 0xD86B_048B_86AA_9922))
    }

    /// The generator 2⁶⁴ steps further on.
    public func jumped() -> Xoroshiro128Plus {
        var copy = self
        copy.jump()
        return copy
    }

    /// Advances the sequence by 2⁹⁶ steps, so each long jump leaves room for 2³² jumps.
    ///
    /// - Complexity: O(1): 128 steps, whatever the distance.
    public mutating func longJump() {
        advance(by: (0x18F7_C399_CCEB_DA8D, 0xF2DE_AC28_BEF3_BB07))
    }

    /// The generator 2⁹⁶ steps further on.
    public func longJumped() -> Xoroshiro128Plus {
        var copy = self
        copy.longJump()
        return copy
    }

    // The state transition is linear over GF(2), so advancing by 2ᵏ steps is a polynomial in the
    // transition applied to the state: the state is stepped once per bit, and the states at the
    // polynomial's set bits are added (xored) up. The polynomials are the reference ones; the 2016
    // form's long jump was derived the same way the reference derives its own.
    @usableFromInline
    mutating func advance(by polynomial: (UInt64, UInt64)) {
        var jumped0: UInt64 = 0
        var jumped1: UInt64 = 0
        for word in [polynomial.0, polynomial.1] {
            for bit in 0 ..< 64 {
                if word & (1 << bit) != 0 {
                    jumped0 ^= state0
                    jumped1 ^= state1
                }
                _ = next()
            }
        }
        state0 = jumped0
        state1 = jumped1
    }

    enum CodingKeys: String, CodingKey {
        case state
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let words = try container.decode([UInt64].self, forKey: .state)
        guard words.count == 2 else {
            throw DecodingError.dataCorruptedError(forKey: .state, in: container, debugDescription: "Xoroshiro128Plus holds 2 state words")
        }
        guard words.contains(where: { $0 != 0 }) else {
            throw DecodingError.dataCorruptedError(forKey: .state, in: container, debugDescription: "An all-zero state only ever yields zero")
        }
        state0 = words[0]
        state1 = words[1]
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([state0, state1], forKey: .state)
    }
}
