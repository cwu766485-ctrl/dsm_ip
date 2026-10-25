"""Pure-Python fixed-point reference for the frozen thermo5 digital SKU.

The model follows the identity-DPD, two-x2-interpolator, four-plane Cartesian
TID chain in MATLAB's gen_tid32_thermo5_frontend_bittrue_vectors.m. It uses
plain Python integers and emits the same hexadecimal .mem format.
"""

import random
from pathlib import Path


LANES_IN = 8
DATA_WIDTH = 16
Q14_ONE = 1 << 14
INTERP_COEFFS_Q14 = {
    2: (8192, 8192),
    3: (6144, 12288, -2048),
    4: (5120, 15360, -5120, 1024),
}
CENTERED_CUBIC_COEFFS_Q14 = (-1024, 9216, 9216, -1024)


def nonlinear_test_dpd_coefficients():
    """Two-tap polynomial test image with a nonlinear memory tap."""
    return {
        "c1_re": (0x4000, 0x0400, 0, 0),
        "c1_im": (0, 0, 0, 0),
        "c3_re": (0x0800, 0x0200, 0, 0),
        "c3_im": (0, 0, 0, 0),
        "c5_re": (0, 0, 0, 0),
        "c5_im": (0, 0, 0, 0),
    }


def wrap_signed(value, bits):
    modulus = 1 << bits
    return ((int(value) + (modulus >> 1)) % modulus) - (modulus >> 1)


def saturate_signed(value, bits):
    low = -(1 << (bits - 1))
    high = (1 << (bits - 1)) - 1
    return min(max(int(value), low), high)


def round_shift_symmetric(value, shift):
    """Round to nearest, with exact half cases away from zero (MATLAB/RTL)."""
    if shift <= 0:
        return int(value) << (-shift)
    bias = 1 << (shift - 1)
    if value >= 0:
        return (int(value) + bias) >> shift
    return -(((-int(value)) + bias) >> shift)


def apply_q14_gain(i_values, q_values, gain):
    if len(i_values) != len(q_values):
        raise ValueError("I and Q vectors must have equal lengths")
    return ([saturate_signed(round_shift_symmetric(int(x) * int(gain), 14), 16)
             for x in i_values],
            [saturate_signed(round_shift_symmetric(int(x) * int(gain), 14), 16)
             for x in q_values])


def interp_x2_vector(i_values, q_values, history_i, history_q, taps):
    """Match one MATLAB/RTL vector transaction; histories are newest first."""
    if taps not in INTERP_COEFFS_Q14:
        raise ValueError("taps must be 2, 3, or 4")
    if len(i_values) != len(q_values):
        raise ValueError("I and Q vectors must have equal lengths")
    if len(history_i) != taps - 1 or len(history_q) != taps - 1:
        raise ValueError("history length must equal taps - 1")

    coeffs = INTERP_COEFFS_Q14[taps]
    out_i = []
    out_q = []
    lanes = len(i_values)
    for lane in range(lanes):
        out_i.append(int(i_values[lane]))
        out_q.append(int(q_values[lane]))
        acc_i = 0
        acc_q = 0
        for tap, coeff in enumerate(coeffs):
            if tap <= lane:
                sample_i = int(i_values[lane - tap])
                sample_q = int(q_values[lane - tap])
            else:
                sample_i = int(history_i[tap - lane - 1])
                sample_q = int(history_q[tap - lane - 1])
            acc_i += sample_i * coeff
            acc_q += sample_q * coeff
        out_i.append(saturate_signed(round_shift_symmetric(acc_i, 14), 16))
        out_q.append(saturate_signed(round_shift_symmetric(acc_q, 14), 16))

    history_len = taps - 1
    keep_old = max(0, history_len - len(i_values))
    next_i = list(reversed([int(x) for x in i_values[-history_len:]]))
    next_q = list(reversed([int(x) for x in q_values[-history_len:]]))
    next_i.extend(int(x) for x in history_i[:keep_old])
    next_q.extend(int(x) for x in history_q[:keep_old])
    return out_i, out_q, next_i, next_q


