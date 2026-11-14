/// xoshiro256**, the reference's general-purpose generator, seeded through ``SplitMix64``.
///
/// Every bit of its output passes the usual statistical tests, and its period is 2²⁵⁶ − 1. Choose
/// it for raw integers, shuffles and anything that uses the low bits; ``Xoroshiro128Plus`` is a
/// little faster where only `Double`s are drawn.
///
/// ``jump()`` advances the sequence by 2¹²⁸ steps, so one seed yields up to 2¹²⁸ sequences that
/// never overlap.
///
/// ```swift
/// var generator = Xoshiro256StarStar(seed: 42)
/// [1, 2, 3].shuffled(using: &generator)
/// ```
@frozen
public struct Xoshiro256StarStar: SeedableRandomNumberGenerator {
    @usableFromInline var state0: UInt64
    @usableFromInline var state1: UInt64
    @usableFromInline var state2: UInt64
    @usableFromInline var state3: UInt64

    /// A generator at the start of the sequence `seed` selects.
    ///
    /// The four state words are filled from ``SplitMix64``, so a seed of zero, or seeds that
    /// differ in one bit, start sequences as far apart as any others.
    @inlinable
    public init(seed: UInt64) {
        var seeder = SplitMix64(seed: seed)
        state0 = seeder.next()
        state1 = seeder.next()
        state2 = seeder.next()
        state3 = seeder.next()
    }

    /// The next value in the sequence.
    ///
    /// - Complexity: O(1).
    @inlinable
    public mutating func next() -> UInt64 {
        let scaled = state1 &* 5
        let result = ((scaled << 7) | (scaled >> 57)) &* 9
        let shifted = state1 << 17
        state2 ^= state0
        state3 ^= state1
        state1 ^= state2
        state0 ^= state3
        state2 ^= shifted
        state3 = (state3 << 45) | (state3 >> 19)
        return result
    }

    /// Advances the sequence by 2¹²⁸ steps.
    ///
    /// - Complexity: O(1): 256 steps, whatever the distance.
    public mutating func jump() {
        advance(by: [0x180E_C6D3_3CFD_0ABA, 0xD5A6_1266_F0C9_392C, 0xA958_2618_E03F_C9AA, 0x39AB_DC45_29B1_661C])
    }

    /// The generator 2¹²⁸ steps further on.
    public func jumped() -> Xoshiro256StarStar {
        var copy = self
        copy.jump()
        return copy
    }

    /// Advances the sequence by 2¹⁹² steps, so each long jump leaves room for 2⁶⁴ jumps.
    ///
    /// - Complexity: O(1): 256 steps, whatever the distance.
    public mutating func longJump() {
        advance(by: [0x76E1_5D3E_FEFD_CBBF, 0xC500_4E44_1C52_2FB3, 0x7771_0069_854E_E241, 0x3910_9BB0_2ACB_E635])
    }

    /// The generator 2¹⁹² steps further on.
    public func longJumped() -> Xoshiro256StarStar {
        var copy = self
        copy.longJump()
        return copy
    }

    // See Xoroshiro128Plus.advance(by:): the same polynomial method, over four words.
    @usableFromInline
    mutating func advance(by polynomial: [UInt64]) {
        var jumped: (UInt64, UInt64, UInt64, UInt64) = (0, 0, 0, 0)
        for word in polynomial {
            for bit in 0 ..< 64 {
                if word & (1 << bit) != 0 {
                    jumped.0 ^= state0
                    jumped.1 ^= state1
                    jumped.2 ^= state2
                    jumped.3 ^= state3
                }
                _ = next()
            }
        }
        (state0, state1, state2, state3) = jumped
    }

    enum CodingKeys: String, CodingKey {
        case state
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let words = try container.decode([UInt64].self, forKey: .state)
        guard words.count == 4 else {
            throw DecodingError.dataCorruptedError(forKey: .state, in: container, debugDescription: "Xoshiro256StarStar holds 4 state words")
        }
        guard words.contains(where: { $0 != 0 }) else {
            throw DecodingError.dataCorruptedError(forKey: .state, in: container, debugDescription: "An all-zero state only ever yields zero")
        }
        (state0, state1, state2, state3) = (words[0], words[1], words[2], words[3])
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode([state0, state1, state2, state3], forKey: .state)
    }
}
