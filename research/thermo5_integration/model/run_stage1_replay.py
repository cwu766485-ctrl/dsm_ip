#!/usr/bin/env python3
"""Prove every captured Cartesian input sample against scalar Stage 1."""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import subprocess
import numpy as np
from audit_mash_qam import ROOT, rows, scalar_efm, pack_fs4, unpack_words


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--capture',type=Path,required=True)
    ap.add_argument('--output',type=Path,required=True)
    args=ap.parse_args(); cap=args.capture.resolve();out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    pre=rows(cap/'pre_words.csv')
    iq=np.array([[(lambda v:v-65536 if v&32768 else v)((int(r[k],16)>>(16*l))&65535)
                  for k in ('i_hex','q_hex')] for r in pre for l in range(32)],dtype=np.int32)
    expected=np.r_[pack_fs4(np.zeros((32*32,2),dtype=np.int8)),pack_fs4(scalar_efm(iq))]
    files=['rtl/gt/gt_tx_user_bridge.sv','rtl/gt/gt_tx_raw64_boundary.sv',
           'research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
           'research/thermo5_integration/verif/tb/tb_stage1_scalar_replay.sv']
    summary={'input_samples':len(iq),'stage1_delay_words':32,'source_sha256':{
        f:hashlib.sha256((ROOT/f).read_bytes()).hexdigest() for f in files},'runs':{}}
    for bubbles in (0,1):
        run=out/('bubbles'+str(bubbles));run.mkdir()
        for component in ('i','q'):
            (run/('stage1_replay_'+component+'.mem')).write_text(''.join(r[component+'_hex']+'\n' for r in pre))
        top='tb_stage1_scalar_replay'
        commands=[['iverilog','-g2012','-s',top,'-P'+top+'.WORDS='+str(len(pre)),
                   '-P'+top+'.BUBBLES='+str(bubbles),'-o',str(run/'stage1.vvp'),
                   *[str(ROOT/f) for f in files]],['vvp',str(run/'stage1.vvp')]]
        for j,command in enumerate(commands):
            with (run/('compile.log' if j==0 else 'simulation.log')).open('w') as log:
                subprocess.run(command,cwd=run,stdout=log,stderr=subprocess.STDOUT,check=True)
        captured=rows(run/'stage1_replay.csv')
        actual=unpack_words([int(r['raw_hex'],16) for r in captured])
        assert len(actual)==len(expected)
        bad=np.flatnonzero(actual!=expected)
        with (run/'stage1_bittrue.csv').open('w') as f:
            w=csv.writer(f);w.writerow(['source_sample','component','output_word','raw_bit','rtl','golden','time_ps','mismatch'])
            for n,(a,b) in enumerate(zip(actual,expected)):
                w.writerow([n//2-32*32,'IQ'[n%2],n//64,n%64,int(a),int(b),captured[n//64]['time_ps'],int(a!=b)])
        integrated=unpack_words([int(r['raw_hex'],16) for r in rows(cap/'stage1_words.csv')])
        prefix_bad=int(np.count_nonzero(actual[:len(integrated)]!=integrated))
        summary['runs'][str(bubbles)]={'words':len(captured),'input_samples_compared':len(iq),
            'bits_compared_including_reset_fill':len(actual),'total_mismatch':len(bad),
            'first_mismatch':int(bad[0]) if len(bad) else None,
            'integrated_prefix_mismatches':prefix_bad,'flush_zero_words':32,'commands':commands,
            'vcd_sha256':hashlib.sha256((run/'stage1_replay.vcd').read_bytes()).hexdigest()}
        assert not len(bad) and not prefix_bad,summary
        print('STAGE1_SCALAR_PASS bubbles=%d samples=%d bits=%d'%(bubbles,len(iq),len(actual)),flush=True)
    (out/'stage1_complete_summary.json').write_text(json.dumps(summary,indent=2)+'\n')


if __name__=='__main__':main()
