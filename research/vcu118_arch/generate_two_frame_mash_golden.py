#!/usr/bin/env python3
"""Generate a continuous-state scalar MASH golden for two identical frames."""
import argparse,hashlib,json,shutil,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'dv/uvm/refmodel/python'))
from dsm_refmodel.thermo5 import read_source_vectors,run_centered_cubic_ef2_inputs,one_tap_complex_coefficients
from dsm_refmodel.thermo5_mash import corrected_pa_words
p=argparse.ArgumentParser();p.add_argument('--vectors',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
iw,qw,starts,gains=read_source_vectors(a.vectors/'source_arch1')
if sum(starts)!=1 or not starts[0]:raise ValueError('expected one initial frame')
pre=run_centered_cubic_ef2_inputs(iw+iw,qw+qw,starts+starts,gains+gains,dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
iq=[(i,q) for iv,qv in pre for i,q in zip(iv,qv)]
pa=corrected_pa_words(iq);n=len(pa)//2
if len(pa)!=2*n or n!=5264:raise ValueError('unexpected sample count')
for plane in (0,1):
 old=[int(x,16) for x in (a.vectors/f'arch2_pa{plane}.mem').read_text().split()]
 if [v[plane] for v in pa[:n]]!=old:raise ValueError('first-frame oracle mismatch')
 for frame in (0,1):(out/f'frame{frame}_pa{plane}.mem').write_text(''.join(f'{v[plane]:016x}\n' for v in pa[frame*n:(frame+1)*n]))
for name in ('axis_i_samples.mem','axis_q_samples.mem'):shutil.copyfile(a.vectors/name,out/name)
(out/'manifest.json').write_text(json.dumps({'frames':2,'words_per_frame':n,'mash_state':'continuous, no reset','source_vectors':str(a.vectors),'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.mem')}},indent=2)+'\n')
print('TWO_FRAME_MASH_GOLDEN_PASS words_per_frame',n)
