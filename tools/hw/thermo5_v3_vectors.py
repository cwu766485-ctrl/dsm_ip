#!/usr/bin/env python3.12
"""Generate P0 source/static expectations with existing bit-true functions."""
from pathlib import Path
import sys,json
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'dv/uvm/refmodel/python'))
from dsm_refmodel.thermo5 import (generate_source_vectors,one_tap_complex_coefficients,
 run_centered_cubic_frontend,run_centered_cubic_ef2_inputs,write_vectors)

def main():
 for name,words,starts,configs in [('overlap',112,(1,57),[None,{'coefficients':one_tap_complex_coefficients(12288,0),'active_taps':1}]),
                                  ('long64',112,(1,),None),('long96',168,(1,),None),('reset',56,(1,),None)]:
  out=ROOT/'runs/dv_convergence_v3/vectors'/name
  i,q,s,g=generate_source_vectors(words=words,seed=930000,profile='random',frame_start_words=starts,frame_gains=(16384,)*len(starts))
  pa=run_centered_cubic_frontend(i,q,s,g,step=5120,tidsm_order=2,dpd_configs_by_frame=configs)
  ef=run_centered_cubic_ef2_inputs(i,q,s,g,dpd_configs_by_frame=configs)
  write_vectors(out,i,q,s,g,pa,ef2_words=ef)
  (out/'p0_manifest.json').write_text(json.dumps({'case':name,'words':words,'seed':930000,'starts':starts,'new_c1':12288 if name=='overlap' else None},indent=2)+'\n')
  print(name,words,'PASS')
if __name__=='__main__':main()
