"""Thermo5 raw-plane serialization, Fs/4 mapping, and scalar TID audit helpers."""

import math

from .thermo5 import (
    INTERP_COEFFS_Q14,
    round_shift_symmetric,
    saturate_signed,
    tid_word,
)


def decode_fs4_branch_word(plane_word, branch=0):
    """Decode one 64-bit raw plane into its 32 bipolar I/Q samples.

    Bit zero is the earliest serial bit. The alternating I/Q polarity is the
    RTL Fs/4 mapping; this function removes that polarity and maps bit 0/1 to
    -1/+1. The returned values are one branch's normalized switching levels.
    """
    if not 0 <= int(plane_word) < (1 << 64):
        raise ValueError("plane word must fit in 64 bits")
    if branch not in range(4):
        raise ValueError("branch index must be 0..3")
    out_i = []
    out_q = []
    for lane in range(32):
        bit_i = 1 if (plane_word >> (2 * lane)) & 1 else -1
        bit_q = 1 if (plane_word >> (2 * lane + 1)) & 1 else -1
        out_i.append(bit_i if lane % 2 == 0 else -bit_i)
        out_q.append(-bit_q if lane % 2 == 0 else bit_q)
    return out_i, out_q


def decode_thermo5_plane_words(plane_words, normalize=True):
    """Return the combined complex baseband samples reconstructed from planes.

    ``plane_words`` contains one four-word tuple per core transaction. Each
    branch is bipolar decoded and Fs/4 de-rotated before the four equal-weight
    branch outputs are summed. ``normalize=True`` returns levels in [-1, 1];
    the physical equal-weight PA sum is four times this value.
    """
    scale = 0.25 if normalize else 1.0
    output = []
    for word in plane_words:
        if len(word) != 4:
            raise ValueError("each output transaction must contain four planes")
        branch_iq = [decode_fs4_branch_word(plane, branch)
                     for branch, plane in enumerate(word)]
        for lane in range(32):
            sample_i = sum(branch_iq[b][0][lane] for b in range(4)) * scale
            sample_q = sum(branch_iq[b][1][lane] for b in range(4)) * scale
            output.append(complex(sample_i, sample_q))
    return output


def serialize_thermo5_plane_words(plane_words):
    """Combine four equal-weight PA planes into the real raw Fs/4 sample stream.

    The returned values are the unscaled bipolar PA sum (-4, -2, 0, 2, 4).
    Within each 64-bit word, bit zero is serialized first.
    """
    output = []
    for word in plane_words:
        if len(word) != 4:
            raise ValueError("each output transaction must contain four planes")
        for bit_index in range(64):
            output.append(sum(1 if (int(plane) >> bit_index) & 1 else -1
                              for plane in word))
    return output


def scalar_efm_polar(samples, offset=0, width=16):
    """Independent scalar first-order EFM output used to audit TID plane timing."""
    modulus = 1 << width
    state_mask = (1 << (width + 1)) - 1
    sign_bit = 1 << width
    low = -(1 << (width - 1))
    high = (1 << (width - 1)) - 1
    state = 0
    output = []
    for sample in samples:
        value = min(max(int(sample) + int(offset), low), high)
        offset_binary = (value + (1 << (width - 1))) & (modulus - 1)
        state = (offset_binary + (state & (modulus - 1))) & state_mask
        output.append(1 if state & sign_bit else -1)
    return output


def audit_thermo5_plane_alignment(plane_words, input_i, input_q, step=7168,
                                 latency_samples=1056):
    """Compare decoded raw planes with four independent scalar EFM streams.

    ``latency_samples`` is measured at the complex-sample rate entering TID.
    A vector stream with its first 32-sample pipeline word removed uses 1024;
    the untrimmed TID word stream uses 1056.
    """
    if len(input_i) != len(input_q):
        raise ValueError("input I/Q lengths differ")
    # Reassemble each branch's I/Q stream from word-major decoded values.
    branch_i = [[] for _ in range(4)]
    branch_q = [[] for _ in range(4)]
    for word in plane_words:
        for branch, plane in enumerate(word):
            out_i, out_q = decode_fs4_branch_word(plane, branch)
            branch_i[branch].extend(out_i)
            branch_q[branch].extend(out_q)

    offsets = (3 * int(step), int(step), -int(step), -3 * int(step))
    details = []
    total_mismatches = 0
    total_compared = 0
    for branch, offset in enumerate(offsets):
        ref_i = scalar_efm_polar(input_i, offset)
        ref_q = scalar_efm_polar(input_q, offset)
        for component, actual, reference in (
                ("i", branch_i[branch], ref_i),
                ("q", branch_q[branch], ref_q)):
            count = min(max(0, len(actual) - latency_samples), len(reference))
            mismatches = sum(
                actual[index + latency_samples] != reference[index]
                for index in range(count))
            details.append({
                "branch": branch,
                "component": component,
                "mismatches": mismatches,
                "compared_samples": count,
            })
            total_mismatches += mismatches
            total_compared += count
    return {
        "latency_samples": int(latency_samples),
        "mismatches": total_mismatches,
        "compared_samples": total_compared,
        "streams": details,
    }


