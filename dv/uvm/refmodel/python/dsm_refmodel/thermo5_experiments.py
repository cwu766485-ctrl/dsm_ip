"""Software-only TIDSM alternatives used by the thermo5 order benchmark.

The first-order path calls the independent scalar recurrence that matches RTL.
The error-feedback paths are floating-point architecture studies, not RTL models.
"""

import math

from .thermo5_receiver import scalar_efm_polar


ERROR_FEEDBACK_NTF = {
    1: (1.0,),
    2: (2.0, -1.0),
    3: (3.0, -3.0, 1.0),
}


def _error_feedback_quantize(samples, offset, order, width=16):
    """Run ``NTF=(1-z^-1)^order`` with a sign quantizer and error feedback."""
    if order not in ERROR_FEEDBACK_NTF:
        raise ValueError("error-feedback order must be 1, 2, or 3")
    low = -(1 << (width - 1))
    high = (1 << (width - 1)) - 1
    coefficients = ERROR_FEEDBACK_NTF[order]
    errors = [0.0] * order
    output = []
    input_clips = 0
    overrange = 0
    max_abs_u = 0.0
    max_abs_error = 0.0

    for sample in samples:
        raw = int(sample) + int(offset)
        clipped = min(max(raw, low), high)
        input_clips += int(clipped != raw)
        x = clipped / float(1 << (width - 1))
        u = x + sum(coefficient * error
                    for coefficient, error in zip(coefficients, errors))
        # Match the existing RTL's negative decision for an exact zero state.
        quantized = 1 if u > 0.0 else -1
        error = u - quantized
        output.append(quantized)
        overrange += int(abs(u) > 1.0)
        max_abs_u = max(max_abs_u, abs(u))
        max_abs_error = max(max_abs_error, abs(error))
        errors = [error] + errors[:-1]

    return output, {
        "input_saturation_samples": input_clips,
        "quantizer_overrange_samples": overrange,
        "max_abs_quantizer_input": max_abs_u,
        "max_abs_error_state": max_abs_error,
        "final_error_states": errors,
        "finite": all(math.isfinite(value) for value in errors) and
                  math.isfinite(max_abs_u) and math.isfinite(max_abs_error),
    }


def _error_feedback_quantize_ef2_fixed(samples, offset, width=16,
                                       state_width=None):
    """Integer EF2 with configurable signed state width and saturation.

    ``state_width`` changes only the state rails; the Q1.(width-1) input,
    sign quantizer, and feedback coefficients 2/-1 are unchanged. Omitting it
    preserves the historical width+4 behavior.
    """
    input_low = -(1 << (width - 1))
    input_high = (1 << (width - 1)) - 1
    if state_width is None:
        state_width = width + 4
    if state_width < 2:
        raise ValueError("state_width must be at least two bits")
    state_low = -(1 << (state_width - 1))
    state_high = (1 << (state_width - 1)) - 1
    one = 1 << (width - 1)
    e1 = e2 = 0
    output = []
    input_clips = state_clips = overrange = 0
    max_abs_u = max_abs_error = 0
    for sample in samples:
        raw = int(sample) + int(offset)
        x = min(max(raw, input_low), input_high)
        input_clips += int(x != raw)
        u = x + 2 * e1 - e2
        positive = u > 0
        error_raw = u - (one if positive else -one)
        error = min(max(error_raw, state_low), state_high)
        state_clips += int(error != error_raw)
        output.append(1 if positive else -1)
        e2, e1 = e1, error
        overrange += int(abs(u) > one)
        max_abs_u = max(max_abs_u, abs(u))
        max_abs_error = max(max_abs_error, abs(error))

    scale = float(one)
    return output, {
        "input_saturation_samples": input_clips,
        "state_saturation_samples": state_clips,
        "quantizer_overrange_samples": overrange,
        "max_abs_quantizer_input": max_abs_u / scale,
        "max_abs_error_state": max_abs_error / scale,
        "max_abs_quantizer_input_lsb": max_abs_u,
        "max_abs_error_state_lsb": max_abs_error,
        "final_error_states": [e1 / scale, e2 / scale],
        "finite": True,
        "state_width_bits": int(state_width),
        "fixed_point": "signed Q1.%d input, signed %d-bit state with %d fractional bits" %
                       (width - 1, state_width, width - 1),
    }


def pack_fs4_branch_streams(branch_i, branch_q):
    """Pack four decoded bipolar I/Q branch streams into thermo5 FS/4 words."""
    if len(branch_i) != 4 or len(branch_q) != 4:
        raise ValueError("thermo5 requires four I and four Q branch streams")
    count = len(branch_i[0])
    if count == 0 or count % 32:
        raise ValueError("branch streams must contain complete 32-sample words")
    if any(len(stream) != count for stream in branch_i + branch_q):
        raise ValueError("all branch streams must have equal length")

    words = []
    for first in range(0, count, 32):
        planes = [0, 0, 0, 0]
        for branch in range(4):
            for lane in range(32):
                sample_i = branch_i[branch][first + lane]
                sample_q = branch_q[branch][first + lane]
                bit_i = sample_i > 0 if lane % 2 == 0 else sample_i < 0
                bit_q = sample_q < 0 if lane % 2 == 0 else sample_q > 0
                if bit_i:
                    planes[branch] |= 1 << (2 * lane)
                if bit_q:
                    planes[branch] |= 1 << (2 * lane + 1)
        words.append(tuple(planes))
    return words


