#!/usr/bin/env python3
"""Same source and frontend, independent EF1/EF2/accumulator-MASH PA oracles."""
import argparse
import hashlib
import json
from pathlib import Path
import shutil
import subprocess
import sys
from dsm_refmodel.thermo5 import read_source_vectors,run_centered_cubic_ef2_inputs,one_tap_complex_coefficients
from dsm_refmodel.thermo5_mash import corrected_pa_words


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--output-dir',type=Path,required=True)
    ap.add_argument('--words',type=int,default=56)
    ap.add_argument('--seed',type=int,default=610216)
    ap.add_argument('--input-dir',type=Path)
    a=ap.parse_args();out=a.output_dir.resolve();out.mkdir(parents=True,exist_ok=False)
    if a.words%56:raise ValueError('Product packets require 56-output-word quanta')
    generator=Path(__file__).with_name('generate_thermo5_frontend_vectors.py')
    commands=[]
    for arch,order,step in ((0,1,7168),(1,2,5120)):
        cmd=[sys.executable,str(generator),'--output-dir',str(out/('source_arch'+str(arch))),
             '--words',str(a.words),'--seed',str(a.seed),'--interp-mode','centered_cubic',
             '--tidsm-order',str(order),'--step',str(step),'--frame-start-words','1','--frame-gains','16384']
        if a.input_dir:cmd+=['--input-dir',str(a.input_dir.resolve())]
        subprocess.run(cmd,check=True);commands.append(cmd)
        for plane in range(4):shutil.copy2(out/('source_arch'+str(arch))/('tid32_thermo5_frontend_pa%d.mem'%plane),out/('arch%d_pa%d.mem'%(arch,plane)))
    names=('tid32_thermo5_frontend_i.mem','tid32_thermo5_frontend_q.mem')
    for name in names:
        if (out/'source_arch0'/name).read_bytes()!=(out/'source_arch1'/name).read_bytes():raise ValueError('Architecture inputs differ')
    iw,qw,starts,gains=read_source_vectors(out/'source_arch1')
    if sum(starts)!=1 or not starts[0] or any(v!=16384 for v in gains):raise ValueError('Runtime replay uses one unity-gain packet frame')
    pre=run_centered_cubic_ef2_inputs(iw,qw,starts,gains,dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
    iq=[(i,q) for iv,qv in pre for i,q in zip(iv,qv)]
    pa=corrected_pa_words(iq)
    for p in range(2):(out/('arch2_pa%d.mem'%p)).write_text(''.join('%016x\n'%row[p] for row in pa))
    for c,words in (('i',iw),('q',qw)):
        flat=[v for word in words for v in word]
        (out/('axis_'+c+'_samples.mem')).write_text(''.join('%04x\n'%(v&65535) for v in flat))
    m={'words':len(iw),'source_beats':len(iw)*8//14,'seed':a.seed,'commands':commands,
       'input_sha256':{n:hashlib.sha256((out/n).read_bytes()).hexdigest() for n in ('axis_i_samples.mem','axis_q_samples.mem')},
       'architecture_contracts':{'0':'EF1 STEP7168 four equal PA','1':'EF2 STEP5120 four equal PA','2':'accumulator MASH, two PA weights1:2'}}
    (out/'manifest.json').write_text(json.dumps(m,indent=2)+'\n');print('RUNTIME_VECTORS_PASS '+str(out),flush=True)


if __name__=='__main__':main()
