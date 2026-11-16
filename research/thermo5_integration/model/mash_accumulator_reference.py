"""Scalar accumulator-error MASH oracle, separate from frozen x-q1 Golden.

The unsigned EFM residue r obeys q1=x+r_prev-r. Feeding centered r into
Stage 2 gives q1+(1-z^-1)q2=x-(1-z^-1)^2 r2. Constant centering cancels.
"""
from mash_weighted_contract import weighted_encode


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
