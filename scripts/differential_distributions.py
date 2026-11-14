"""The distributions against their algorithms written out in Python over the reference xoshiro256**
sequence: fdlibm's log, log1p, exp and sine and cosine kernels on the bits of each double,
Box–Muller, inverse distribution functions, Marsaglia and Tsang's gamma, Knuth's and Hörmann's
Poisson samplers with Stirling's series, and a linear scan for a weighted choice. Every sample is
compared bit for bit, three from one generator so that the draws each consumes are checked too.
Run directly, it prints the first samples for seed 42, the goldens the module's tests pin."""

import math
import struct

import differential_generators as generators

MODULE = "Distributions"

SAMPLES = 3


def bits(x):
    return struct.unpack("<Q", struct.pack("<d", x))[0]


def double(b):
    return struct.unpack("<d", struct.pack("<Q", b & generators.MASK))[0]


LN2_HI, LN2_LO = double(0x3FE62E42FEE00000), double(0x3DEA39EF35793C76)
LG = [double(b) for b in [0x3FE5555555555593, 0x3FD999999997FA04, 0x3FD2492494229359, 0x3FCC71C51D8E78AF,
                          0x3FC7466496CB03DE, 0x3FC39A09D078C69F, 0x3FC2F112DF3E5244]]
INV_LN2 = double(0x3FF71547652B82FE)
P = [double(b) for b in [0x3FC555555555553E, 0xBF66C16C16BEBD93, 0x3F11566AAF25DE2C, 0xBEBBBD41C5D26BF1,
                         0x3E66376972BEA4D0]]
C = [double(b) for b in [0x3FA555555555554C, 0xBF56C16C16C15177, 0x3EFA01A019CB1590, 0xBE927E4F809C52AD,
                         0x3E21EE9EBDB4B1C4, 0xBDA8FAE9BE8838D4]]
S = [double(b) for b in [0xBFC5555555555549, 0x3F8111111110F8A6, 0xBF2A01A019C161D5, 0x3EC71DE357B1FE7D,
                         0xBE5AE5E68A2B9CEB, 0x3DE5D93A5ACFD57C]]
HALF_PI = double(0x3FF921FB54442D18)


def log_tail(f, k, c=0.0):
    hfsq = 0.5 * f * f
    s = f / (2.0 + f)
    z = s * s
    w = z * z
    t1 = w * (LG[1] + w * (LG[3] + w * LG[5]))
    t2 = z * (LG[0] + w * (LG[2] + w * (LG[4] + w * LG[6])))
    r = t2 + t1
    dk = float(k)
    return s * (hfsq + r) + (dk * LN2_LO + c) - hfsq + f + dk * LN2_HI


def log(x):
    b = bits(x)
    high = b >> 32
    k = 0
    if high < 0x00100000 or high >> 31:
        if (b << 1) & generators.MASK == 0:
            return -math.inf
        if high >> 31:
            return math.nan
        k -= 54
        x *= 2.0 ** 54
        b = bits(x)
        high = b >> 32
    elif high >= 0x7FF00000:
        return x
    elif high == 0x3FF00000 and b & 0xFFFFFFFF == 0:
        return 0.0
    high = (high + 0x3FF00000 - 0x3FE6A09E) & 0xFFFFFFFF
    k += (high >> 20) - 0x3FF
    high = (high & 0x000FFFFF) + 0x3FE6A09E
    f = double((high << 32) | (b & 0xFFFFFFFF)) - 1.0
    # log's last line adds dk * LN2_LO alone; with c = 0 the sum (dk * LN2_LO + 0.0) is the same.
    return log_tail(f, k)


def log1p(x):
    high = bits(x) >> 32
    k, f, c = 1, 0.0, 0.0
    if high < 0x3FDA827A or high >> 31:
        if high >= 0xBFF00000:
            return -math.inf if x == -1.0 else math.nan
        if ((high << 1) & 0xFFFFFFFF) < ((0x3CA00000 << 1) & 0xFFFFFFFF):
            return x
        if high <= 0xBFD2BEC4:
            k, f = 0, x
    elif high >= 0x7FF00000:
        return x
    if k > 0:
        u = 1.0 + x
        b = bits(u)
        hu = ((b >> 32) + 0x3FF00000 - 0x3FE6A09E) & 0xFFFFFFFF
        k = (hu >> 20) - 0x3FF
        if k < 54:
            c = 1.0 - (u - x) if k >= 2 else x - (u - 1.0)
            c /= u
        hu = (hu & 0x000FFFFF) + 0x3FE6A09E
        f = double((hu << 32) | (b & 0xFFFFFFFF)) - 1.0
    return log_tail(f, k, c)


