"""Seed trees against a reference that recomputes each node from the root: FNV-1a over the
name's UTF-8 bytes or the index xored with its constant, one SplitMix64 step for the key, one
more for the child, and overrides by full path."""

import differential_generators as generators

MODULE = "SeedTrees"

NAMES = ["agent", "delay", "", "7", "a", "é", "👋🏽", "x" * 40]
INDEX_CONSTANT = 0x6A09E667F3BCC908


def derive(value):
    return next(generators.splitmix64(value))


def mixing_value(key):
    if isinstance(key, int):
        return derive((key & generators.MASK) ^ INDEX_CONSTANT)
    hash_ = 0xCBF29CE484222325
    for byte in key.encode("utf-8"):
        hash_ = ((hash_ ^ byte) * 0x100000001B3) & generators.MASK
    return derive(hash_)


def random_key(rng):
    if rng.random() < 0.5:
        return rng.choice([0, 1, -1, 7, 2**31 - 1, -(2**31), rng.randrange(-1000, 1000)])
    return rng.choice(NAMES)


def generate(rng):
    paths = [[random_key(rng) for _ in range(rng.randrange(0, 4))] for _ in range(rng.randrange(1, 5))]
    overrides = [{"path": rng.choice(paths)[: rng.randrange(0, 4)], "seed": rng.getrandbits(64)} for _ in range(rng.randrange(0, 3))]
    return {"root": rng.getrandbits(64), "overrides": overrides, "paths": paths}


def seed_of(root, overrides, path):
    seed = overrides.get((), root)
    for depth, key in enumerate(path):
        seed = overrides.get(tuple(path[: depth + 1]), derive(seed ^ mixing_value(key)))
    return seed


def reference(case):
    overrides = {tuple(o["path"]): o["seed"] for o in case["overrides"]}
    return {"seeds": [str(seed_of(case["root"], overrides, path)) for path in case["paths"]]}


def compare(case, mine, ref):
    if mine is None:
        return ["no answer"]
    return [] if mine.get("seeds") == ref["seeds"] else [f"seeds: library {mine.get('seeds')}, reference {ref['seeds']}"]
