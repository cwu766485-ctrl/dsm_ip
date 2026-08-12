"""Integer reference for the 3/5-order memory-polynomial DPD path."""

from .fixed import arithmetic_shift_right, saturate_signed


class ComplexCoeff:
    def __init__(self, real, imag):
        self.real = int(real)
        self.imag = int(imag)


def memory_poly(i_samples, q_samples, c1, c3, c5,
                active_taps, input_frac=15, coeff_frac=14):
    """Match the MATLAB memory_poly_model sample update and truncation order."""
    if len(i_samples) != len(q_samples):
        raise ValueError("I/Q sample counts differ")
    if not 1 <= active_taps <= min(len(c1), len(c3), len(c5)):
        raise ValueError("invalid active_taps")
    hist_i = [0] * active_taps
    hist_q = [0] * active_taps
    out_i = []
    out_q = []
    saturated = []
    for current_i, current_q in zip(i_samples, q_samples):
        hist_i[1:] = hist_i[:-1]
        hist_q[1:] = hist_q[:-1]
        hist_i[0], hist_q[0] = current_i, current_q
        acc_i = 0
        acc_q = 0
        for tap in range(active_taps):
            ii, qq = hist_i[tap], hist_q[tap]
            r2 = arithmetic_shift_right(ii * ii + qq * qq, input_frac)
            r4 = arithmetic_shift_right(r2 * r2, input_frac)
            gain_r = c1[tap].real + arithmetic_shift_right(c3[tap].real * r2, input_frac)
            gain_r += arithmetic_shift_right(c5[tap].real * r4, input_frac)
            gain_i = c1[tap].imag + arithmetic_shift_right(c3[tap].imag * r2, input_frac)
            gain_i += arithmetic_shift_right(c5[tap].imag * r4, input_frac)
            acc_i += arithmetic_shift_right(ii * gain_r - qq * gain_i, coeff_frac)
            acc_q += arithmetic_shift_right(ii * gain_i + qq * gain_r, coeff_frac)
        yi = saturate_signed(acc_i, 16)
        yq = saturate_signed(acc_q, 16)
        out_i.append(yi)
        out_q.append(yq)
        saturated.append(yi != acc_i or yq != acc_q)
    return out_i, out_q, saturated