def scalbn(y, n):
    if n > 1023:
        y *= 2.0 ** 1023
        n -= 1023
        if n > 1023:
            y *= 2.0 ** 1023
            n -= 1023
            n = min(n, 1023)
    elif n < -1022:
        y *= 2.0 ** -969
        n += 1022 - 53
        if n < -1022:
            y *= 2.0 ** -969
            n += 1022 - 53
            n = max(n, -1022)
    return y * double((0x3FF + n) << 52)


def exp(x):
    word = bits(x) >> 32
    sign = word >> 31
    high = word & 0x7FFFFFFF
    if high >= 0x4086232B:
        if math.isnan(x):
            return x
        if x > 709.782712893383973096:
            return math.inf
        if x < -745.13321910194110842:
            return 0.0
    if high > 0x3FD62E42:
        if high >= 0x3FF0A2B2:
            k = int(INV_LN2 * x + (0.5 if sign == 0 else -0.5))  # int() truncates toward zero, as C does
        else:
            k = 1 - sign - sign
        hi = x - k * LN2_HI
        lo = k * LN2_LO
        x = hi - lo
    elif high > 0x3E300000:
        k, hi, lo = 0, x, 0.0
    else:
        return 1.0 + x
    xx = x * x
    c = x - xx * (P[0] + xx * (P[1] + xx * (P[2] + xx * (P[3] + xx * P[4]))))
    y = 1.0 + (x * c / (2.0 - c) - lo + hi)
    return y if k == 0 else scalbn(y, k)


def cos_kernel(x):
    z = x * x
    w = z * z
    r = z * (C[0] + z * (C[1] + z * C[2])) + w * w * (C[3] + z * (C[4] + z * C[5]))
    hz = 0.5 * z
    v = 1.0 - hz
    return v + (((1.0 - v) - hz) + z * r)


def sin_kernel(x):
    z = x * x
    w = z * z
    r = S[1] + z * (S[2] + z * S[3]) + z * w * (S[4] + z * S[5])
    v = z * x
    return x + v * (S[0] + z * r)


def cos_pi(x):
    quarters = 2.0 * x
    whole = float(round(quarters))  # Python rounds halves to even
    y = (quarters - whole) * HALF_PI
    return [cos_kernel(y), -sin_kernel(y), -cos_kernel(y), sin_kernel(y)][int(whole) & 3]


def uniform(sequence):
    return (next(sequence) >> 11) * 2.0 ** -53


def standard_normal(s):
    radius = math.sqrt(-2.0 * log1p(-uniform(s)))
    return radius * cos_pi(2.0 * uniform(s))


def normal(s, case):
    return case["mean"] + case["standardDeviation"] * standard_normal(s)


def exponential(s, case):
    return -log1p(-uniform(s)) * case["exponentialMean"]


def log_normal(s, case):
    return exp(case["logMean"] + case["logStandardDeviation"] * standard_normal(s))


def triangular(s, case):
    low, mode, high = case["lowerBound"], case["mode"], case["upperBound"]
    width = high - low
    if math.isfinite(width):
        fraction = (mode - low) / width
    else:
        scale = max(abs(low), abs(high))
        fraction = (mode / scale - low / scale) / (high / scale - low / scale)
    unit = uniform(s)
    position = math.sqrt(unit * fraction) if unit < fraction else 1.0 - math.sqrt((1.0 - unit) * (1.0 - fraction))
    return max(low, min((1.0 - position) * low + position * high, high))


def gamma(s, case):
    shape, scale = case["shape"], case["scale"]
    d = (shape + 1.0 if shape < 1 else shape) - 1.0 / 3.0
    c = 1.0 / math.sqrt(9.0 * d)
    while True:
        x = standard_normal(s)
        root = 1.0 + c * x
        if root <= 0:
            continue
        v = root * root * root
        u = uniform(s)
        squared = x * x
        if u < 1.0 - 0.0331 * squared * squared or log(u) < 0.5 * squared + d * (1.0 - v + log(v)):
            break
    if shape >= 1:
        return d * v * scale
    return d * v * exp(log(uniform(s)) / shape) * scale


STIRLING = [1.796443723688307e-01, -2.955065359477124e-02, 6.410256410256410e-03, -1.917526917526918e-03,
            8.417508417508418e-04, -5.952380952380952e-04, 7.936507936507937e-04, -2.777777777777778e-03,
            8.333333333333333e-02]


def log_gamma(x):
    if x in (1.0, 2.0):
        return 0.0
    shift = float(int(7.0 - x)) if x < 7 else 0.0
    shifted = x + shift
    inverse_square = (1.0 / shifted) * (1.0 / shifted)
    series = -1.39243221690590e+00
    for coefficient in STIRLING:
        series = series * inverse_square + coefficient
    result = series / shifted + 0.5 * 1.8378770664093453 + (shifted - 0.5) * log(shifted) - shifted
    while shift > 0:
        result -= log(shifted - 1.0)
        shifted -= 1.0
        shift -= 1.0
    return result


