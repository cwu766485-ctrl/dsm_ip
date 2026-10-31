"""Run production-RTL reset/counter proofs with explicit scope and cover gates."""
import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import time

ROOT=Path(__file__).resolve().parents[3]
SOURCES=('rtl/axis/dsm_reset_sync.sv','rtl/dpd/dpd_poly.v','rtl/dpd/dpd_memory_poly.v',
         'rtl/interp/dsm_interp_x2_centered_cubic_vector.sv',
         'rtl/axis/dsm_async_fifo.sv','rtl/axis/dsm_axis14_to_core8_cdc.sv',
         'dv/uvm/formal/thermo5_reset_harness.sv',
         'dv/uvm/formal/thermo5_dpd_counter_harness.sv',
         'dv/uvm/formal/thermo5_dpd_identity_harness.sv',
         'dv/uvm/formal/thermo5_generic_cdc_harness.sv',
         'dv/uvm/formal/thermo5_cdc_end_branch_harness.sv',
         'dv/uvm/formal/thermo5_ef2_stability_harness.sv',
         'dv/uvm/formal/thermo5_ef2_pair_equiv_harness.sv',
         'dv/uvm/formal/thermo5_frame_tail_harness.sv',
         'dv/uvm/formal/thermo5_ef2_product_params_harness.sv',
         'rtl/gt/gt_tx_user_bridge.sv','rtl/gt/gt_tx_raw64_boundary.sv',
         'rtl/tx_bandpass_if/tid32_cartesian_ef2_fs4_gt_tx.sv',
         'dv/uvm/formal/run_thermo5_gap_fpv.tcl',
         'dv/uvm/formal/run_thermo5_cdc_end_branch_fpv.tcl')

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--unbounded-counter',action='store_true',
                    help='Also prove all 32 counter-bit transitions without a stream budget')
    ap.add_argument('--identity-and-residual',action='store_true',
                    help='Also prove identity arithmetic/latency and generic CDC residual legality')
    ap.add_argument('--residual-only',action='store_true',
                    help='Add the residual proof without the optional expensive arithmetic proof')
    ap.add_argument('--jobs',nargs='+',choices=('reset','counter','counter_unbounded','identity','cdc_residual','cdc_end_branch','ef2','ef2_pair','frame_tail','ef2_product_params'),
                    help='Run selected existing jobs for focused diagnosis')
    args=ap.parse_args(); out=Path(args.out_dir).resolve()
    if ROOT/'runs' not in out.parents or out.exists(): ap.error('Use a new runs/ directory')
    out.mkdir(parents=True)
    hashes={p:hashlib.sha256((ROOT/p).read_bytes()).hexdigest() for p in SOURCES}
    revision=subprocess.run(['git','-C',str(ROOT),'rev-parse','HEAD'],check=True,
                            stdout=subprocess.PIPE,universal_newlines=True).stdout.strip()
    git_status=subprocess.run(['git','-C',str(ROOT),'status','--porcelain'],check=True,
                              stdout=subprocess.PIPE,universal_newlines=True).stdout.splitlines()
    result={'status':'FAIL','source_sha256':hashes,
            'source':{'git_revision':revision,'worktree_dirty':bool(git_status),
                      'git_status':git_status},
            'jobs':[],'errors':[],
            'scope':{'reset':'runtime reset changes only on falling edge; active-edge collisions excluded',
                     'counter':'MAX_TAPS=1 identity; at most 2072 accepted inputs per reset epoch'}}
    kinds=('reset','counter','counter_unbounded') if args.unbounded_counter else ('reset','counter')
    if args.identity_and_residual:
        kinds+=('identity','cdc_residual')
        result['scope']['identity']='MAX_TAPS=1, USE_EXTERNAL_TAPS=1, identity; arbitrary signed payload and legal stalls'
        result['scope']['cdc_residual']='production generic FIFO CDC; separate clocks; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    elif args.residual_only:
        kinds+=('cdc_residual',)
        result['scope']['cdc_residual']='production generic FIFO CDC; separate clocks; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    if args.jobs:
        kinds=tuple(dict.fromkeys(args.jobs))
        if 'cdc_residual' in kinds:
            result['scope']['cdc_residual']='production generic FIFO CDC; exact 7:4 scaled clock periods; constructed registered legal AXIS source; no runtime assumptions on DUT state'
    if args.unbounded_counter:
        result['scope']['counter_unbounded']='MAX_TAPS=1 identity; no acceptance budget; transition proofs do not imply URG hits'
    if args.jobs and 'ef2' in args.jobs:
        result['scope']['ef2']='Production 32-lane signed-16 EF2, arbitrary input/ready sequences; prove widened no-wrap/bounds, state handshake, and output hold/capture'
    if args.jobs and 'ef2_pair' in args.jobs:
        result['scope']['ef2_pair']='Relational proof of exact pairwise look-ahead against scalar EF2 for arbitrary signed-16 input, stalls, and state saturation; product parameter remains disabled'
    if args.jobs and 'ef2_product_params' in args.jobs:
        result['scope']['ef2_product_params']='Exact W=16, CHANNELS=32 product EF2 parameter elaboration; prove PAIR_LOOKAHEAD=0 and legal parameter guard, while requiring corresponding candidate arms to be uncoverable'
    if args.jobs and 'cdc_end_branch' in args.jobs:
        result['scope']['cdc_end_branch']='Exact product 14:8 CDC gearbox and Generic FIFO; legal 32-beat AXIS packets; prove line-210 immediate frame-end arm unreachable and require legal frame-end context Cover'
    if args.jobs and 'frame_tail' in args.jobs:
        result['scope']['frame_tail']='Exact W=16, LANES=8 centered-cubic stage parameters; stage-1 input tail tied low as in the product, stage-2 APPEND_TAIL_VECTOR=0; prove single-entry pop/push reachable and exact tail-only paths uncoverable'
    if any(kind in kinds for kind in ('ef2','ef2_pair')):
        result['configuration']={'proof_core':'thermo5_ef2',
            'input_width_bits':16,'state_width_bits':20,
            'sample_order':'chronological','input_domain':'all signed-16 values',
            'product_pair_lookahead_default':False,
            'formal_harness_channels':{
                kind:(2 if kind=='ef2_pair' else 32)
                for kind in kinds if kind in ('ef2','ef2_pair')},
            'pair_transfer_composition':'The two-sample formal transfer repeats 16 times in the 32-sample VCS miter.'}
    for kind in kinds:
        top=('thermo5_ef2_stability_harness' if kind=='ef2' else
             'thermo5_ef2_pair_equiv_harness' if kind=='ef2_pair' else
             f'thermo5_{kind}_harness' if kind in ('counter_unbounded','identity','cdc_residual','cdc_end_branch','frame_tail','ef2_product_params') else
             f'thermo5_{kind}_gap_harness')
        work=out/kind; work.mkdir()
        env=os.environ.copy()
        env.update(THERMO5_FORMAL_TOP=top,THERMO5_FORMAL_OUT=str(work),THERMO5_FORMAL_REPO=str(ROOT))
        tcl_script=(ROOT/'dv/uvm/formal/run_thermo5_cdc_end_branch_fpv.tcl'
                    if kind=='cdc_end_branch' else ROOT/'dv/uvm/formal/run_thermo5_gap_fpv.tcl')
        argv=['vcf','-batch','-fmode','FPV','-f',str(tcl_script)]
        started=time.monotonic(); log=work/'console.log'
        try:
            with log.open('w') as stream:
                code=subprocess.run(argv,cwd=work,env=env,stdout=stream,stderr=subprocess.STDOUT,
                                    timeout=420).returncode
            setup=(work/'setup.txt').read_text()
            properties=(work/'properties.txt').read_text()
            assertions=re.findall(r'^\s*\[\s*\d+\]\s+(\w+)\s+.*? -\s+(\S*\.a_\S+)',properties,re.M)
            covers=re.findall(r'^\s*\[\s*\d+\]\s+(covered|uncoverable|inconclusive|undetermined|unprocessed)\s+.*? -\s+(\S*\.c_\S+)',properties,re.M)
            expected_covers=5 if kind=='reset' else 9 if kind=='cdc_residual' else 3 if kind=='cdc_end_branch' else 4 if kind=='ef2_pair' else 3 if kind=='ef2' else 2 if kind=='ef2_product_params' else 9 if kind=='frame_tail' else 4
            expected_assertions=35 if kind=='counter_unbounded' else 5 if kind=='identity' else 7 if kind in ('cdc_residual','ef2_pair') else 6 if kind=='ef2' else 2 if kind=='ef2_product_params' else 6 if kind=='frame_tail' else 1 if kind=='cdc_end_branch' else 3
            ok=code==0 and len(assertions)==expected_assertions and all(s=='proven' for s,n in assertions)
            if kind=='frame_tail':
                expected_cover_states={'c_append_frame_end':'covered',
                    'c_append_tail_transfer':'covered','c_plain_frame_end':'covered',
                    'c_plain_tail_unreachable':'uncoverable',
                    'c_append_single_pop_push':'covered',
                    'c_plain_single_pop_push':'covered',
                    'c_append_tail_head_drop_unreachable':'uncoverable',
                    'c_plain_tail_fire_unreachable':'uncoverable',
                    'c_plain_append_tail_arm_unreachable':'uncoverable'}
                observed_cover_states={n.rsplit('.',1)[-1]:s for s,n in covers}
                ok=ok and len(covers)==expected_covers and observed_cover_states==expected_cover_states
            elif kind=='ef2_product_params':
                expected_cover_states={'c_pair_lookahead_arm_enabled':'uncoverable',
                    'c_invalid_parameter_guard':'uncoverable'}
                observed_cover_states={n.rsplit('.',1)[-1]:s for s,n in covers}
                ok=ok and len(covers)==expected_covers and observed_cover_states==expected_cover_states
            elif kind=='cdc_end_branch':
                expected_cover_states={'c_product_end_branch_context':'covered',
                    'c_immediate_end_arm':'uncoverable',
                    'c_completed_legal_frame':'covered'}
                observed_cover_states={n.rsplit('.',1)[-1]:s for s,n in covers}
                ok=ok and len(covers)==expected_covers and observed_cover_states==expected_cover_states
            else:
                ok=ok and len(covers)==expected_covers and all(
                    s==('uncoverable' if n.endswith('.c_collision_bin') else 'covered') for s,n in covers)
            ok=ok and not re.search(r':\s+[1-9]\d*\s*$',setup,re.M)
            banner=log.read_text()
            blackboxes=re.findall(r'Number of Black-Box Instances\s*=\s*(\d+)',banner)
            ok=ok and bool(blackboxes) and all(int(x)==0 for x in blackboxes)
            if kind=='reset':
                ok=ok and bool(re.search(r'# non_vacuous\s*:\s*3\b',properties))
            else:
                if kind=='counter_unbounded':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*35\b',properties))
                    ok=ok and bool(re.search(r'constrained\s+\(non_vacuous\).*\.asm_payload_stable',properties))
                elif kind=='counter':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*2\b',properties))
                elif kind=='cdc_residual':
                    ok=ok and bool(re.search(r'proven\s+\(non_vacuous\).*\.a_axis_stable',properties))
                elif kind=='cdc_end_branch':
                    ok=ok and bool(re.search(r'proven\s+\(non_vacuous\).*\.a_immediate_end_arm_unreachable',properties))
                    ok=ok and not re.search(r'inconclusive|undetermined',properties)
                elif kind=='ef2':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*4\b',properties))
                elif kind=='ef2_pair':
                    ok=ok and bool(re.search(r'# non_vacuous\s*:\s*[1-9]\d*\b',properties))
                elif kind=='frame_tail':
                    ok=ok and bool(re.search(
                        r'constrained\s+\(non_vacuous\).*\.asm_source_stable',properties))
                elif kind=='ef2_product_params':
                    pass  # The checks are elaboration constants, not state-dependent properties.
                else:
                    ok=ok and bool(re.search(r'constrained\s+\(non_vacuous\).*\.asm_payload_stable',properties))
            result['jobs'].append({'kind':kind,'top':top,'status':'PASS' if ok else 'FAIL',
                'argv':argv,'exit_code':code,'duration_seconds':round(time.monotonic()-started,2),
                'assertions':assertions,'covers':covers,'log':str(log),
                'setup':str(work/'setup.txt'),'properties':str(work/'properties.txt'),
                'black_box_instances':blackboxes,
                'tool_banner':next((x.strip() for x in log.read_text().splitlines() if 'Version V-' in x),'UNKNOWN')})
            if not ok: result['errors'].append(f'{kind}: assertion/cover/vacuity/setup gate failed')
        except Exception as exc:
            result['errors'].append(f'{kind}: {exc}')
    if not result['errors'] and len(result['jobs'])==len(kinds): result['status']='PASS'
    (out/'formal_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps({'status':result['status'],'errors':result['errors'],'manifest':str(out/'formal_summary.json')}))
    return 0 if result['status']=='PASS' else 1

if __name__=='__main__': raise SystemExit(main())
