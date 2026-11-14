"""The generators against pure-Python references: SplitMix64, xoroshiro128+ (2016) and
xoshiro256** written out from the reference C with 64-bit masks, and their jumps checked by a
different method altogether. Each state transition is linear over GF(2), so a jump of 2^k steps
is the transition matrix raised to 2^k by k squarings; the library's jump polynomials must land
on the same state."""

MODULE = "Generators"

MASK = (1 << 64) - 1
GOLDEN = 0x9E3779B97F4A7C15


def rotl(x, k):
    return ((x << k) | (x >> (64 - k))) & MASK


def splitmix64(seed):
    """Yields the SplitMix64 sequence from `seed`."""
    counter = seed
    while True:
        counter = (counter + GOLDEN) & MASK
        z = counter
        z = ((z ^ (z >> 30)) * 0xBF58476D1CE4E5B9) & MASK
        z = ((z ^ (z >> 27)) * 0x94D049BB133111EB) & MASK
        yield z ^ (z >> 31)


def seed_words(seed, count):
    sequence = splitmix64(seed)
    return [next(sequence) for _ in range(count)]


def xoroshiro_step(state):
    s0, s1 = state
    s1 ^= s0
    return [rotl(s0, 55) ^ s1 ^ ((s1 << 14) & MASK), rotl(s1, 36)]


def xoroshiro_output(state):
    return (state[0] + state[1]) & MASK


def xoshiro_step(state):
    s = list(state)
    t = (s[1] << 17) & MASK
    s[2] ^= s[0]
    s[3] ^= s[1]
    s[1] ^= s[2]
    s[0] ^= s[3]
    s[2] ^= t
    s[3] = rotl(s[3], 45)
    return s


def xoshiro_output(state):
    return (rotl((state[1] * 5) & MASK, 7) * 9) & MASK


GENERATORS = {
    # name: (state words, step, output, jump exponent, long jump exponent)
    "xoroshiro128plus": (2, xoroshiro_step, xoroshiro_output, 64, 96),
    "xoshiro256starstar": (4, xoshiro_step, xoshiro_output, 128, 192),
}


def outputs(name, state, count):
    _, step, output, _, _ = GENERATORS[name]
    values = []
    for _ in range(count):
        values.append(output(state))
        state = step(state)
    return values, state


def pack(words):
    value = 0
    for i, word in enumerate(words):
        value |= word << (64 * i)
    return value


def unpack(value, count):
    return [(value >> (64 * i)) & MASK for i in range(count)]


def transition_matrix(step, words):
    """The transition as its images of the unit vectors, one packed state per bit."""
    return [pack(step(unpack(1 << bit, words))) for bit in range(64 * words)]


def apply(matrix, state):
    result = 0
    bit = 0
    while state:
        if state & 1:
            result ^= matrix[bit]
        state >>= 1
        bit += 1
    return result


_POWERS = {}


def jumped(name, state, exponent):
    """The state 2^exponent steps on, by squaring the transition matrix."""
    words, step, _, _, _ = GENERATORS[name]
    key = (name, exponent)
    if key not in _POWERS:
        matrix = transition_matrix(step, words)
        for _ in range(exponent):
            matrix = [apply(matrix, column) for column in matrix]
        _POWERS[key] = matrix
    return unpack(apply(_POWERS[key], pack(state)), words)


def generate(rng):
    return {"seed": rng.getrandbits(64), "count": rng.randrange(1, 9)}


def reference(case):
    seed, count = case["seed"], case["count"]
    answer = {"splitmix64": [str(v) for v in seed_words(seed, count)]}
    for name, (words, _, _, jump, long_jump) in GENERATORS.items():
        state = seed_words(seed, words)
        values, after = outputs(name, state, count)
        answer[name] = [str(v) for v in values]
        answer[name + "_jumped"] = [str(v) for v in outputs(name, jumped(name, after, jump), 2)[0]]
        answer[name + "_long_jumped"] = [str(v) for v in outputs(name, jumped(name, after, long_jump), 2)[0]]
    return answer


def compare(case, mine, ref):
    if mine is None:
        return ["no answer"]
    return [f"{key}: library {mine.get(key)}, reference {ref[key]}" for key in sorted(ref) if mine.get(key) != ref[key]]