def poisson(s, case):
    mean = case["poissonMean"]
    if mean == 0:
        return 0
    if mean < 10:
        limit = exp(-mean)
        count, product = 0, uniform(s)
        while product > limit:
            count += 1
            product *= uniform(s)
        return count
    b = 0.931 + 2.53 * math.sqrt(mean)
    a = -0.059 + 0.02483 * b
    inverse_alpha = 1.1239 + 1.1328 / (b - 3.4)
    bound = 0.9277 - 3.6224 / (b - 2.0)
    log_mean = log(mean)
    while True:
        u = uniform(s) - 0.5
        v = uniform(s)
        us = 0.5 - abs(u)
        k = math.floor((2.0 * a / us + b) * u + mean + 0.43) if us > 0 else -math.inf
        if us >= 0.07 and v <= bound:
            return int(k)
        if k < 0 or k >= 2.0 ** 31 or (us < 0.013 and v > us):
            continue
        k = float(k)
        if log(v) + log(inverse_alpha) - log(a / (us * us) + b) <= -mean + k * log_mean - log_gamma(k + 1.0):
            return int(k)


def geometric(s, case):
    failures = math.floor(log1p(-uniform(s)) / log1p(-case["probability"]))
    return min(failures, (1 << 63) - 1)


def weighted_choice(s, case):
    weights = case["weights"]
    largest = max(weights)
    positive, totals, total = [], [], 0.0
    for index, weight in enumerate(weights):
        if weight > 0:
            total += weight / largest
            positive.append(index)
            totals.append(total)
    threshold = uniform(s) * totals[-1]
    for index, running in zip(positive, totals):
        if running > threshold:
            return index
    return positive[-1]


SAMPLERS = {
    "normal": normal, "exponential": exponential, "logNormal": log_normal, "triangular": triangular,
    "gamma": gamma, "poisson": poisson, "geometric": geometric, "weightedChoice": weighted_choice,
}


def generate(rng):
    low = rng.choice([rng.uniform(-1e3, 1e3), -1e308, 0.0])
    high = low + rng.choice([1e-6, 1.0, 1e6]) if low != -1e308 else 1e308
    return {
        "seed": rng.getrandbits(64),
        "mean": rng.uniform(-1e3, 1e3),
        "standardDeviation": rng.choice([0.0, 1.0, rng.uniform(0, 100)]),
        "exponentialMean": 10 ** rng.uniform(-3, 6),
        "logMean": rng.uniform(-5, 5),
        "logStandardDeviation": rng.choice([0.0, rng.uniform(0, 3)]),
        "lowerBound": low,
        "mode": rng.choice([low, high, low + (high - low) * rng.random() if low != -1e308 else rng.uniform(-1, 1) * 1e308]),
        "upperBound": high,
        "shape": rng.choice([1.0, 10 ** rng.uniform(-2, 3)]),
        "scale": 10 ** rng.uniform(-2, 2),
        "poissonMean": rng.choice([0.0, 10.0, rng.uniform(0, 10), rng.uniform(10, 1000), 10 ** rng.uniform(3, 9)]),
        "probability": rng.choice([1.0, rng.uniform(1e-6, 1), 10 ** rng.uniform(-12, 0)]),
        "weights": [rng.choice([0.0, rng.uniform(0, 10), 10 ** rng.uniform(-300, 300)]) for _ in range(rng.randrange(1, 9))] + [rng.uniform(0.1, 10)],
    }


def sequence_from(seed):
    state = generators.seed_words(seed, 4)
    while True:
        yield generators.xoshiro_output(state)
        state = generators.xoshiro_step(state)


def reference(case):
    answer = {}
    for name, sampler in SAMPLERS.items():
        s = sequence_from(case["seed"])
        samples = [sampler(s, case) for _ in range(SAMPLES)]
        answer[name] = [repr(x) if isinstance(x, float) else x for x in samples]
    return answer


def compare(case, mine, ref):
    if mine is None:
        return ["no answer"]
    return [f"{key}: library {mine.get(key)!r}, reference {ref[key]!r}" for key in sorted(ref) if mine.get(key) != ref[key]]


if __name__ == "__main__":
    golden = {
        "seed": 42, "mean": 0.0, "standardDeviation": 1.0, "exponentialMean": 1.0, "logMean": 0.0,
        "logStandardDeviation": 1.0, "lowerBound": 0.0, "mode": 1.0, "upperBound": 4.0, "shape": 2.0,
        "scale": 1.0, "poissonMean": 4.0, "probability": 0.25, "weights": [1.0, 2.0, 3.0],
    }
    for name, samples in reference(golden).items():
        print(name, samples)
    for name, overrides in [("gammaSmallShape", {"shape": 0.5}), ("poissonLargeMean", {"poissonMean": 100.0})]:
        print(name, reference({**golden, **overrides})["gamma" if name.startswith("gamma") else "poisson"])
