#!/usr/bin/env python3
"""Check all 21-bit reduced numerators against the original Q14 rounding."""

def clamp(x):
    return max(-32768, min(32767, x))


def main():
    for n in range(-(1 << 20), 1 << 20):
        value = n * 1024
        reference = ((value + 8192) >> 14 if value >= 0 else
                     -(((-value) + 8192) >> 14))
        candidate = (n + (7 if n < 0 else 8)) >> 4
        if clamp(reference) != clamp(candidate):
            raise AssertionError((n, reference, candidate))
    print('CUBIC_REDUCED_NUMERATOR_EXHAUSTIVE_PASS count=2097152 W=16')


if __name__ == '__main__':
    main()
