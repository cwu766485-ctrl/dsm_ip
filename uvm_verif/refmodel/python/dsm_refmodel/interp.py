"""Integer reference for the shipped half-band/CIC interpolation frontend."""

from .fixed import saturate_signed


COEFF_FRAC = 16
HALFBAND_47 = (
    -145, 0, 193, 0, -323, 0, 555, 0, -914, 0, 1434, 0, -2170,
    0, 3221, 0, -4805, 0, 7491, 0, -13392, 0, 41587, 65606, 41587,
    0, -13392, 0, 7491, 0, -4805, 0, 3221, 0, -2170, 0, 1434, 0,
    -914, 0, 555, 0, -323, 0, 193, 0, -145,
)
CIC_29 = (
    128, 512, 1280, 2560, 4480, 7168, 10752, 15360, 20608, 26112,
    31488, 36352, 40320, 43008, 44032, 43008, 40320, 36352, 31488,
    26112, 20608, 15360, 10752, 7168, 4480, 2560, 1280, 512, 128,
)
COMP_63 = (
    182, 167, 157, 148, 132, 101, 46, -36, -152, -298, -473, -665,
    -861, -1041, -1185, -1268, -1270, -1167, -946, -596, -117, 485,
    1193, 1982, 2818, 3664, 4475, 5212, 5832, 6303, 6596, 6696, 6596,
    6303, 5832, 5212, 4475, 3664, 2818, 1982, 1193, 485, -117, -596, -946,
    -1167, -1270, -1268, -1185, -1041, -861, -665, -473, -298, -152,
    -36, 46, 101, 132, 148, 157, 167, 182,
)


def round_shift_symmetric(value, shift):
    """RTL/MATLAB round-to-nearest, ties-away-from-zero."""
    if shift <= 0:
        return value
    bias = 1 << (shift - 1)
    return (value + bias) >> shift if value >= 0 else -((-value + bias) >> shift)


def fir_fixed(samples, coeffs, interp=1):
    """Causal Q1.15 FIR with Q2.16 coefficients and 16-bit saturation."""
    history = [0] * len(coeffs)
    output = []
    for sample in samples:
        for phase in range(interp):
            x = sample if phase == 0 else 0
            history[1:] = history[:-1]
            history[0] = x
            acc = sum(tap * coeff for tap, coeff in zip(history, coeffs))
            output.append(saturate_signed(round_shift_symmetric(acc, COEFF_FRAC), 16))
    return output


def interp_frontend(samples, mode):
    """Reference I or Q path for frontend modes 0..4, implementation I0."""
    if mode == 0:
        return list(samples)
    stages = {1: 2, 2: 3, 3: 4, 4: 2}
    if mode not in stages:
        raise ValueError(f"unsupported interpolation mode {mode}")
    out = list(samples)
    for _ in range(stages[mode]):
        out = fir_fixed(out, HALFBAND_47, interp=2)
    if mode == 4:
        out = fir_fixed(out, CIC_29, interp=8)
        out = fir_fixed(out, COMP_63)
    return out
