import random
import unittest

from mash_weighted_contract import Q, weighted_decode, weighted_encode


def encode_raw(level, lane, component):
    positive = level > 0
    if component == 0:
        bit = positive if lane % 2 == 0 else not positive
    else:
        bit = not positive if lane % 2 == 0 else positive
    return int(bit)


def raw_word(levels):
    word = 0
    for lane, (i, q) in enumerate(levels):
        for component, value in enumerate((i, q)):
            if encode_raw(value, lane, component):
                word |= 1 << (2 * lane + component)
    return word


class WeightedContractTest(unittest.TestCase):
    def test_all_levels_and_fs4_packing(self):
        rng = random.Random(20261118)
        previous = (-1, -1)
        for _ in range(128):
            first = [(rng.choice((-1, 1)), rng.choice((-1, 1)))
                     for _ in range(32)]
            second = [(rng.choice((-1, 1)), rng.choice((-1, 1)))
                      for _ in range(32)]
            a0, a1, levels, previous = weighted_encode(
                raw_word(first), raw_word(second), previous)
            self.assertEqual(weighted_decode(a0, a1), levels)
            self.assertTrue(all(i in (-3, -1, 1, 3) and
                                q in (-3, -1, 1, 3) for i, q in levels))

    def test_weighted_sum_is_not_raw_stage_sum(self):
        first = [(1, -1)] * 32
        second = [(-1, 1)] * 32
        a0, a1, levels, _ = weighted_encode(raw_word(first), raw_word(second))
        self.assertEqual(weighted_decode(a0, a1), levels)
        self.assertNotEqual(levels[0][0], first[0][0] + 2 * second[0][0])


if __name__ == "__main__":
    unittest.main()
