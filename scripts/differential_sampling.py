"""The draws against the same algorithms written out in Python over the reference xoshiro256**
sequence: the top 53 bits scaled into [0, 1), rejection sampling for integers, the affine map
and clamp for intervals, the comparison for a Bernoulli trial, Fisher-Yates from the last offset
down for a shuffle, and one integer draw for an element pick. The generator's next value after a
shuffle or a pick pins how many draws it took."""

import math
import struct

import differential_generators as generators

MODULE = "Sampling"

INT_MIN, INT_MAX = -(1 << 63), (1 << 63) - 1


def generate(rng):
    kind = rng.choice(["small", "zero", "wide", "full", "one"])
    if kind == "small":
        lower = rng.randrange(-100, 100)
        upper = lower + rng.randrange(1, 100)
    elif kind == "zero":
        lower, upper = -rng.randrange(1, 1 << 40), rng.randrange(1, 1 << 40)
    elif kind == "wide":
        lower, upper = rng.randrange(INT_MIN, INT_MAX - 1), None
        upper = rng.randrange(lower + 1, INT_MAX + 1)
    elif kind == "full":
        lower, upper = INT_MIN, INT_MAX
    else:
        lower = rng.randrange(INT_MIN, INT_MAX)
        upper = lower + 1
    low = rng.uniform(-1e6, 1e6)
    return {
        "seed": rng.getrandbits(64),
        "lower": lower,
        "upper": upper,
        "closedUpper": rng.choice([upper, upper - 1]) if kind != "full" else INT_MAX,
        "intervalLower": low,
        "intervalUpper": low + rng.choice([1e-9, 1.0, 1e6, 1e12]),
        "probability": rng.choice([0.0, 1.0, rng.random()]),
        "shuffleCount": rng.choice([0, 1, 2, rng.randrange(3, 64)]),
        "elementCount": rng.choice([0, 1, rng.randrange(2, 1 << 20)]),
    }


def uniform(sequence):
    return (next(sequence) >> 11) * 2.0 ** -53


def offset(sequence, width):
    threshold = ((1 << 64) - width) % width
    value = next(sequence)
    while value < threshold:
        value = next(sequence)
    return value % width


def shuffle(sequence, elements):
    for i in range(len(elements) - 1, 0, -1):
        j = offset(sequence, i + 1)
        elements[i], elements[j] = elements[j], elements[i]
    return elements


def element(sequence, count):
    return None if count == 0 else offset(sequence, count)


def to_signed(value):
    return value - (1 << 64) if value >= (1 << 63) else value


def reference(case):
    def sequence_from(seed):
        state = generators.seed_words(seed, 4)
        while True:
            yield generators.xoshiro_output(state)
            state = generators.xoshiro_step(state)

    seed = case["seed"]
    answer = {}
    s = sequence_from(seed)
    answer["uniform"] = repr(uniform(s))
    s = sequence_from(seed)
    width = (case["upper"] - case["lower"]) & generators.MASK
    answer["integer"] = to_signed((case["lower"] + offset(s, width)) & generators.MASK)
    s = sequence_from(seed)
    width = (case["closedUpper"] - case["lower"] + 1) & generators.MASK
    answer["closedInteger"] = to_signed(next(s)) if width == 0 else to_signed((case["lower"] + offset(s, width)) & generators.MASK)
    s = sequence_from(seed)
    unit = uniform(s)
    low, high = case["intervalLower"], case["intervalUpper"]
    value = (1 - unit) * low + unit * high
    answer["interval"] = repr(max(low, min(value, math.nextafter(high, -math.inf))))
    s = sequence_from(seed)
    answer["bernoulli"] = uniform(s) < case["probability"]
    s = sequence_from(seed)
    answer["shuffled"] = shuffle(s, list(range(case["shuffleCount"])))
    answer["afterShuffle"] = next(s)
    s = sequence_from(seed)
    answer["element"] = element(s, case["elementCount"])
    answer["afterElement"] = next(s)
    return answer


def compare(case, mine, ref):
    if mine is None:
        return ["no answer"]
    return [f"{key}: library {mine.get(key)!r}, reference {ref[key]!r}" for key in sorted(ref) if mine.get(key) != ref[key]]
