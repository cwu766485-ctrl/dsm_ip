#!/usr/bin/env python3
"""Research-only EF1 step sweep; matched frozen stimulus, no RTL parameter change."""
import argparse,json,sys
from pathlib import Path
import numpy as np
ROOT=Path(__file__).resolve().parents[2];sys.path.insert(0,str(ROOT/'dv/uvm/refmodel/python'))
from dsm_refmodel.thermo5 import read_source_vectors,run_centered_cubic_ef2_inputs,one_tap_complex_coefficients
from mash111_research import metrics,raw_fs4

def scalar(iq,step):
 residues=[[0,0] for _ in range(4)];off=[3*step,step,-step,-3*step];sat=0
 levels=np.empty((len(iq),2),dtype=np.int8)
 for n,pair in enumerate(iq):
  for c,x in enumerate(pair):
   y=0
   for plane in range(4):
    raw=int(x)+off[plane];sat+=raw < -32768 or raw > 32767
    val=min(32767,max(-32768,raw));u=residues[plane][c]+val+32768
    y+=2*(u>>16)-1;residues[plane][c]=u&65535
   levels[n,c]=y
 return levels,sat

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepared',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);ap.add_argument('--steps',type=int,nargs='+',default=[6400,6656,6912,7168,7424,7680]);a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=False)
 s=json.loads((a.prepared/'stimulus.json').read_text());s['qam_rows']=[[complex(*v) for v in row] for row in s['qam_rows']]
 iw,qw,fs,g=read_source_vectors(a.prepared/'input');front=run_centered_cubic_ef2_inputs(iw,qw,fs,g,dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
 iq=[(i,q) for iv,qv in front for i,q in zip(iv,qv)];res=[]
 for step in a.steps:
  levels,sat=scalar(iq,step);m=metrics(raw_fs4(levels),s)
  row={'step':step,'seed':s['seed'],'symbols':s['symbols'],'evm_percent':m['evm_percent'],'sndr_db':m['sndr_db'],'bit_errors':m['uncoded_bit_errors_natural_binary'],'bits':m['qam_symbols']*8,'offset_saturation_count':sat,'status':'scalar research, not new RTL acceptance'}
  if step==7168 and s['seed']==281001 and abs(row['evm_percent']-3.502994496691636)>1e-8:raise AssertionError('scalar EF1 does not reproduce actual RTL EVM')
  res.append(row);print(json.dumps(row),flush=True)
 (a.out/'metrics.json').write_text(json.dumps(res,indent=2)+'\n')
if __name__=='__main__':main()
