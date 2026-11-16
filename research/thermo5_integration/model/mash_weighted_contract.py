"""Independent fixed-point MASH cancellation and weighted PA contract."""

Q = 1 << 15


def decode_fs4(word, lane, component):
    bit = (word >> (2 * lane + component)) & 1
    if component == 0:
        return 1 if bool(bit) == (lane % 2 == 0) else -1
    return -1 if bool(bit) == (lane % 2 == 0) else 1


def encode_fs4(positive, lane, component):
    if component == 0:
        return int(bool(positive) if lane % 2 == 0 else not positive)
    return int(not positive if lane % 2 == 0 else positive)


def weighted_encode(stage1, stage2, previous_q2=(-1, -1), channels=32):
    """Return PA0/PA1 packed words and decoded cancellation samples."""
    if not isinstance(stage1, int) or not isinstance(stage2, int):
        raise TypeError("stage words must be packed integers")
    prev_i, prev_q = previous_q2
    pa0 = pa1 = 0
    levels = []
    for lane in range(channels):
        q1_i, q1_q = decode_fs4(stage1, lane, 0), decode_fs4(stage1, lane, 1)
        q2_i, q2_q = decode_fs4(stage2, lane, 0), decode_fs4(stage2, lane, 1)
        y_i, y_q = q1_i + q2_i - prev_i, q1_q + q2_q - prev_q
        if y_i not in (-3, -1, 1, 3) or y_q not in (-3, -1, 1, 3):
            raise AssertionError("MASH cancellation left odd bipolar range")
        for component, y in ((0, y_i), (1, y_q)):
            b0 = y in (-1, 3)
            b1 = y in (1, 3)
            if encode_fs4(b0, lane, component):
                pa0 |= 1 << (2 * lane + component)
            if encode_fs4(b1, lane, component):
                pa1 |= 1 << (2 * lane + component)
        levels.append((y_i, y_q))
        prev_i, prev_q = q2_i, q2_q
    return pa0, pa1, levels, (prev_i, prev_q)


def weighted_decode(pa0, pa1, channels=32):
    levels = []
    for lane in range(channels):
        values = []
        for component in (0, 1):
            b0 = decode_fs4(pa0, lane, component)
            b1 = decode_fs4(pa1, lane, component)
            values.append(b0 + 2 * b1)
        levels.append(tuple(values))
    return levels
