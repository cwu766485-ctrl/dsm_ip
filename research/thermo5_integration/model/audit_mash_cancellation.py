#!/usr/bin/env python3
"""Compare captured q1/q2 cancellation with the physical 1:2 PA pair."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np
from audit_mash_qam import rows, unpack_words, decode_fs4, scalar_efm, pack_fs4


def read_iq(records,prefix=''):
    return np.array([[(lambda v:v-65536 if v&32768 else v)((int(r[prefix+k],16)>>(16*l))&65535)
                      for k in ('i_hex','q_hex')] for r in records for l in range(32)],dtype=np.int32)


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    p.add_argument('--correct-residue',action='store_true');args=p.parse_args()
    cap=args.capture;out=args.output;out.mkdir(parents=True,exist_ok=False)
    pairs=rows(cap/'stage_pairs.csv'); pre=rows(cap/'pre_words.csv')
    q1,q2,pa0,pa1=[decode_fs4(unpack_words([int(r[k],16) for r in pairs]))
                    for k in ('q1_hex','q2_hex','pa0_hex','pa1_hex')]
    prev=np.vstack([[-1,-1],q2[:-1]])
    math=q1+q2-prev;physical=pa0+2*pa1
    mismatch=np.argwhere(math!=physical)
    with (out/'cancellation_samples.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['transaction_id','sample','component','q1','q2','delayed_q2','math','pa0','pa1','physical','time_ps','frame_start','frame_end','tail','config_id','epoch'])
        for n in range(len(q1)):
            r=pairs[n//32]
            for c in range(2):
                w.writerow([n//32,n%32,'IQ'[c],q1[n,c],q2[n,c],prev[n,c],math[n,c],pa0[n,c],pa1[n,c],physical[n,c],r['time_ps'],r['frame_start'],r['frame_end'],r['tail'],r['config_id'],r['epoch']])
    # Check exact residual operands. This locates the first mathematical MASH
    # discrepancy without changing the frozen historical bit-true Golden.
    residual=rows(cap/'residual_words.csv');x=read_iq(residual,'x_');actual=read_iq(residual)
    s1raw=unpack_words([int(r['q1_hex'],16) for r in residual]); bipolar=decode_fs4(s1raw)
    historical_diff=x-bipolar*32767
    saturated=int(np.count_nonzero((historical_diff>32767)|(historical_diff < -32768)))
    iq=read_iq(pre)
    # Accumulator residue is computed independently from captured input only.
    r=np.zeros(2,dtype=np.int64); scalar_res=[]
    for sample in iq:
        r=(r+sample+32768)&65535;scalar_res.append(r.copy()-32768)
    expected_res=np.vstack([np.full((32*32,2),-32768),np.array(scalar_res)])[:len(actual)]
    bad_res=np.argwhere(actual!=expected_res)
    independent_q1=decode_fs4(pack_fs4(scalar_efm(iq)))
    delayed_q1_bad=int(np.count_nonzero(q1[66*32:]!=independent_q1[:len(q1)-66*32]))
    stages=rows(cap/'stage2_words.csv')
    second_raw=unpack_words([int(r['raw_hex'],16) for r in stages])
    second_expected=np.r_[pack_fs4(np.zeros((32*32,2),dtype=np.int8)),pack_fs4(scalar_efm(actual))][:len(second_raw)]
    second_bad=int(np.count_nonzero(second_raw!=second_expected))
    first=None
    if len(bad_res):
        n,c=map(int,bad_res[0]);record=residual[n//32]
        first={'transaction_id':n//32,'lane':n%32,'component':'IQ'[c],
               'time_ps':record['time_ps'],'rtl_stage2_input':int(actual[n,c]),
               'independent_accumulator_residue_centered':int(expected_res[n,c]),
               'delayed_x':int(x[n,c]),'q1':int(bipolar[n,c])}
    result={'pa_reconstruction_total_mismatch':len(mismatch),
            'pa_reconstruction_first_mismatch':None if not len(mismatch) else mismatch[0].tolist(),
            'q1_delayed_66_words_scalar_mismatches':delayed_q1_bad,
            'stage2_scalar_mismatches':second_bad,'residual_accumulator_mismatches':len(bad_res),
            'first_residual_discrepancy':first,'hypothetical_x_minus_q1_saturations':saturated,
            'metadata_mismatches':sum(int(r['config_id'])!=66 or int(r['epoch'])!=1 or
                int(r['tail'])!=0 or int(r['frame_start'])!=(n==0) or
                int(r['frame_end'])!=(n==len(pairs)-1) for n,r in enumerate(pairs)),
            'correct_residue_requested':args.correct_residue}
    (out/'cancellation_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result,indent=2),flush=True)
    assert not len(mismatch) and not delayed_q1_bad and not second_bad and not result['metadata_mismatches']
    if args.correct_residue:assert not len(bad_res)


if __name__=='__main__':main()
