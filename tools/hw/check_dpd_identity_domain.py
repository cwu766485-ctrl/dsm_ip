"""Exhaust the frozen DPD1 arithmetic cone over every signed 16-bit value.

This is an arithmetic proof tied to dpd_memory_poly.v with W=COEFF_W=16,
COEFF_FRAC=14, MAX_TAPS=1, active_taps=1, c1_re=16384 and all other
coefficients zero. It is not a sequential RTL/formal-tool signoff; the
companion VCS bench checks the actual pipeline, valid and counters.
"""

from __future__ import annotations


def signed16(bits: int) -> int:
    return bits - 65536 if bits >= 32768 else bits


def identity_cone(value: int) -> tuple[int, bool]:
    # RTL gain_re_s5 = c1_re + (c3*r2 >> 15) + (c5*r4 >> 15).
    gain_re = 16384
    gain_im = 0
    # RTL term_i_s8/term_q_s8 use signed 64-bit arithmetic >> 14.
    real_product = value * gain_re - 0 * gain_im
    result = real_product >> 14
    saturated = not (-32768 <= result <= 32767)
    return result, saturated


def main() -> None:
    for bits in range(65536):
        value = signed16(bits)
        result, saturated = identity_cone(value)
        if result != value or saturated:
            raise AssertionError((bits, value, result, saturated))
    print(
        "DPD_IDENTITY_ARITHMETIC_PASS domain=65536 signed_values "
        "min=-32768 max=32767 saturation=0"
    )


if __name__ == "__main__":
    main()
