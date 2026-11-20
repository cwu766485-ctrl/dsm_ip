#!/usr/bin/env python3
"""Generate continuous-state scalar MASH goldens for repeated OFDM frames."""
import argparse,hashlib,json,shutil,sys
from pathlib import Path
root=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(root/'dv/uvm/refmodel/python'))
from dsm_refmodel.thermo5 import read_source_vectors,run_centered_cubic_ef2_inputs,one_tap_complex_coefficients
from dsm_refmodel.thermo5_mash import corrected_pa_words
p=argparse.ArgumentParser();p.add_argument('--vectors',type=Path,required=True);p.add_argument('--out',type=Path,required=True);p.add_argument('--frames',type=int,default=2);a=p.parse_args()
if a.frames < 1: raise ValueError('--frames must be positive')
out=a.out.resolve();out.mkdir(parents=True,exist_ok=False)
iw,qw,starts,gains=read_source_vectors(a.vectors/'source_arch1')
if sum(starts)!=1 or not starts[0]:raise ValueError('expected one initial frame')
pre=run_centered_cubic_ef2_inputs(iw*a.frames,qw*a.frames,starts*a.frames,gains*a.frames,dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
iq=[(i,q) for iv,qv in pre for i,q in zip(iv,qv)]
pa=corrected_pa_words(iq);n=len(pa)//a.frames
if len(pa)!=a.frames*n or n!=5264:raise ValueError('unexpected sample count')
for plane in (0,1):
 old=[int(x,16) for x in (a.vectors/f'arch2_pa{plane}.mem').read_text().split()]
 if [v[plane] for v in pa[:n]]!=old:raise ValueError('first-frame oracle mismatch')
 for frame in range(a.frames):(out/f'frame{frame}_pa{plane}.mem').write_text(''.join(f'{v[plane]:016x}\n' for v in pa[frame*n:(frame+1)*n]))
 (out/f'long_pa{plane}.mem').write_text(''.join(f'{v[plane]:016x}\n' for v in pa))
for name in ('axis_i_samples.mem','axis_q_samples.mem'):shutil.copyfile(a.vectors/name,out/name)
(out/'manifest.json').write_text(json.dumps({'frames':a.frames,'words_per_frame':n,'mash_state':'continuous, no reset','source_vectors':str(a.vectors),'sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in out.glob('*.mem')}},indent=2)+'\n')
print(f'CONTINUOUS_MASH_GOLDEN_PASS frames={a.frames} words_per_frame={n} total_words={len(pa)}')
