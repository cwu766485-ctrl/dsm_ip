"""Interval proof for the frozen 2-tap half-sample interpolation preset.

The phase-1 accumulator in dsm_interp_x2_polyphase_vector.sv uses two
nonnegative Q2.14 coefficients of 8192 each. Phase-0 is an exact copy.
This proves the saturation branch cannot fire for any signed 16-bit inputs;
it does not substitute for a sequential RTL test of reset/backpressure.
"""


def round_away_from_zero(acc: int) -> int:
    if acc >= 0:
        return (acc + 8192) >> 14
    return -((-acc + 8192) >> 14)


def main() -> None:
    lo, hi = -32768, 32767
    coeff = (8192, 8192)
    assert sum(coeff) == 16384 and min(coeff) >= 0
    # A positive weighted sum is monotone in each independent input.
    acc_lo = sum(lo * c for c in coeff)
    acc_hi = sum(hi * c for c in coeff)
    assert round_away_from_zero(acc_lo) == lo
    assert round_away_from_zero(acc_hi) == hi
    for a in (lo, lo + 1, -1, 0, 1, hi - 1, hi):
        for b in (lo, lo + 1, -1, 0, 1, hi - 1, hi):
            result = round_away_from_zero(a * coeff[0] + b * coeff[1])
            assert lo <= result <= hi
    print("INTERP2_SATURATION_INTERVAL_PASS phase0=copy phase1=[-32768,32767]")


if __name__ == "__main__":
    main()