def run_tid_plane_stream(i_samples, q_samples, step=7168, width=16,
                         drop_first_word=True, append_flush=True):
    """Run the vector TID model on an already interpolated I/Q sample stream.

    Samples are grouped into 32-lane transactions. This helper exposes the
    TID boundary separately from interpolation so alternate FIR candidates
    can be compared through the same TID and receiver chain.
    """
    if len(i_samples) != len(q_samples) or len(i_samples) % 32:
        raise ValueError("TID I/Q streams must have equal lengths divisible by 32")
    states = None
    words = []
    for first in range(0, len(i_samples), 32):
        word, states = tid_word(
            i_samples[first:first + 32], q_samples[first:first + 32],
            states, width=width, step=step)
        words.append(word)
    if append_flush and words:
        flush, states = tid_word([0] * 32, [0] * 32, states,
                                 width=width, step=step)
        words.append(flush)
    if drop_first_word and words:
        words = words[1:]
    return words


def interpolate_x2_rtl(samples, taps=2):
    """Apply the existing causal RTL x2 coefficients to signed I/Q tuples."""
    if taps not in INTERP_COEFFS_Q14:
        raise ValueError("taps must be 2, 3, or 4")
    history = [(0, 0)] * (taps - 1)
    coeffs = INTERP_COEFFS_Q14[taps]
    output = []
    for current in samples:
        terms = [current] + history
        accum_i = sum(int(term[0]) * coeff for term, coeff in zip(terms, coeffs))
        accum_q = sum(int(term[1]) * coeff for term, coeff in zip(terms, coeffs))
        odd = (
            saturate_signed(round_shift_symmetric(accum_i, 14), 16),
            saturate_signed(round_shift_symmetric(accum_q, 14), 16),
        )
        output.extend((current, odd))
        if history:
            history = [current] + history[:-1]
    return output


def interpolate_x2_centered_cubic(samples):
    """Block-mode centered cubic x2 interpolation with zero extension.

    Each odd output is at n+1/2 and uses x[n-1:n+3] with Q14 coefficients
    [-1, 9, 9, -1]/16. The complete block makes its future samples available;
    streaming latency and frame-end flushing are reported by the benchmark.
    """
    coeffs = (-1024, 9216, 9216, -1024)
    count = len(samples)
    output = []
    for index, current in enumerate(samples):
        neighborhood = [samples[position] if 0 <= position < count else (0, 0)
                        for position in (index - 1, index, index + 1, index + 2)]
        accum_i = sum(int(term[0]) * coeff
                      for term, coeff in zip(neighborhood, coeffs))
        accum_q = sum(int(term[1]) * coeff
                      for term, coeff in zip(neighborhood, coeffs))
        odd = (
            saturate_signed(round_shift_symmetric(accum_i, 14), 16),
            saturate_signed(round_shift_symmetric(accum_q, 14), 16),
        )
        output.extend((current, odd))
    return output


def interpolate_x4(samples, method="rtl2"):
    """Apply two x2 stages; method is ``rtl2`` or ``centered_cubic``."""
    if method == "rtl2":
        stage = interpolate_x2_rtl(samples, 2)
        return interpolate_x2_rtl(stage, 2)
    if method == "centered_cubic":
        source_count = len(samples)
        # Three zero source samples cover the maximum future dependency of
        # the two-stage cascade; retain only the original frame's 4x outputs.
        padded = list(samples) + [(0, 0)] * 3
        stage = interpolate_x2_centered_cubic(padded)
        return interpolate_x2_centered_cubic(stage)[:4 * source_count]
    raise ValueError("method must be rtl2 or centered_cubic")


def centered_cubic_stream_contract(input_lanes_per_word=8):
    """Derive lookahead and tail requirements from the two centered x2 stages."""
    if input_lanes_per_word < 1:
        raise ValueError("input_lanes_per_word must be positive")

    def stage(supports):
        output = []
        for index, current in enumerate(supports):
            output.append(set(current))
            future = set()
            for position in (index - 1, index, index + 1, index + 2):
                if 0 <= position < len(supports):
                    future.update(supports[position])
            output.append(future)
        return output

    supports = [set((index,)) for index in range(64)]
    supports = stage(stage(supports))
    per_phase = {}
    max_lookahead = 0.0
    for index, support in enumerate(supports):
        phase = index % 4
        lookahead = max(support) - index / 4.0
        per_phase[phase] = max(per_phase.get(phase, 0.0), lookahead)
        max_lookahead = max(max_lookahead, lookahead)
    required_source_samples = int(math.ceil(max_lookahead))
    return {
        "max_future_dependency_source_samples": max_lookahead,
        "required_integer_source_sample_lookahead": required_source_samples,
        "input_word_lanes": int(input_lanes_per_word),
        "additional_input_words_to_lookahead": int(math.ceil(
            required_source_samples / float(input_lanes_per_word))),
        "zero_source_samples_to_flush_at_frame_end": required_source_samples,
        "max_lookahead_by_x4_output_phase_source_samples": [
            per_phase.get(phase, 0.0) for phase in range(4)],
        "interpretation": (
            "Block processing can produce samples at their stated time labels. "
            "A causal stream needs three future 1.75-GHz input samples; with "
            "eight input lanes this crosses one input transaction. Append "
            "three zero samples after an explicit frame end to emit the last "
            "four-times-rate output samples."
        ),
    }
