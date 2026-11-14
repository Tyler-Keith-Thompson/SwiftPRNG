# Planted bugs for Generators; run with `just mutate Generators`. See scripts/mutate.py.
#
# Each mutant is Mutant(name, file, old, new), where `old` occurs once in Sources/Generators/<file>
# (or `nth=` picks one), and mode="stmt" replaces whole statements rather than an expression.
# Every mutant must be caught; one that survives needs a test, or a note here saying why it is
# equivalent to the original.
#
# Known equivalent mutants (they survive by design): none.

TESTS = ["GeneratorsTests"]

S = "SplitMix64.swift"
R = "Xoroshiro128Plus.swift"
X = "Xoshiro256StarStar.swift"

MUTANTS = [
    # SplitMix64
    Mutant("splitmix_nogolden", S, "counter &+= 0x9E37_79B9_7F4A_7C15", "counter &+= 1", mode="stmt"),
    Mutant("splitmix_lastshift", S, "return mixed ^ (mixed >> 31)", "return mixed", mode="stmt"),
    Mutant("splitmix_shift30", S, "(mixed ^ (mixed >> 30))", "(mixed ^ (mixed >> 29))"),
    Mutant("splitmix_nostate", S, "counter &+= 0x9E37_79B9_7F4A_7C15", "", mode="stmt"),
    # Xoroshiro128Plus
    Mutant("xoroshiro_seedonce", R, "state1 = seeder.next()", "state1 = state0", mode="stmt"),
    Mutant("xoroshiro_xoroutput", R, "state0 &+ state1", "state0 ^ state1"),
    Mutant("xoroshiro_rot36", R, "(mixed << 36) | (mixed >> 28)", "(mixed << 37) | (mixed >> 27)"),
    Mutant("xoroshiro_rot55", R, "((state0 << 55) | (state0 >> 9))", "((state0 << 24) | (state0 >> 40))"),
    Mutant("xoroshiro_shift14", R, "(mixed << 14)", "(mixed << 16)"),
    Mutant("xoroshiro_jumpconstant", R, "0xBEAC_0467_EBA5_FACB", "0xBEAC_0467_EBA5_FACA"),
    Mutant("xoroshiro_longjumpconstant", R, "0xF2DE_AC28_BEF3_BB07", "0xF2DE_AC28_BEF3_BB06"),
    Mutant("xoroshiro_jumpnostep", R, "_ = next()", "", mode="stmt"),
    Mutant("xoroshiro_jumpedinplace", R, "copy.jump()", "", mode="stmt"),
    Mutant("xoroshiro_longjumpedinplace", R, "copy.longJump()", "", mode="stmt"),
    Mutant("xoroshiro_decodezero", R, "words.contains(where: { $0 != 0 })", "true"),
    Mutant("xoroshiro_decodecount", R, "words.count == 2", "words.count >= 2"),
    Mutant("xoroshiro_encodeswap", R, "[state0, state1]", "[state1, state0]"),
    # Xoshiro256StarStar
    Mutant("xoshiro_seedthree", X, "state3 = seeder.next()", "state3 = state2", mode="stmt"),
    Mutant("xoshiro_scale5", X, "state1 &* 5", "state1 &* 3"),
    Mutant("xoshiro_scale9", X, "((scaled << 7) | (scaled >> 57)) &* 9", "((scaled << 7) | (scaled >> 57)) &* 7"),
    Mutant("xoshiro_shift17", X, "state1 << 17", "state1 << 16"),
    Mutant("xoshiro_rot45", X, "(state3 << 45) | (state3 >> 19)", "(state3 << 44) | (state3 >> 20)"),
    Mutant("xoshiro_noshift", X, "state2 ^= shifted", "", mode="stmt"),
    Mutant("xoshiro_jumpconstant", X, "0x180E_C6D3_3CFD_0ABA", "0x180E_C6D3_3CFD_0ABB"),
    Mutant("xoshiro_longjumpconstant", X, "0x3910_9BB0_2ACB_E635", "0x3910_9BB0_2ACB_E634"),
    Mutant("xoshiro_jumpnostep", X, "_ = next()", "", mode="stmt"),
    Mutant("xoshiro_jumpedinplace", X, "copy.jump()", "", mode="stmt"),
    Mutant("xoshiro_decodezero", X, "words.contains(where: { $0 != 0 })", "true"),
    Mutant("xoshiro_decodecount", X, "words.count == 4", "words.count >= 4"),
]
