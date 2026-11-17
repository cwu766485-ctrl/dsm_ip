"""Scalar accumulator-error MASH oracle, separate from frozen x-q1 Golden.

The unsigned EFM residue r obeys q1=x+r_prev-r. Feeding centered r into
Stage 2 gives q1+(1-z^-1)q2=x-(1-z^-1)^2 r2. Constant centering cancels.
"""



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


def pack_fs4(bits):
    result=0
    for lane,(i,q) in enumerate(bits):
        result|=(i^(lane&1))<<(2*lane)
        result|=(q^(1-(lane&1)))<<(2*lane+1)
    return result


def scalar_stages(iq):
    r1=[0,0]; r2=[0,0]; q1=[];q2=[]; residues=[]
    for sample in iq:
        a=[];b=[];rr=[]
        for c in range(2):
            total=r1[c]+int(sample[c])+32768
            a.append(total>>16);r1[c]=total&65535
            rr.append(r1[c]-32768)
            total2=r2[c]+r1[c]
            b.append(total2>>16);r2[c]=total2&65535
        q1.append(a);q2.append(b);residues.append(rr)
    return q1,q2,residues


def corrected_pa_words(iq):
    if len(iq)%32:raise ValueError('Whole Cartesian words required')
    q1,q2,_=scalar_stages(iq)
    raw1=[pack_fs4(q1[n:n+32]) for n in range(0,len(iq),32)]
    raw2=[pack_fs4(q2[n:n+32]) for n in range(0,len(iq),32)]
    reset=0x6666666666666666
    # Exact historical output reset FIFO / alignment contract. No fitted lag.
    aligned1=([0]*34+[reset]*32+raw1)[:len(raw1)]
    aligned2=([reset]*66+raw2)[:len(raw2)]
    prev=(-1,-1); result=[]
    for a,b in zip(aligned1,aligned2):
        p0,p1,_,prev=weighted_encode(a,b,prev)
        result.append((p0,p1))
    return result
