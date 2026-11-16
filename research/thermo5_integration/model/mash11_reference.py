"""Fixed-point reference for the historical 32-lane Cartesian MASH 1-1 RTL."""

from dataclasses import dataclass, field


def _wrap_signed(value, bits):
    mask = (1 << bits) - 1
    value &= mask
    return value - (1 << bits) if value & (1 << (bits - 1)) else value


def _pack_fs4(i_sign, q_sign):
    word = 0
    for lane, (i_bit, q_bit) in enumerate(zip(i_sign, q_sign)):
        word |= (int(bool(i_bit) if lane % 2 == 0 else not i_bit) << (2 * lane))
        word |= (int(not q_bit if lane % 2 == 0 else q_bit) << (2 * lane + 1))
    return word


@dataclass
class FirstOrderState:
    width: int
    channels: int
    accum_i: list = field(init=False)
    accum_q: list = field(init=False)
    feedback_i: list = field(init=False)
    feedback_q: list = field(init=False)

    def __post_init__(self):
        self.accum_i = [[0] * self.channels for _ in range(self.channels)]
        self.accum_q = [[0] * self.channels for _ in range(self.channels)]
        self.feedback_i = [0] * self.channels
        self.feedback_q = [0] * self.channels


def first_order_tick(i_samples, q_samples, state):
    """Advance one registered TIDSM word and return its raw Fs/4 word."""
    channels, width = state.channels, state.width
    if len(i_samples) != channels or len(q_samples) != channels:
        raise ValueError("input vectors must match the configured channel count")

    sign_i = [value < 0 for value in state.feedback_i]
    sign_q = [value < 0 for value in state.feedback_q]
    out_i = [sign_i[lane] ^ (sign_i[lane - 1] if lane else False)
             for lane in range(channels)]
    out_q = [sign_q[lane] ^ (sign_q[lane - 1] if lane else False)
             for lane in range(channels)]
    raw_word = _pack_fs4(out_i, out_q)

    next_a_i = [[0] * channels for _ in range(channels)]
    next_a_q = [[0] * channels for _ in range(channels)]
    input_offset = 1 << (width - 1)
    input_mask = (1 << width) - 1
    for lane in range(channels):
        next_a_i[lane][0] = (int(i_samples[lane]) + input_offset) & input_mask
        next_a_q[lane][0] = (int(q_samples[lane]) + input_offset) & input_mask
    for column in range(1, channels):
        for lane in range(channels):
            next_a_i[lane][column] = state.accum_i[lane][column - 1]
            next_a_q[lane][column] = state.accum_q[lane][column - 1]
        next_a_i[column][column] = _wrap_signed(
            state.accum_i[column - 1][column - 1] +
            state.accum_i[column][column - 1], width + 1)
        next_a_q[column][column] = _wrap_signed(
            state.accum_q[column - 1][column - 1] +
            state.accum_q[column][column - 1], width + 1)

    feedback = (state.feedback_i[-1] & input_mask,
                state.feedback_q[-1] & input_mask)
    state.feedback_i = [
        _wrap_signed(state.accum_i[lane][-1] + feedback[0], width + 1)
        for lane in range(channels)]
    state.feedback_q = [
        _wrap_signed(state.accum_q[lane][-1] + feedback[1], width + 1)
        for lane in range(channels)]
    state.accum_i, state.accum_q = next_a_i, next_a_q
    return raw_word


@dataclass
class Mash11State:
    width: int = 16
    channels: int = 32
    stage1: FirstOrderState = field(init=False)
    stage2: FirstOrderState = field(init=False)
    input_i_delay: list = field(init=False)
    input_q_delay: list = field(init=False)
    stage1_delay: list = field(init=False)
    delay_valid: bool = False
    output_word_index: int = 0

    def __post_init__(self):
        self.stage1 = FirstOrderState(self.width, self.channels)
        self.stage2 = FirstOrderState(self.width, self.channels)
        delay_words = self.channels + 1
        self.input_i_delay = [[0] * self.channels for _ in range(delay_words)]
        self.input_q_delay = [[0] * self.channels for _ in range(delay_words)]
        self.stage1_delay = [0] * delay_words


def mash11_tick(i_samples, q_samples, state):
    """Return the MATLAB/RTL-aligned raw stage pair for one accepted vector."""
    channels, width = state.channels, state.width
    raw1 = first_order_tick(i_samples, q_samples, state.stage1)

    if state.delay_valid:
        residual_i, residual_q = [], []
        for lane in range(channels):
            if lane % 2 == 0:
                qi_bit = (raw1 >> (2 * lane)) & 1
                qq_bit = 1 - ((raw1 >> (2 * lane + 1)) & 1)
            else:
                qi_bit = 1 - ((raw1 >> (2 * lane)) & 1)
                qq_bit = (raw1 >> (2 * lane + 1)) & 1
            qi = (1 << (width - 1)) - 1 if qi_bit else -((1 << (width - 1)) - 1)
            qq = (1 << (width - 1)) - 1 if qq_bit else -((1 << (width - 1)) - 1)
            lo, hi = -(1 << (width - 1)), (1 << (width - 1)) - 1
            residual_i.append(min(hi, max(lo, state.input_i_delay[-1][lane] - qi)))
            residual_q.append(min(hi, max(lo, state.input_q_delay[-1][lane] - qq)))
    else:
        residual_i = [0] * channels
        residual_q = [0] * channels

    raw2 = first_order_tick(residual_i, residual_q, state.stage2)
    stage1_out = state.stage1_delay[-1]
    stage2_out = raw2
    if state.output_word_index == channels + 1:
        stage1_out = 0
        stage2_out = sum(1 << (2 * lane + (1 if lane % 2 == 0 else 0))
                         for lane in range(channels))

    state.input_i_delay = [[int(value) for value in i_samples], *state.input_i_delay[:-1]]
    state.input_q_delay = [[int(value) for value in q_samples], *state.input_q_delay[:-1]]
    state.stage1_delay = [raw1, *state.stage1_delay[:-1]]
    state.delay_valid = True
    state.output_word_index += 1
    return stage1_out, stage2_out


def run_mash11(i_words, q_words, width=16):
    state = Mash11State(width=width, channels=len(i_words[0]))
    raw_pairs = []
    for i_word, q_word in zip(i_words, q_words):
        raw_pairs.append(mash11_tick(i_word, q_word, state))
    return raw_pairs