def _interp_x2_centered_pairs(samples):
    """Block-mode centered cubic x2 filter with zero extension at each edge."""
    out = []
    count = len(samples)
    for index, current in enumerate(samples):
        neighborhood = [samples[position] if 0 <= position < count else (0, 0)
                        for position in (index - 1, index, index + 1, index + 2)]
        accum_i = sum(int(sample[0]) * coeff for sample, coeff in
                      zip(neighborhood, CENTERED_CUBIC_COEFFS_Q14))
        accum_q = sum(int(sample[1]) * coeff for sample, coeff in
                      zip(neighborhood, CENTERED_CUBIC_COEFFS_Q14))
        odd = (saturate_signed(round_shift_symmetric(accum_i, 14), 16),
               saturate_signed(round_shift_symmetric(accum_q, 14), 16))
        out.extend((current, odd))
    return out


def _centered_cubic_midpoint(xm1, x0, xp1, xp2):
    accum_i = sum(int(sample[0]) * coeff for sample, coeff in
                  zip((xm1, x0, xp1, xp2), CENTERED_CUBIC_COEFFS_Q14))
    accum_q = sum(int(sample[1]) * coeff for sample, coeff in
                  zip((xm1, x0, xp1, xp2), CENTERED_CUBIC_COEFFS_Q14))
    return (saturate_signed(round_shift_symmetric(accum_i, 14), 16),
            saturate_signed(round_shift_symmetric(accum_q, 14), 16))


def _centered_cubic_x2_with_future(samples, future=()):
    """Interpolate one complete frame, using explicit following samples."""
    zero = (0, 0)
    output = []
    for index, current in enumerate(samples):
        xm1 = samples[index - 1] if index else zero
        xp1 = (samples[index + 1] if index + 1 < len(samples) else
               future[0] if len(future) > 0 else zero)
        xp2 = (samples[index + 2] if index + 2 < len(samples) else
               future[index + 2 - len(samples)]
               if index + 2 - len(samples) < len(future) else zero)
        output.extend((current, _centered_cubic_midpoint(xm1, current, xp1, xp2)))
    return output


def apply_memory_polynomial(samples, coefficients, active_taps=None, history=()):
    """Apply the RTL's scalar equivalent memory-polynomial DPD.

    Coefficients are signed Q2.14 lists keyed by ``c1_re``, ``c1_im``,
    ``c3_re``, ``c3_im``, ``c5_re`` and ``c5_im``. Tap zero is the current
    sample; later taps use prior samples. RTL truncation is arithmetic shift
    (floor for negative values), followed by signed-16 saturation.
    """
    names = ("c1_re", "c1_im", "c3_re", "c3_im", "c5_re", "c5_im")
    coeff = {name: tuple(int(value) for value in coefficients.get(name, ()))
             for name in names}
    lengths = {len(values) for values in coeff.values()}
    if len(lengths) != 1 or not lengths or next(iter(lengths)) < 1:
        raise ValueError("all coefficient arrays must have the same nonzero length")
    max_taps = next(iter(lengths))
    taps = max_taps if active_taps is None else int(active_taps)
    if not 1 <= taps <= max_taps:
        raise ValueError("active_taps must be in [1, len(coefficients)]")
    prior = [tuple(map(int, value)) for value in history[:max_taps - 1]]
    prior.extend([(0, 0)] * (max_taps - 1 - len(prior)))
    output = []
    saturation_count = 0

    for current in samples:
        current = tuple(map(int, current))
        gain_re_sum = 0
        gain_im_sum = 0
        for tap in range(taps):
            sample = current if tap == 0 else (
                prior[tap - 1] if tap - 1 < len(prior) else (0, 0))
            i_value, q_value = sample
            power = (i_value * i_value + q_value * q_value) >> 15
            power4 = (power * power) >> 15
            gain_re = (coeff["c1_re"][tap] +
                       ((coeff["c3_re"][tap] * power) >> 15) +
                       ((coeff["c5_re"][tap] * power4) >> 15))
            gain_im = (coeff["c1_im"][tap] +
                       ((coeff["c3_im"][tap] * power) >> 15) +
                       ((coeff["c5_im"][tap] * power4) >> 15))
            gain_re_sum += (i_value * gain_re - q_value * gain_im) >> 14
            gain_im_sum += (i_value * gain_im + q_value * gain_re) >> 14

        low, high = -(1 << 15), (1 << 15) - 1
        clipped_i = min(max(gain_re_sum, low), high)
        clipped_q = min(max(gain_im_sum, low), high)
        saturation_count += int(clipped_i != gain_re_sum or clipped_q != gain_im_sum)
        output.append((clipped_i, clipped_q))
        if max_taps > 1:
            prior = [current] + prior[:max_taps - 2]

    return output, prior, saturation_count


