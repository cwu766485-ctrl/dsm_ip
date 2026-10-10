"""Compile once per FIFO, measure baseline, then compare exact bins after legal directed tests."""
import argparse
import csv
import importlib.util
import json
from pathlib import Path
import re
import subprocess
import sys

HERE=Path(__file__).resolve().parent
ROOT=HERE.parents[2]
spec=importlib.util.spec_from_file_location('frozen',HERE/'run_thermo5_frozen_regression.py')
frozen=importlib.util.module_from_spec(spec); spec.loader.exec_module(frozen)
sys.path.insert(0,str(ROOT/'tools/hw'))
import thermo5_audit_reports as audit
import thermo5_coverage_denominator as denominator

def toggle_bits(report):
    """Expand URG's grouped ranges; retain both measured directions per bit."""
    result={}
    for row in audit.condition_rows(report,include_covered_toggles=True)[1]:
        match=re.fullmatch(r'(.*)\[(\d+)(?::(\d+))?\]',row['signal'])
        signals=[row['signal']]
        if match:
            hi=int(match[2]); lo=int(match[3] or match[2])
            signals=[f'{match[1]}[{bit}]' for bit in range(min(lo,hi),max(lo,hi)+1)]
        for signal in signals:
            key=(row['instance'],row['kind'],signal)
            result[key]={**row,'signal':signal}
    return result

def toggle_delta(before_report,after_report):
    before=toggle_bits(before_report); after=toggle_bits(after_report)
    delta=[]
    for key,row in before.items():
        if row['one_to_zero']=='Yes' and row['zero_to_one']=='Yes': continue
        if key not in after: raise RuntimeError(f'After toggle bit missing: {key}')
        later=after[key]
        delta.append({'instance':key[0],'kind':key[1],'signal':key[2],
            'before_1_to_0':row['one_to_zero'],'before_0_to_1':row['zero_to_one'],
            'after_1_to_0':later['one_to_zero'],'after_0_to_1':later['zero_to_one'],
            'status':'HIT_BOTH_DIRECTIONS' if later['one_to_zero']=='Yes' and
                     later['zero_to_one']=='Yes' else 'PARTIAL_OR_OPEN'})
    return delta

