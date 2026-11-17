#!/usr/bin/env python3
"""Prepare legal runtime-product QAM packets; evaluate actual weighted PA captures.

Only trailing zero guard padding changes from the preserved 3004-beat test:
packets must contain whole 32-AXIS-beat quanta. No QAM sample is changed.
"""
import argparse
import hashlib
import json
import math
from pathlib import Path
from benchmark_thermo5_tid_receiver import (make_256qam_ofdm,GUARD_SAMPLES,RAW_FS_HZ,
    RX_FIR_TAPS,_blackman_lowpass,_linear_fir_decimate,demodulate_metrics)
from dsm_refmodel.thermo5 import write_vectors

SOURCE_OFFSET=528  # 66 accepted 32-lane words / four frontend samples per source sample.


def prepare(out,seed,symbols):
    out.mkdir(parents=True,exist_ok=False)
    s=make_256qam_ofdm(seed,symbols=symbols,rms_drive=0.09)
    data=s['source_iq'][GUARD_SAMPLES:GUARD_SAMPLES+s['data_samples']]
    guard=46*56
    original=[(0,0)]*guard+data+[(0,0)]*((-len(data))%56+guard)
    padding=(-len(original))%(32*14)
    iq=original+[(0,0)]*padding
    iw=[[i for i,q in iq[n:n+8]] for n in range(0,len(iq),8)]
    qw=[[q for i,q in iq[n:n+8]] for n in range(0,len(iq),8)]
    write_vectors(out/'input',iw,qw,[1]+[0]*(len(iw)-1),[16384]*len(iw),[(0,0,0,0)]*len(iw))
    meta={k:v for k,v in s.items() if k not in ('source_iq','qam_rows')}
    meta.update(seed=seed,symbols=symbols,data_start=guard,axis_beats=len(iq)//14,
                words=len(iw),product_trailing_zero_padding=padding,
                qam_rows=[[[v.real,v.imag] for v in row] for row in s['qam_rows']])
    (out/'stimulus.json').write_text(json.dumps(meta,indent=2)+'\n')
    print(json.dumps({'words':len(iw),'beats':len(iq)//14,'padding':padding}))


def evaluate(prepared,capture,out):
    m=json.loads((prepared/'stimulus.json').read_text())
    paths=[capture/('phase1_arch2_pa%d.mem'%p) for p in range(2)]
    pa=[[int(s,16) for s in path.read_text().split()] for path in paths]
    if any(len(p)!=m['words'] for p in pa):raise ValueError('Incomplete RTL PA capture')
    rf=[(1 if (a>>b)&1 else -1)+2*(1 if (c>>b)&1 else -1) for a,c in zip(*pa) for b in range(64)]
    phase=(1+0j,-1j,-1+0j,1j)
    ddc=[2*v*phase[n&3] for n,v in enumerate(rf)]
    bb7=_linear_fir_decimate(ddc,_blackman_lowpass(0.75*250e6,RAW_FS_HZ,RX_FIR_TAPS),2,phase=0)
    bb=_linear_fir_decimate(bb7,_blackman_lowpass(0.75*250e6,RAW_FS_HZ/2,RX_FIR_TAPS),4,phase=0)
    m['qam_rows']=[[complex(*v) for v in row] for row in m['qam_rows']]
    m['data_start']+=SOURCE_OFFSET
    result=demodulate_metrics(bb,m)
    result.update(seed=m['seed'],symbols=m['symbols'],words=m['words'],fft_window_source_offset=SOURCE_OFFSET,
                  source='canonical runtime RTL PA captures, phase1 MASH',
                  pa_sha256={p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in paths})
    result['pass']=result['evm_percent']<=3.5 and result['sndr_db']>=29.12
    out.write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
    if not result['pass']:raise SystemExit('QAM acceptance failed')


def main():
    a=argparse.ArgumentParser(description=__doc__);sp=a.add_subparsers(dest='mode',required=True)
    p=sp.add_parser('prepare');p.add_argument('--out',type=Path,required=True);p.add_argument('--seed',type=int,default=281001);p.add_argument('--symbols',type=int,default=8)
    p=sp.add_parser('evaluate');p.add_argument('--prepared',type=Path,required=True);p.add_argument('--capture',type=Path,required=True);p.add_argument('--out',type=Path,required=True)
    v=a.parse_args()
    if v.mode=='prepare':prepare(v.out,v.seed,v.symbols)
    else:evaluate(v.prepared,v.capture,v.out)

if __name__=='__main__':main()