def interpolate_centered_cubic_x4(samples):
    """Cascade two centered cubic x2 stages and crop to four outputs/input."""
    count = len(samples)
    if count == 0:
        return []
    # Three source zeros cover the cascade's largest future dependency. They
    # are used only to calculate frame-tail outputs and are cropped afterward.
    padded = list(samples) + [(0, 0)] * 3
    stage1 = _interp_x2_centered_pairs(padded)
    stage2 = _interp_x2_centered_pairs(stage1)
    return stage2[:4 * count]


def _new_tid_branch(lanes):
    return {
        "a_i": [[0] * lanes for _ in range(lanes)],
        "a_q": [[0] * lanes for _ in range(lanes)],
        "v_i": [0] * lanes,
        "v_q": [0] * lanes,
    }


def _tid_branch_step(i_values, q_values, state, width, offset):
    lanes = len(i_values)
    low = -(1 << (width - 1))
    high = (1 << (width - 1)) - 1
    biased_i = [min(max(int(x) + offset, low), high) for x in i_values]
    biased_q = [min(max(int(x) + offset, low), high) for x in q_values]

    msb_i = [value < 0 for value in state["v_i"]]
    msb_q = [value < 0 for value in state["v_q"]]
    yi = [msb_i[0]] + [msb_i[k] != msb_i[k - 1] for k in range(1, lanes)]
    yq = [msb_q[0]] + [msb_q[k] != msb_q[k - 1] for k in range(1, lanes)]
    word = 0
    for lane in range(lanes):
        if lane % 2 == 0:
            i_bit, q_bit = yi[lane], not yq[lane]
        else:
            i_bit, q_bit = not yi[lane], yq[lane]
        if i_bit:
            word |= 1 << (2 * lane)
        if q_bit:
            word |= 1 << (2 * lane + 1)

    old_a_i = state["a_i"]
    old_a_q = state["a_q"]
    next_a_i = [[0] * lanes for _ in range(lanes)]
    next_a_q = [[0] * lanes for _ in range(lanes)]
    modulus = 1 << width
    for row in range(lanes):
        next_a_i[row][0] = (biased_i[row] + (1 << (width - 1))) % modulus
        next_a_q[row][0] = (biased_q[row] + (1 << (width - 1))) % modulus
    for col in range(1, lanes):
        for row in range(lanes):
            next_a_i[row][col] = old_a_i[row][col - 1]
            next_a_q[row][col] = old_a_q[row][col - 1]
        next_a_i[col][col] = wrap_signed(
            old_a_i[col - 1][col - 1] + old_a_i[col][col - 1], width + 1)
        next_a_q[col][col] = wrap_signed(
            old_a_q[col - 1][col - 1] + old_a_q[col][col - 1], width + 1)

    feedback_i = state["v_i"][-1] % modulus
    feedback_q = state["v_q"][-1] % modulus
    next_v_i = [wrap_signed(old_a_i[row][-1] + feedback_i, width + 1)
                for row in range(lanes)]
    next_v_q = [wrap_signed(old_a_q[row][-1] + feedback_q, width + 1)
                for row in range(lanes)]
    state["a_i"] = next_a_i
    state["a_q"] = next_a_q
    state["v_i"] = next_v_i
    state["v_q"] = next_v_q
    return word


def tid_word(i_values, q_values, states, width=16, step=7168):
    """Return one four-plane 64-bit word and advance four pipelined TID branches."""
    if len(i_values) != len(q_values) or len(i_values) < 2 or len(i_values) % 2:
        raise ValueError("TID requires equal I/Q vectors with even length >= 2")
    lanes = len(i_values)
    if states is None:
        states = [_new_tid_branch(lanes) for _ in range(4)]
    if len(states) != 4:
        raise ValueError("TID state must contain four branches")
    offsets = (3 * int(step), int(step), -int(step), -3 * int(step))
    words = [_tid_branch_step(i_values, q_values, states[b], width, offsets[b])
             for b in range(4)]
    return words, states


