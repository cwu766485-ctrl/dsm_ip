#!/usr/bin/env python3
"""Replay full captured OFDM through corrected adapter under control stress."""
import argparse
import json
from pathlib import Path
import shutil
import subprocess
from audit_mash_qam import ROOT,rows


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture',type=Path,required=True);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();cap=a.capture.resolve();out=a.output.resolve();out.mkdir(parents=True,exist_ok=False)
    pre=rows(cap/'pre_words.csv')
    files=['rtl/gt/gt_tx_user_bridge.sv','rtl/gt/gt_tx_raw64_boundary.sv',
        'research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
        'research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv',
        'research/thermo5_integration/rtl/thermo5_weighted_mash_encoder.sv',
        'research/thermo5_integration/rtl/thermo5_weighted_mash_backend_adapter.sv',
        'research/thermo5_integration/verif/tb/tb_mash_control_replay.sv']
    result={'scope':'adapter replay of all captured Cartesian OFDM samples; no AXIS STOP interface','runs':[]}
    for stress in (0,1):
        run=out/('stress'+str(stress));run.mkdir()
        for c in ('i','q'):(run/('stage1_replay_'+c+'.mem')).write_text(''.join(r[c+'_hex']+'\n' for r in pre))
        for c in range(2):shutil.copy2(cap/('corrected_expected_pa%d.mem'%c),run/('corrected_expected_pa%d.mem'%c))
        top='tb_mash_control_replay'
        commands=[['iverilog','-g2012','-s',top,'-P'+top+'.WORDS='+str(len(pre)),
            '-P'+top+'.STRESS='+str(stress),'-o',str(run/'controls.vvp'),*[str(ROOT/f) for f in files]],
            ['vvp',str(run/'controls.vvp')]]
        codes=[]
        for j,cmd in enumerate(commands):
            with (run/('compile.log' if j==0 else 'simulation.log')).open('w') as log:
                r=subprocess.run(cmd,cwd=run,stdout=log,stderr=subprocess.STDOUT)
            codes.append(r.returncode)
            if r.returncode:break
        result['runs'].append({'stress':stress,'commands':commands,'returncodes':codes})
        (out/'control_summary.json').write_text(json.dumps(result,indent=2)+'\n')
        if any(codes):raise SystemExit('Control regression failed: '+str(run))
        print('CONTROL_PASS stress='+str(stress),flush=True)


if __name__=='__main__':main()
