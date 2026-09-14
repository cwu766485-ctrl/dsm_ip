#!/usr/bin/env python3
"""Bit-true proof for the balanced piecewise-affine temporal64 candidate."""

import argparse
import random

Q = 32767
ACC_MIN = -(1 << 27)
ACC_MAX = (1 << 27) - 1
# Full reset-reachable error invariant for Q1.15 input and +/-32767
# quantization. The extrema are reachable with opposite-signed inputs.
DOMAIN_MIN = -32769
DOMAIN_MAX = 32769


def scalar_phase(samples, state):
    bits = []
    signed = []
    values = []
    for x in samples:
        value = x - state
        value = max(ACC_MIN, min(ACC_MAX, value))
        bit = int(value >= 0)
        level = Q if bit else -Q
        bits.append(bit)
        signed.append(level)
        values.append(value)
        state = value - level
    return tuple(bits), tuple(signed), tuple(values), state


def scalar_block(samples, e1, e2):
    """Evaluate the actual delay-2 BP-EFDSM2 stream."""
    bits = []
    signed = []
    values = []
    for x in samples:
        value = x - e2
        value = max(ACC_MIN, min(ACC_MAX, value))
        bit = int(value >= 0)
        level = Q if bit else -Q
        bits.append(bit)
        signed.append(level)
        values.append(value)
        error = value - level
        e2, e1 = e1, error
    return tuple(bits), tuple(signed), tuple(values), (e1, e2)


def leaf(samples):
    """Return the exact integer intervals for one four-sample phase map."""
    maps = []
    for mask in range(1 << len(samples)):
        lo = DOMAIN_MIN
        hi = DOMAIN_MAX
        slope = 1
        offset = 0
        bits = []
        for x in samples:
            d = x - offset
            bit = (mask >> len(bits)) & 1
            bits.append(bit)
            if slope > 0:
                if bit:
                    hi = min(hi, d)
                else:
                    lo = max(lo, d + 1)
            else:
                if bit:
                    lo = max(lo, -d)
                else:
                    hi = min(hi, -d - 1)
            offset = x - offset - (Q if bit else -Q)
            slope = -slope
        lo = max(lo, DOMAIN_MIN)
        hi = min(hi, DOMAIN_MAX)
        if lo <= hi:
            maps.append((lo, hi, slope, offset, tuple(bits)))
    maps.sort(key=lambda item: item[0])
    return maps


def compose(left, right):
    """Compose right(left(state)) and preserve chronological bit order."""
    out = []
    for llo, lhi, ls, lc, lb in left:
        for rlo, rhi, rs, rc, rb in right:
            if ls > 0:
                lo = max(llo, rlo - lc)
                hi = min(lhi, rhi - lc)
            else:
                lo = max(llo, lc - rhi)
                hi = min(lhi, lc - rlo)
            lo = max(lo, DOMAIN_MIN)
            hi = min(hi, DOMAIN_MAX)
            if lo <= hi:
                out.append((lo, hi, ls * rs, rs * lc + rc, lb + rb))
    out.sort(key=lambda item: item[0])
    return out


def phase_map(samples):
    maps = [leaf(samples[i:i + 4]) for i in range(0, 32, 4)]
    while len(maps) > 1:
        maps = [compose(maps[i], maps[i + 1])
                for i in range(0, len(maps), 2)]
    return maps[0]


def map_eval(mapping, state):
    for lo, hi, slope, offset, bits in mapping:
        if lo <= state <= hi:
            return bits, slope * state + offset
    raise AssertionError("state is outside the composed map domain")


def check_block(samples, e1, e2):
    bits, signed, values, state_pair = scalar_block(samples, e1, e2)
    even_bits, even_state = map_eval(phase_map(samples[0::2]), e2)
    odd_bits, odd_state = map_eval(phase_map(samples[1::2]), e1)
    mapped_bits = tuple(bit for pair in zip(even_bits, odd_bits) for bit in pair)
    mapped_signed = tuple(Q if bit else -Q for bit in mapped_bits)
    if mapped_bits != bits:
        raise AssertionError("bit mismatch")
    if mapped_signed != signed:
        raise AssertionError("signed output mismatch")
    if (odd_state, even_state) != state_pair:
        raise AssertionError("state mismatch")
    return odd_state, even_state, values[-1]


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--blocks", type=int, default=100)
    parser.add_argument("--seed", type=int, default=20260906)
    args = parser.parse_args()
    if args.blocks <= 0:
        parser.error("--blocks must be positive")

    rng = random.Random(args.seed)
    e1 = 0
    e2 = 0
    max_regions = 0
    for block in range(args.blocks):
        samples = [rng.randrange(-32768, 32768) for _ in range(64)]
        samples[0] = -32768
        samples[1] = 32767
        e1, e2, _ = check_block(samples, e1, e2)
        max_regions = max(max_regions, len(phase_map(samples[0::2])),
                           len(phase_map(samples[1::2])))
    print("BP_EF2_PREFIX_MAP_PASS blocks=%d samples=%d max_regions=%d" %
          (args.blocks, args.blocks * 64, max_regions))


if __name__ == "__main__":
    main()