def _ef2_component(samples, state, width, offset):
    """Run one fixed-point EF2 component and return bipolar quantizer bits."""
    input_low = -(1 << (width - 1))
    input_high = (1 << (width - 1)) - 1
    state_width = width + 4
    state_low = -(1 << (state_width - 1))
    state_high = (1 << (state_width - 1)) - 1
    one = 1 << (width - 1)
    e1, e2 = state
    output = []
    input_saturations = 0
    state_saturations = 0
    max_abs_u = 0
    max_abs_state = max(abs(e1), abs(e2))
    for sample in samples:
        raw = int(sample) + int(offset)
        x = min(max(raw, input_low), input_high)
        input_saturations += int(x != raw)
        u = x + (2 * e1) - e2
        positive = u > 0
        y = one if positive else -one
        error_raw = u - y
        error = min(max(error_raw, state_low), state_high)
        state_saturations += int(error != error_raw)
        output.append(1 if positive else -1)
        e2, e1 = e1, error
        max_abs_u = max(max_abs_u, abs(u))
        max_abs_state = max(max_abs_state, abs(e1), abs(e2))
    state[0], state[1] = e1, e2
    return output, {
        "input_saturation_samples": input_saturations,
        "state_saturation_samples": state_saturations,
        "max_abs_quantizer_input_lsb": max_abs_u,
        "max_abs_error_state_lsb": max_abs_state,
    }


def tid_word_ef2(i_values, q_values, states=None, width=16, step=5120):
    """Return a four-plane word using saturated fixed-point second-order EF.

    State values are Q(width-1) signed integers clamped to width+4 bits.
    Each branch uses ``u=x+2e1-e2`` and ``e=u-sign(u)``; the initial states
    are zero. The branch offsets and Fs/4 packing match ``tid_word``.
    """
    if len(i_values) != len(q_values) or len(i_values) < 2 or len(i_values) % 2:
        raise ValueError("TID requires equal I/Q vectors with even length >= 2")
    if states is None:
        states = [{"i": [0, 0], "q": [0, 0]} for _ in range(4)]
    if len(states) != 4:
        raise ValueError("TID state must contain four branches")
    offsets = (3 * int(step), int(step), -int(step), -3 * int(step))
    plane_words = []
    branch_stats = []
    for branch, offset in enumerate(offsets):
        i_bits, i_stats = _ef2_component(i_values, states[branch]["i"], width, offset)
        q_bits, q_stats = _ef2_component(q_values, states[branch]["q"], width, offset)
        word = 0
        for lane, (i_bit, q_bit) in enumerate(zip(i_bits, q_bits)):
            if lane % 2 == 0:
                bit_i, bit_q = i_bit > 0, q_bit < 0
            else:
                bit_i, bit_q = i_bit < 0, q_bit > 0
            if bit_i:
                word |= 1 << (2 * lane)
            if bit_q:
                word |= 1 << (2 * lane + 1)
        plane_words.append(word)
        branch_stats.append({"branch": branch, "i": i_stats, "q": q_stats})
    return plane_words, states, branch_stats


def run_frozen_frontend(i_words, q_words, frame_starts, frame_gains,
                        interp_taps=2, step=7168, tidsm_order=1):
    """Model gain, two x2 stages, identity DPD, and the four TID code planes."""
    count = len(i_words)
    if count != len(q_words) or count != len(frame_starts) or count != len(frame_gains):
        raise ValueError("I/Q and frame metadata word counts must match")
    if interp_taps not in INTERP_COEFFS_Q14:
        raise ValueError("interp_taps must be 2, 3, or 4")
    if tidsm_order not in (1, 2):
        raise ValueError("tidsm_order must be 1 or 2")
    for i_word, q_word in zip(i_words, q_words):
        if len(i_word) != LANES_IN or len(q_word) != LANES_IN:
            raise ValueError("each source word must contain eight I and Q samples")

    h1_i = [0] * (interp_taps - 1)
    h1_q = [0] * (interp_taps - 1)
    h2_i = [0] * (interp_taps - 1)
    h2_q = [0] * (interp_taps - 1)
    states = None
    active_gain = Q14_ONE
    raw_words = []
    for index in range(count):
        if frame_starts[index]:
            active_gain = int(frame_gains[index])
        gain_i, gain_q = apply_q14_gain(i_words[index], q_words[index], active_gain)
        x1_i, x1_q, h1_i, h1_q = interp_x2_vector(
            gain_i, gain_q, h1_i, h1_q, interp_taps)
        # The frozen SKU's programmable DPD is configured to exact Q2.14 unity.
        x2_i, x2_q, h2_i, h2_q = interp_x2_vector(
            x1_i, x1_q, h2_i, h2_q, interp_taps)
        if tidsm_order == 1:
            raw, states = tid_word(x2_i, x2_q, states, width=16, step=step)
        else:
            raw, states, _ = tid_word_ef2(x2_i, x2_q, states, width=16, step=step)
        raw_words.append(raw)

    if tidsm_order == 2:
        # The EF2 RTL emits one result per accepted vector; its output boundary
        # adds latency but does not discard the first transaction.
        output_words = raw_words
    else:
        if count:
            flush, states = tid_word([0] * 32, [0] * 32, states, width=16, step=step)
        else:
            flush = [0, 0, 0, 0]
        # MATLAB drops the first pipelined TID result, then appends one drain word.
        output_words = raw_words[1:] + [flush] if raw_words else []
    return output_words


