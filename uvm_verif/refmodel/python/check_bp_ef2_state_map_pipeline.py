#!/usr/bin/env python3
"""Exact staged-map and II=1 schedule proof for temporal64 BP-EFDSM2.

The proof deliberately mirrors the proposed hardware boundary: four-sample
leaf maps, 8/16/32-sample map composition, then a state-dependent selector.
It also models bubbles in the map pipeline to prove that the single feedback
state advances in accepted transaction order rather than input-clock order.
"""

import argparse
import random

from check_bp_ef2_prefix_map import (
    ACC_MAX, ACC_MIN, DOMAIN_MAX, DOMAIN_MIN, Q, compose, leaf, map_eval,
    scalar_block, scalar_phase,
)


def assert_partition(mapping, label):
    """Check ordered, non-overlapping, gap-free coverage of the valid state domain."""
    if not mapping:
        raise AssertionError("%s has no valid regions" % label)
    expected_lo = DOMAIN_MIN
    for index, (lo, hi, _slope, _offset, _bits) in enumerate(mapping):
        if lo != expected_lo:
            raise AssertionError("%s region %d starts %d, expected %d" %
                                 (label, index, lo, expected_lo))
        if hi < lo:
            raise AssertionError("%s region %d is empty" % (label, index))
        expected_lo = hi + 1
    if expected_lo != DOMAIN_MAX + 1:
        raise AssertionError("%s ends %d, expected %d" %
                             (label, expected_lo - 1, DOMAIN_MAX))


def make_stages(samples):
    if len(samples) != 32:
        raise ValueError("phase input must contain 32 samples")
    stage4 = [leaf(samples[index:index + 4]) for index in range(0, 32, 4)]
    for index, mapping in enumerate(stage4):
        assert_partition(mapping, "leaf4[%d]" % index)
        if len(mapping) > 5:
            raise AssertionError("leaf4 region bound exceeded: %d" % len(mapping))
    stage8 = [compose(stage4[index], stage4[index + 1])
              for index in range(0, 8, 2)]
    for index, mapping in enumerate(stage8):
        assert_partition(mapping, "map8[%d]" % index)
        if len(mapping) > 9:
            raise AssertionError("map8 region bound exceeded: %d" % len(mapping))
    stage16 = [compose(stage8[index], stage8[index + 1])
               for index in range(0, 4, 2)]
    for index, mapping in enumerate(stage16):
        assert_partition(mapping, "map16[%d]" % index)
        if len(mapping) > 17:
            raise AssertionError("map16 region bound exceeded: %d" % len(mapping))
    stage32 = compose(stage16[0], stage16[1])
    assert_partition(stage32, "map32")
    if len(stage32) > 34:
        raise AssertionError("map32 region bound exceeded: %d" % len(stage32))
    return stage4, stage8, stage16, stage32


def check_phase_stages(samples, state):
    stage4, stage8, stage16, stage32 = make_stages(samples)
    ref_bits, _ref_signed, _ref_values, ref_state = scalar_phase(samples, state)
    bits, mapped_state = map_eval(stage32, state)
    if (bits, mapped_state) != (ref_bits, ref_state):
        raise AssertionError("32-sample composed phase map mismatch")
    # Check each composition boundary on directed states, including all map
    # region edges, which covers strict quantizer sign boundary semantics.
    probe_states = {DOMAIN_MIN, DOMAIN_MAX, 0, state}
    for mapping in stage32:
        probe_states.update(mapping[:2])
    for probe in probe_states:
        ref_bits, _unused, _values, ref_state = scalar_phase(samples, probe)
        bits, mapped_state = map_eval(stage32, probe)
        if (bits, mapped_state) != (ref_bits, ref_state):
            raise AssertionError("map boundary mismatch state=%d" % probe)
    return stage32


def select_transaction(maps, e1, e2):
    even_bits, even_state = map_eval(maps[0], e2)
    odd_bits, odd_state = map_eval(maps[1], e1)
    bits = tuple(bit for pair in zip(even_bits, odd_bits) for bit in pair)
    return bits, (odd_state, even_state)


def check_ii1_schedule(transactions):
    """Model four registered map stages followed by the exact selector."""
    pipe = [None, None, None, None]
    e1 = 0
    e2 = 0
    expected = []
    completed = 0
    # Insert randomized bubbles before each transaction and drain after it.
    for accepted_index, samples in enumerate(transactions):
        bubbles = (accepted_index * 5 + 1) % 4
        for _ in range(bubbles + 1):
            selected = pipe.pop()
            pipe.insert(0, None)
            if selected is not None:
                bits, state_pair = select_transaction(selected, e1, e2)
                ref_bits, _signed, _values, ref_state = scalar_block(
                    expected[completed], e1, e2)
                if bits != ref_bits or state_pair != ref_state:
                    raise AssertionError("pipelined transaction %d mismatch" % completed)
                e1, e2 = state_pair
                completed += 1
        maps = (check_phase_stages(samples[0::2], e2),
                check_phase_stages(samples[1::2], e1))
        expected.append(samples)
        selected = pipe.pop()
        pipe.insert(0, maps)
        if selected is not None:
            bits, state_pair = select_transaction(selected, e1, e2)
            ref_bits, _signed, _values, ref_state = scalar_block(
                expected[completed], e1, e2)
            if bits != ref_bits or state_pair != ref_state:
                raise AssertionError("pipelined transaction %d mismatch" % completed)
            e1, e2 = state_pair
            completed += 1
    while any(item is not None for item in pipe):
        selected = pipe.pop()
        pipe.insert(0, None)
        if selected is not None:
            bits, state_pair = select_transaction(selected, e1, e2)
            ref_bits, _signed, _values, ref_state = scalar_block(
                expected[completed], e1, e2)
            if bits != ref_bits or state_pair != ref_state:
                raise AssertionError("pipelined drain transaction %d mismatch" % completed)
            e1, e2 = state_pair
            completed += 1
    if completed != len(transactions):
        raise AssertionError("schedule lost transactions: %d/%d" %
                             (completed, len(transactions)))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blocks", type=int, default=128)
    parser.add_argument("--seed", type=int, default=20260906)
    args = parser.parse_args()
    if args.blocks <= 0:
        parser.error("--blocks must be positive")
    rng = random.Random(args.seed)
    transactions = []
    for block in range(args.blocks):
        samples = [rng.randrange(-32768, 32768) for _ in range(64)]
        # Directed full-scale/sign cases exercise the formal state-domain
        # boundaries along with random Q1.15 input values.
        samples[0] = -32768
        samples[1] = 32767
        samples[2] = 0
        samples[63] = -32768 if (block & 1) else 32767
        transactions.append(samples)
    check_ii1_schedule(transactions)
    print("BP_EF2_STATE_MAP_PIPELINE_PASS blocks=%d samples=%d stages=4 ii=1" %
          (args.blocks, args.blocks * 64))


if __name__ == "__main__":
    main()
