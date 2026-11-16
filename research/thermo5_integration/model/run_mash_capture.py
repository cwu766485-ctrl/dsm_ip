#!/usr/bin/env python3
"""Fresh, source-hashed Icarus full-chain capture; never overwrite a run."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import shutil
import subprocess


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--input-run', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    ap.add_argument('--correct-residue', action='store_true',
                    help='Opt-in corrected error-state candidate; historical Goldens stay unchanged')
    args = ap.parse_args()
    root = Path(__file__).resolve().parents[3]
    source = args.input_run.resolve()
    out = args.output.resolve()
    out.mkdir(parents=True, exist_ok=False)
    for name in ('axis_i_samples.mem', 'axis_q_samples.mem',
                 'expected_mash_pa0.mem', 'expected_mash_pa1.mem', 'stimulus.json'):
        shutil.copy2(source / name, out / name)
    meta = json.loads((source / 'stimulus.json').read_text())
    if args.correct_residue:
        import sys
        sys.path.insert(0,str(root/'dv/uvm/refmodel/python'))
        from dsm_refmodel.thermo5 import (read_source_vectors, run_centered_cubic_ef2_inputs,
                                         one_tap_complex_coefficients)
        from mash_accumulator_reference import corrected_pa_words
        i,q,starts,gains=read_source_vectors(source/'frontend_vectors')
        pre=run_centered_cubic_ef2_inputs(i,q,starts,gains,
            dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
        iq=[(ii,qq) for iw,qw in pre for ii,qq in zip(iw,qw)]
        expected=corrected_pa_words(iq)
        for c in range(2):
            (out/('corrected_expected_pa%d.mem'%c)).write_text(''.join('%016x\n'%w[c] for w in expected))
    files = [line.strip() for line in (root / 'dv/uvm/sim/thermo5_sku_filelist.f').read_text().splitlines()
             if line.startswith('rtl/')]
    files = [f for f in files if f != 'rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv']
    files += [
        'research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv',
        'research/thermo5_weighted_mash/rtl/tx_bandpass_if/tid32_mash11_fs4_multipa_tx.sv',
        'research/thermo5_integration/rtl/thermo5_weighted_mash_encoder.sv',
        'research/thermo5_integration/rtl/thermo5_weighted_mash_backend_adapter.sv',
        'research/thermo5_integration/rtl/thermo5_unified_dsm_backend.sv',
        'research/thermo5_integration/rtl/tid32_thermo5_mash_axis_frontend_tx.sv',
        'research/thermo5_integration/verif/tb/tb_tid32_thermo5_mash_axis_qam.sv',
    ]
    top = 'tb_tid32_thermo5_mash_axis_qam'
    commands = [
        ['iverilog', '-g2012', '-DSYNTHESIS', '-s', top, '-P'+top+'.SOURCE_BEATS='+str(meta['axis_beats']),
         '-P'+top+'.EXPECTED_WORDS='+str(meta['frontend_words']),
         '-P'+top+'.USE_ACCUMULATOR_RESIDUE='+str(int(args.correct_residue)),
         '-o', str(out/'capture.vvp'), *[str(root/f) for f in files]],
        ['vvp', str(out/'capture.vvp'), '+pa0=captured_mash_pa0.mem',
         '+pa1=captured_mash_pa1.mem', '+audit_dir='+str(out), '+vcd='+str(out/'audit.vcd')],
    ]
    manifest = {'commands': commands, 'cwd': str(out), 'source_root': str(root),
                'use_accumulator_residue':args.correct_residue,
                'sources': {f: hashlib.sha256((root/f).read_bytes()).hexdigest() for f in files},
                'input_sha256': {f: hashlib.sha256((source/f).read_bytes()).hexdigest()
                                 for f in ('axis_i_samples.mem','axis_q_samples.mem','stimulus.json')},
                'iverilog_version': subprocess.run(['iverilog','-V'],capture_output=True,text=True).stdout,
                'returncodes': []}
    for i, cmd in enumerate(commands):
        with (out / ('compile.log' if i == 0 else 'simulation.log')).open('w') as log:
            result = subprocess.run(cmd, cwd=out, stdout=log, stderr=subprocess.STDOUT)
        manifest['returncodes'].append(result.returncode)
        (out/'capture_manifest.json').write_text(json.dumps(manifest, indent=2)+'\n')
        if result.returncode:
            raise SystemExit('Capture failed: '+str(out))
    print('CAPTURE_PASS '+str(out), flush=True)


if __name__ == '__main__':
    main()