def run_centered_cubic_frontend(i_words, q_words, frame_starts, frame_gains,
                                step=7168, dpd_coefficients=None,
                                dpd_active_taps=None, tidsm_order=1):
    """Generate four-plane oracle words for the streaming centered-cubic SKU.

    Each frame is zero-extended independently for the two centered FIR stages.
    The bit-true DPD in the UVM SKU is configured to identity; TID state remains
    continuous across frame boundaries, as in the RTL.
    """
    count = len(i_words)
    if count != len(q_words) or count != len(frame_starts) or count != len(frame_gains):
        raise ValueError("I/Q and frame metadata word counts must match")
    if tidsm_order not in (1, 2):
        raise ValueError("tidsm_order must be 1 or 2")
    if not count:
        return []
    for i_word, q_word in zip(i_words, q_words):
        if len(i_word) != LANES_IN or len(q_word) != LANES_IN:
            raise ValueError("each source word must contain eight I and Q samples")

    starts = [index for index, flag in enumerate(frame_starts) if flag]
    if not starts or starts[0] != 0:
        starts.insert(0, 0)
    if any(index % 7 for index in starts):
        raise ValueError("centered-cubic frame starts must align to 7-word TID quanta")
    boundaries = starts + [count]
    states = None
    dpd_history = ()
    raw_words = []
    for frame_index in range(len(starts)):
        first_word, end_word = boundaries[frame_index:frame_index + 2]
        if (end_word - first_word) % 7:
            raise ValueError("centered-cubic frame lengths must be a multiple of 7 words")
        gain = int(frame_gains[first_word])
        frame_i = [value for word in i_words[first_word:end_word] for value in word]
        frame_q = [value for word in q_words[first_word:end_word] for value in word]
        gained_i, gained_q = apply_q14_gain(frame_i, frame_q, gain)
        source = list(zip(gained_i, gained_q))
        stage1_real = _centered_cubic_x2_with_future(source)
        tail_mid = _centered_cubic_midpoint(source[-1], (0, 0), (0, 0), (0, 0))
        tail = [(0, 0)] * 16
        tail[1] = tail_mid
        if dpd_coefficients is None:
            dpd_frame = stage1_real
            dpd_tail = tail
        else:
            # The first streaming interpolator emits one 16-lane lookahead
            # vector after TLAST. Only its lane 1 is nonzero; the DPD sees it
            # and its own memory history before the second interpolator uses
            # the vector to reconstruct the final real samples.
            dpd_frame, dpd_history, _ = apply_memory_polynomial(
                stage1_real + tail, dpd_coefficients,
                active_taps=dpd_active_taps, history=dpd_history)
            dpd_tail = dpd_frame[len(stage1_real):]
            dpd_frame = dpd_frame[:len(stage1_real)]

        interpolated = _centered_cubic_x2_with_future(dpd_frame, dpd_tail)
        if len(interpolated) % 32:
            raise ValueError("interpolated centered frame must contain full 32-lane TID words")
        for first in range(0, len(interpolated), 32):
            block = interpolated[first:first + 32]
            block_i = [sample[0] for sample in block]
            block_q = [sample[1] for sample in block]
            if tidsm_order == 1:
                word, states = tid_word(block_i, block_q, states, width=16, step=step)
            else:
                word, states, _ = tid_word_ef2(
                    block_i, block_q, states, width=16, step=step)
            raw_words.append(word)

    if tidsm_order == 2:
        return raw_words
    flush, states = tid_word([0] * 32, [0] * 32, states, width=16, step=step)
    return raw_words[1:] + [flush]


def _to_signed16(value):
    value = int(value) & 0xffff
    return value - 0x10000 if value & 0x8000 else value