def inventory(report,out):
    conditions,toggles,branches,gaps=audit.condition_rows(report)
    if not conditions or not toggles or not branches: raise RuntimeError('Incomplete URG inventory')
    out.mkdir()
    for name,rows in (('conditions',conditions),('toggle_gaps',toggles),('branches',gaps)):
        audit.write_csv(out/(name+'.csv'),list(rows[0]),rows)
    totals,lines,arms=denominator.inventory(report)
    for name,rows in (('denominators',totals),('line_gaps',lines),('branch_arms',arms)):
        audit.write_csv(out/(name+'.csv'),list(rows[0]),rows)
    return conditions,toggles,gaps

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--out-dir',required=True)
    ap.add_argument('--xpm-root',required=True)
    ap.add_argument('--range-vectors',required=True)
    ap.add_argument('--range-words',type=int,default=2072,
                    help='Independent oracle words; >=2072 and a multiple of seven')
    ap.add_argument('--gain-vectors',type=Path,
                    help='Optional 56-word MATLAB extreme-payload/saturating-gain oracle')
    ap.add_argument('--gain-toggle-vectors',type=Path,
                    help='Optional legal gain 0/max/min independent oracle')
    ap.add_argument('--endpoint-vectors',default=str(ROOT/'runs/uvm_thermo5_extreme_20261003'))
    ap.add_argument('--dry-run',action='store_true')
    ap.add_argument('--baseline-dir',type=Path,
                    help='Reuse a PASS baseline only when its current source hash matches')
    args=ap.parse_args()
    if args.range_words < 2072 or args.range_words % 7:
        ap.error('--range-words must be >=2072 and a multiple of seven')
    out=Path(args.out_dir).resolve(); vectors=Path(args.range_vectors).resolve()
    if ROOT/'runs' not in out.parents or out.exists(): ap.error('Use a new runs/ directory')
    out.mkdir(parents=True)
    # Check exact independent oracle lengths before a costly compile.
    if not args.dry_run:
        sets=[(vectors,args.range_words),(Path(args.endpoint_vectors),56)]
        if args.gain_vectors: sets.append((args.gain_vectors,56))
        if args.gain_toggle_vectors: sets.append((args.gain_toggle_vectors,56))
        for vec,words in sets:
            for suffix in ('i','q','frame_start','frame_gain','pa0','pa1','pa2','pa3'):
                path=vec/f'tid32_thermo5_frontend_{suffix}.mem'
                count=len(path.read_text().split())
                if count != words*(8 if suffix in ('i','q') else 1):
                    ap.error(f'Invalid vector length: {path}, count={count}')
    start_source=frozen.source_state()
    baseline_dir=args.baseline_dir.resolve() if args.baseline_dir else out/'baseline'
    command=[sys.executable,str(HERE/'run_thermo5_frozen_regression.py'),'--out-dir',str(baseline_dir),
             '--xpm-root',args.xpm_root]
    if args.dry_run: command+=['--dry-run']
    if args.baseline_dir:
        previous=json.loads((baseline_dir/'manifest.json').read_text())
        if previous['status']!='PASS' or previous['source']['rtl_dv_source_sha256']!=start_source['rtl_dv_source_sha256']:
            ap.error('Reused baseline must be PASS and match the current source hash')
        code=0
    else:
        code=subprocess.call(command,cwd=ROOT)
    result={'source_before':start_source,'baseline_exit_code':code,'status':'DRY_RUN' if args.dry_run else 'FAIL',
            'directed':[],'fifo_reports':[],'errors':[]}
    try:
        if code: raise RuntimeError('Fresh baseline failed; no coverage closure attempted')
        if args.dry_run:
            result['planned_tests']=['interp1_empty_blocked',f'range_long_{args.range_words}','signed_endpoints']
        else:
            baseline=json.loads((baseline_dir/'manifest.json').read_text())
            if baseline['status']!='PASS': raise RuntimeError('Baseline manifest is not PASS')
            for fifo in ('generic','xpm'):
                build=baseline_dir/fifo
                before=inventory(build/'coverage',out/f'{fifo}_audit_before')
                tests=[('thermo5_sku_interp1_empty_blocked_test',610071,frozen.BASE_VECTORS,'',56,
                        'THERMO5_INTERP1_EMPTY_BLOCKED_UVM_PASS'),
                       ('thermo5_sku_prestart_empty_test',610083,frozen.BASE_VECTORS,'',56,
                        'THERMO5_PRESTART_EMPTY_PASS'),
                       ('thermo5_sku_long_counter_test',610072,vectors,
                        f'+CORE_WORDS={args.range_words} +EXPECT_SIGNED_EXTREMES',args.range_words,'THERMO5_SKU_UVM_PASS'),
                       ('thermo5_sku_bittrue_test',610106,Path(args.endpoint_vectors),
                        '+EXPECT_SIGNED_EXTREMES',56,'THERMO5_SKU_UVM_PASS')]
                if args.gain_vectors:
                    tests.append(('thermo5_sku_bittrue_test',610082,args.gain_vectors,
                        '+EXPECT_SIGNED_EXTREMES +STRESS_PA_READY',56,'THERMO5_SKU_UVM_PASS'))
                if args.gain_toggle_vectors:
                    tests.append(('thermo5_sku_bittrue_test',610084,args.gain_toggle_vectors,
                        '+EXPECT_SIGNED_EXTREMES +STRESS_PA_READY',56,'THERMO5_SKU_UVM_PASS'))
                if fifo=='xpm':
                    tests.extend(('thermo5_sku_fifo_reset_phase_test',610200+delay,
                                  frozen.BASE_VECTORS,f'+FIFO_RESET_DELAY={delay}',56,
                                  'THERMO5_FIFO_RESET_PHASE_UVM_PASS') for delay in range(12))
                extra=[]
                for name,seed,vec,plus,words,marker in tests:
                    argv=['make','-C',str(HERE),'thermo5-vcs-run-only',f'THERMO5_FIFO_IMPL={fifo}',
                          f'THERMO5_OUT={build}',f'THERMO5_VECTORS={vec}',f'THERMO5_TESTNAME={name}',
                          f'UVM_SEED={seed}',f'THERMO5_EXTRA_ARGS={plus}','THERMO5_COVERAGE=1']
                    record=frozen.execute(argv,ROOT,out/f'{fifo}_{name}.log',False)
                    log=build/f'{name}_seed{seed}.log'
                    text=log.read_text(errors='replace') if log.exists() else ''
                    if record['exit_code'] or marker not in text or 'TEST_DONE' not in text or any(
                        not re.search(rf'{kind}\s*:\s*0\b',text) for kind in ('UVM_ERROR','UVM_FATAL')):
                        raise RuntimeError(f'{fifo}/{name} failed completion/error gates')
                    if f'output={words}' not in text: raise RuntimeError('Golden output count marker missing')
                    if name=='thermo5_sku_long_counter_test' and 'THERMO5_LONG_COUNTER_RESET_PASS' not in text:
                        raise RuntimeError('Post-stream independent counter reset check missing')
                    vdb=build/f'cov_{name}_seed{seed}.vdb'
                    if not vdb.is_dir(): raise RuntimeError('Directed VDB missing')
                    extra.append(vdb)
                    result['directed'].append({'fifo':fifo,'test':name,'command':record,'golden_words':words,
                        'seed':seed,'simv_sha256':frozen.sha256(build/'simv'),'log':str(log),
                        'vectors_sha256':{p.name:frozen.sha256(p) for p in vec.glob('*.mem')},'vdb':str(vdb)})
                merged=next(r for r in baseline['urg_merges'] if r['fifo_implementation']==fifo)
                report=out/f'{fifo}_coverage_after'
                argv=['urg','-full64','-dir',str(build/'simv.vdb'),*merged['vdb_inputs'],*[str(p) for p in extra],
                      '-report',str(report),'-dbname',f'thermo5_{fifo}_closure']
                record=frozen.execute(argv,ROOT,out/f'{fifo}_urg_after.log',False)
                if record['exit_code'] or re.search(r'Error-|Design Not Loaded',(out/f'{fifo}_urg_after.log').read_text()):
                    raise RuntimeError('URG after merge failed')
                after=inventory(report,out/f'{fifo}_audit_after')
                delta=toggle_delta(build/'coverage',report)
                audit.write_csv(build/'toggle_bit_delta.csv',list(delta[0]),delta)
                # Every baseline condition must exist in the after report. No missing row is a hit.
                condkey=lambda r:(r['instance'],r['line'],r['expression'],r['operand_bin'])
                after_cond={condkey(r):r for r in after[0]}
                if set(condkey(r) for r in before[0])-after_cond.keys(): raise RuntimeError('After condition rows missing')
                closed=[{'before':r,'after':after_cond[condkey(r)]} for r in before[0]
                        if r['status']=='Not Covered' and after_cond[condkey(r)]['status']=='Covered']
                # Toggle gap disappearance is reported as a gap removal, not a per-bit proof:
                # grouped vector rows may shrink, and URG HTML retains direction detail.
                togkey=lambda r:(r['instance'],r['kind'],r['signal'])
                remaining={togkey(r) for r in after[1]}
                removed=[r for r in before[1] if togkey(r) not in remaining]
                result['fifo_reports'].append({'fifo':fifo,'condition_hits':closed,'toggle_gap_rows_removed':removed,
                    'toggle_bit_delta':str(build/'toggle_bit_delta.csv'),
                    'tid_bits_before':sum('.u_tid' in r['instance'] for r in delta),
                    'tid_bits_hit_both':sum('.u_tid' in r['instance'] and r['status']=='HIT_BOTH_DIRECTIONS' for r in delta),
                    'before_dut':merged['dut_hierarchy_code_coverage'],
                    'after_dut':frozen.parse_dut_code_coverage(report/'hierarchy.html'),
                    'remaining_conditions':[r for r in after[0] if r['status']=='Not Covered'],
                    'remaining_toggle_rows':len(after[1]),'urg_command':record,
                    'before_report':str(build/'coverage'),'after_report':str(report)})
            if frozen.source_state()['rtl_dv_source_sha256']!=start_source['rtl_dv_source_sha256']:
                raise RuntimeError('RTL/DV source changed during compile/run; results need provenance review')
            result['status']='PASS'
    except Exception as exc: result['errors'].append(str(exc))
    (out/'closure.json').write_text(json.dumps(result,indent=2)+'\n')
    lines=['# Thermo5 same-build coverage delta','',
           '| FIFO | DUT score before | DUT score after | Exact condition hits | TID bits hit both directions |',
           '| --- | ---: | ---: | ---: | ---: |']
    for row in result['fifo_reports']:
        lines.append(f"| {row['fifo']} | {row['before_dut']['score']} | {row['after_dut']['score']} | {len(row['condition_hits'])} | {row['tid_bits_hit_both']}/{row['tid_bits_before']} |")
    lines+=['','Generic and XPM include different hierarchies; compare each implementation only to itself.',
            'Formal dispositions do not change raw URG percentages. See closure.json and toggle_bit_delta.csv.']
    (out/'coverage_summary.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps({'status':result['status'],'errors':result['errors'],'manifest':str(out/'closure.json')}))
    return 0 if result['status'] in ('PASS','DRY_RUN') and not result['errors'] else 1

if __name__=='__main__': raise SystemExit(main())