def generate_thermo5_tidsm_planes(i_samples, q_samples, step,
                                  mode="rtl_first_order",
                                  rtl_latency_samples=1024,
                                  state_width=None):
    """Generate output words for the RTL baseline or an EF order experiment.

    ``rtl_first_order`` is padded to the measured RTL transaction latency and
    uses the exact scalar RTL recurrence. EF candidates are sample-serial
    behavioral models with no claimed implementation latency.
    """
    if len(i_samples) != len(q_samples) or len(i_samples) % 32:
        raise ValueError("I/Q input streams must have equal 32-sample word counts")
    if not i_samples or rtl_latency_samples < 0:
        raise ValueError("input and latency must be non-empty/nonnegative")
    offsets = (3 * int(step), int(step), -int(step), -3 * int(step))
    branch_i = []
    branch_q = []
    diagnostics = []

    if mode == "rtl_first_order":
        if rtl_latency_samples >= len(i_samples):
            raise ValueError("RTL latency must be shorter than the input frame")
        for offset in offsets:
            for samples, output, component in (
                    (i_samples, branch_i, "i"), (q_samples, branch_q, "q")):
                clipped_count = sum(
                    int(min(max(int(value) + offset, -32768), 32767) !=
                        int(value) + offset) for value in samples)
                stream = scalar_efm_polar(samples, offset=offset, width=16)
                delayed = ([-1] * rtl_latency_samples +
                           stream[:len(stream) - rtl_latency_samples])
                output.append(delayed)
                diagnostics.append({
                    "branch": len(branch_i) - 1 if component == "q" else len(branch_i),
                    "component": component,
                    "input_saturation_samples": clipped_count,
                })
        latency = int(rtl_latency_samples)
        stats = {
            "input_saturation_samples": sum(
                item["input_saturation_samples"] for item in diagnostics),
            "max_abs_error_state": None,
            "max_abs_quantizer_input": None,
            "quantizer_overrange_samples": None,
            "finite": True,
            "model": "exact scalar recurrence matched to the current RTL",
        }
    elif mode == "ef_order2_fixed":
        for offset in offsets:
            for samples, output, component in (
                    (i_samples, branch_i, "i"), (q_samples, branch_q, "q")):
                stream, branch_stats = _error_feedback_quantize_ef2_fixed(
                    samples, offset, width=16, state_width=state_width)
                output.append(stream)
                diagnostics.append({
                    "branch": len(branch_i) - 1 if component == "q" else len(branch_i),
                    "component": component,
                    **branch_stats
                })
        latency = 0
        stats = {
            "input_saturation_samples": sum(
                item["input_saturation_samples"] for item in diagnostics),
            "state_saturation_samples": sum(
                item["state_saturation_samples"] for item in diagnostics),
            "max_abs_error_state": max(
                item["max_abs_error_state"] for item in diagnostics),
            "max_abs_quantizer_input": max(
                item["max_abs_quantizer_input"] for item in diagnostics),
            "quantizer_overrange_samples": sum(
                item["quantizer_overrange_samples"] for item in diagnostics),
            "finite": all(item["finite"] for item in diagnostics),
            "order": 2,
            "ntf": "(1-z^-1)^2 before saturation",
            "feedback_coefficients": [2, -1],
            "state_width_bits": diagnostics[0]["state_width_bits"],
            "model": "integer Q1.15/Q state-width error-feedback model with saturation",
        }
    elif mode.startswith("ef_order"):
        try:
            order = int(mode[len("ef_order"):])
        except ValueError:
            raise ValueError("EF mode must be ef_order1, ef_order2, or ef_order3")
        if order not in ERROR_FEEDBACK_NTF:
            raise ValueError("EF mode must be ef_order1, ef_order2, or ef_order3")
        for offset in offsets:
            for samples, output, component in (
                    (i_samples, branch_i, "i"), (q_samples, branch_q, "q")):
                stream, branch_stats = _error_feedback_quantize(
                    samples, offset, order, width=16)
                output.append(stream)
                diagnostics.append({
                    "branch": len(branch_i) - 1 if component == "q" else len(branch_i),
                    "component": component,
                    **branch_stats
                })
        latency = 0
        stats = {
            "input_saturation_samples": sum(
                item["input_saturation_samples"] for item in diagnostics),
            "max_abs_error_state": max(
                item["max_abs_error_state"] for item in diagnostics),
            "max_abs_quantizer_input": max(
                item["max_abs_quantizer_input"] for item in diagnostics),
            "quantizer_overrange_samples": sum(
                item["quantizer_overrange_samples"] for item in diagnostics),
            "finite": all(item["finite"] for item in diagnostics),
            "order": order,
            "ntf": "(1-z^-1)^%d" % order,
            "feedback_coefficients": list(ERROR_FEEDBACK_NTF[order]),
            "model": "floating-point sample-serial error-feedback prototype",
        }
    else:
        raise ValueError("unknown TIDSM candidate mode: " + str(mode))

    stats["branch_diagnostics"] = diagnostics
    stats["alignment_latency_samples"] = latency
    return pack_fs4_branch_streams(branch_i, branch_q), stats