def _read_mem(path):
    with open(path, "r") as stream:
        return [_to_signed16(int(line.strip(), 16)) for line in stream if line.strip()]


def read_source_vectors(vector_dir, width=LANES_IN):
    root = Path(vector_dir)
    i_samples = _read_mem(root / "tid32_thermo5_frontend_i.mem")
    q_samples = _read_mem(root / "tid32_thermo5_frontend_q.mem")
    starts = _read_mem(root / "tid32_thermo5_frontend_frame_start.mem")
    gains = _read_mem(root / "tid32_thermo5_frontend_frame_gain.mem")
    if len(i_samples) != len(q_samples) or len(i_samples) % width:
        raise ValueError("invalid source I/Q vector length")
    count = len(i_samples) // width
    if len(starts) != count or len(gains) != count:
        raise ValueError("frame metadata length does not match source words")
    i_words = [i_samples[n * width:(n + 1) * width] for n in range(count)]
    q_words = [q_samples[n * width:(n + 1) * width] for n in range(count)]
    return i_words, q_words, starts, gains


def write_vectors(output_dir, i_words, q_words, frame_starts, frame_gains, pa_words):
    root = Path(output_dir)
    root.mkdir(parents=True, exist_ok=True)
    if len(i_words) != len(q_words) or len(i_words) != len(frame_starts):
        raise ValueError("source words and metadata length must match")
    if len(i_words) != len(frame_gains) or len(pa_words) != len(i_words):
        raise ValueError("output and source word counts must match")

    def write_samples(name, values):
        with open(root / name, "w") as stream:
            for value in values:
                stream.write("%04X\n" % (int(value) & 0xffff))

    write_samples("tid32_thermo5_frontend_i.mem", [x for word in i_words for x in word])
    write_samples("tid32_thermo5_frontend_q.mem", [x for word in q_words for x in word])
    write_samples("tid32_thermo5_frontend_frame_start.mem", frame_starts)
    write_samples("tid32_thermo5_frontend_frame_gain.mem", frame_gains)
    for branch in range(4):
        with open(root / ("tid32_thermo5_frontend_pa%d.mem" % branch), "w") as stream:
            for word in pa_words:
                stream.write("%016X\n" % int(word[branch]))


def generate_source_vectors(words=56, seed=20260930, profile="random",
                            frame_start_words=(1, 15, 36),
                            frame_gains=(16384, 14336, 12288)):
    """Generate deterministic Python-native stimulus with the MATLAB profiles."""
    if words < 12:
        raise ValueError("at least 12 words are required")
    if profile not in ("random", "extreme", "range_stress"):
        raise ValueError("profile must be random, extreme, or range_stress")
    rng = random.Random(seed)
    i_words = [[rng.randint(-12000, 12000) for _ in range(LANES_IN)]
               for _ in range(words)]
    q_words = [[rng.randint(-12000, 12000) for _ in range(LANES_IN)]
               for _ in range(words)]
    extreme_i = [-32768, -24000, -1, 0, 1, 12000, 24000, 32767]
    extreme_q = [32767, 24000, 1, 0, -1, -12000, -24000, -32768]
    if profile == "extreme":
        for word in range(words):
            i_words[word] = [extreme_i[(lane - word) % LANES_IN]
                             for lane in range(LANES_IN)]
            q_words[word] = [extreme_q[(lane - 3 * word) % LANES_IN]
                             for lane in range(LANES_IN)]
    elif profile == "range_stress":
        for word in range(words):
            i_value, q_value = ((-32768, 32767) if (word // 4) % 2 == 0
                                else (32767, -32768))
            i_words[word] = [i_value] * LANES_IN
            q_words[word] = [q_value] * LANES_IN
    i_words[0] = extreme_i[:]
    q_words[0] = extreme_q[:]

    starts = [0] * words
    gains = [Q14_ONE] * words
    selected_gains = list(frame_gains)
    if not selected_gains or any(value < -32768 or value > 32767 for value in selected_gains):
        raise ValueError("frame gains must be signed 16-bit values")
    for ordinal, one_based in enumerate(frame_start_words):
        if one_based < 1 or one_based > words:
            raise ValueError("frame start is outside the generated word range")
        index = one_based - 1
        starts[index] = 1
        gains[index] = selected_gains[ordinal % len(selected_gains)]
    if profile == "range_stress":
        gains = [Q14_ONE] * words
    return i_words, q_words, starts, gains
