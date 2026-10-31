"""Exact raw URG gap ledger. Evidence is scoped; OPEN never becomes a waiver."""
import argparse
from collections import Counter
import csv
import hashlib
import html
import json
from pathlib import Path
import re
import subprocess
import thermo5_audit_reports as audit
from thermo5_coverage_denominator import inventory, fsm_inventory, fsm_gap_inventory

ROOT=Path(__file__).resolve().parents[2]

def source_file_by_instance(report):
    """Map exact URG hierarchy instances to the module source file(s)."""
    result={}
    for page in report.glob('mod*.html'):
        text=page.read_text(errors='replace')
        files=[]
        for raw in re.findall(r"openSrcFile\('([^']+)'\)",text):
            path=Path(html.unescape(raw))
            try:
                relative=path.resolve().relative_to(ROOT.resolve()).as_posix()
            except ValueError:
                relative=path.as_posix()
            if relative not in files:
                files.append(relative)
        if not files:
            continue
        for raw in re.findall(r"onclick=\"showContent\('inst_tag_[^']+'\)\">(.*?)</a>",text,re.S):
            instance=html.unescape(re.sub(r'<[^>]+>','',raw)).strip()
            if instance:
                result[instance]=';'.join(files)
    return result

def classify(instance, metric, key, hint):
    if audit.ownership(instance)=='VENDOR_XPM':
        return 'OPEN_VENDOR', 'Vendor configuration and reset/clock reachability require individual review.'
    if 'sample_count[' in key:
        return 'OPEN_COUNTER_FORMAL_REVIEW', 'High counter transitions are raw-unhit. Existing bounded proof is related evidence, not a simulator hit or automatic exclusion.'
    if ('IDENTITY' in hint or any(s in key for s in ('saturation_count','sat_i','sat_q')) or ':sat:' in key):
        return 'OPEN_ARITHMETIC_REVIEW', 'Identity/arithmetic analysis is only a review lead; verify exact SKU, stimulus, and checker before disposition. No exclusion.'
    if 'CONVEX_AVERAGE' in hint:
        return 'OPEN_ARITHMETIC_REVIEW', 'Convex-average bound is only a review lead; verify exact source/config/bin mapping. No exclusion.'
    if 'EXTERNAL_TAPS' in hint or 'HISTORY_OR_UNUSED_PAIR1' in hint or 'VECTOR_HISTORY_UNUSED' in hint or 'pair1' in key:
        return 'OPEN_CONFIGURATION_REVIEW', 'Tap/history alternative may be inactive in this configuration; confirm the elaborated hierarchy. No exclusion.'
    if 'FIXED' in hint or any(s in key for s in ('c1_re[','c1_im[','c3_re[','c3_im[','c5_re[','c5_im[','active_taps[','lp_state','lp_outstanding','lp_ingress_enable','lp_datapath_enable','core_drain')):
        return 'OPEN_CONFIGURATION_REVIEW', 'Frozen parameters may constrain this bin; verify exact elaboration and applicability. No exclusion.'
    if metric=='cond' and 'u_reset' in instance or metric=='cond' and instance.endswith(('.u_s_reset','.u_c_reset')):
        return 'OPEN_FORMAL_MAPPING_REVIEW', 'A scoped reset proof may be relevant; map the exact source condition and assumptions before disposition. No exclusion.'
    if metric=='cond' and instance.endswith('.u_cdc') and key=='117:0/1/1':
        return 'OPEN_FORMAL_MAPPING_REVIEW', 'A scoped generic CDC proof may be relevant; map the exact source condition and assumptions before disposition. No exclusion.'
    if 'rem_i_q[' in key or 'rem_q_q[' in key:
        return 'OPEN_FORMAL_MAPPING_REVIEW', 'A scoped generic CDC proof may be relevant; map exact bit, property, parameters, and assumptions before disposition. No exclusion.'
    if 'RESIDUAL' in hint or 'rem_count_q[0]' in key:
        return 'OPEN_FORMAL_MAPPING_REVIEW', 'A scoped residual-state proof may be relevant; map exact source bin, FIFO implementation, clocks, and assumptions. No exclusion.'
    return 'OPEN', 'Needs legal stimulus/checker/URG hit or specific proof; do not exclude.'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('closure',type=Path);ap.add_argument('out',type=Path)
    ap.add_argument('--report-layout',choices=('nested','flat'),default='nested',
                    help='flat reads <fifo>_coverage_after from a reused-baseline closure')
    ap.add_argument('--product-source-sha',
                    help='bind the ledger to the frozen simulation-product SHA when the analysis tree has documentation-only edits')
    ap.add_argument('--variants',nargs='+',choices=('generic','axil','xpm'),
                    default=('generic','xpm'),
                    help='Configurations to inventory; AXI-Lite is distinct from the Generic FIFO SKU')
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    result=[]
    for variant in args.variants:
        report=(args.closure/f'{variant}_coverage_after' if args.report_layout=='flat'
                else args.closure/'baseline'/variant/'coverage_after')
        totals,lines,branches=inventory(report)
        instance_sources=source_file_by_instance(report)
        conditions,toggles,_,_=audit.condition_rows(report)
        records=[]
        def add(instance,metric,key,hint,raw):
            status,reason=classify(instance,metric,key,hint)
            if variant=='xpm' and status=='SCOPED_FORMAL_PROVEN' and 'generic CDC' in reason: status='OPEN_XPM_PROOF_TRANSFER'
            if variant=='xpm' and status=='SCOPED_FORMAL_PROVEN' and 'residual' in reason.lower(): status='OPEN_XPM_PROOF_TRANSFER'
            identity='|'.join((variant,instance,metric,key))
            records.append(dict(bin_id=hashlib.sha256(identity.encode()).hexdigest()[:20],
                configuration=variant,instance=instance,metric=metric,bin=key,status=status,reason=reason,
                source_files=instance_sources.get(instance,'OPEN_SOURCE_MAP'),
                evidence_hint=hint,raw=raw))
        for r in lines:
            for n in range(r['missing']):add(r['instance'],'line',f"{r['line']}:{n}",r['disposition'],r)
        for r in branches:add(r['instance'],'branch',f"{r['line']}:{r['decisions']}",r['disposition'],r)
        for r in conditions:
            if r['status']=='Not Covered':add(r['instance'],'cond',f"{r['line']}:{r['operand_bin']}",r['disposition'],r)
        for r in toggles:
            match=re.fullmatch(r'(.*)\[(\d+):(\d+)\]',r['signal'])
            signals=[f'{match[1]}[{bit}]' for bit in range(int(match[3]),int(match[2])+1)] if match else [r['signal']]
            for signal in signals:
                for direction,col in (('1_to_0','one_to_zero'),('0_to_1','zero_to_one')):
                    if r[col]=='No':add(r['instance'],'toggle',r['kind']+':'+signal+':'+direction,r['disposition'],r)
        for r in fsm_gap_inventory(report):
            add(r['instance'],'fsm',r['fsm']+':'+r['metric']+':'+r['bin']+':'+str(r['line']),
                'OPEN_FSM_BIN_REVIEW',r)
        unmapped=[r for r in records if r['source_files']=='OPEN_SOURCE_MAP'
                  and r['raw'].get('ownership')!='VENDOR_XPM']
        assert not unmapped, (variant,unmapped[:3])
        assert len([r for r in records if r['metric']=='line'])==sum(r['missing'] for r in totals if r['metric']=='line')
        assert len([r for r in records if r['metric']=='branch'])==sum(r['missing'] for r in totals if r['metric']=='branch')
        # Vendor memory has condition tables with nonstandard macro formatting.
        # Retain an explicit extraction gap instead of inventing bin identities.
        condition_detail=Counter(r['instance'] for r in records if r['metric']=='cond')
        extraction_gaps=[dict(instance=r['instance'],metric='cond',
            missing_details=r['missing']-condition_detail[r['instance']],status='OPEN_REPORT_EXTRACTION')
            for r in totals if r['metric']=='cond' and r['missing']!=condition_detail[r['instance']]]
        if variant!='xpm':
            assert not extraction_gaps, (variant, extraction_gaps)
        else:
            assert all(audit.ownership(r['instance'])=='VENDOR_XPM' for r in extraction_gaps)
        analysis_git_sha=subprocess.run(['git','rev-parse','HEAD'],cwd=ROOT,check=True,capture_output=True,text=True).stdout.strip()
        product_git_sha=args.product_source_sha or analysis_git_sha
        worktree_dirty=bool(subprocess.run(['git','status','--porcelain','--untracked-files=all'],
            cwd=ROOT,check=True,capture_output=True,text=True).stdout.strip())
        source_roots=(ROOT/'rtl',ROOT/'dv'/'uvm')
        source_hashes={p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest()
            for root in source_roots for p in root.rglob('*') if p.is_file() and p.suffix in ('.v','.sv','.svh')}
        payload={'configuration':variant,'exclusions_applied':False,
                 'source_git_sha':product_git_sha,'analysis_git_sha':analysis_git_sha,
                 'worktree_dirty':worktree_dirty,
                 'report_path':str(report.resolve()),
                 'status_counts':dict(Counter(r['status'] for r in records)),
                 'source_file_map_entries':len(instance_sources),
                 'source_sha256':source_hashes,
                 'records':records,'extraction_gaps':extraction_gaps,
                 'toggle_note':'Directional bins expanded from URG packed rows; Total Bits is the sum of 0->1 and 1->0 directional totals.',
                 'disposition_note':'All statuses are open review queues. This script applies no exclusions, waivers, or coverage-denominator changes.'}
        (args.out/(variant+'_gap_ledger.json')).write_text(json.dumps(payload,indent=2)+'\n')
        result.append({k:v for k,v in payload.items() if k not in ('records','source_sha256')})
    ledger_path=args.out/'thermo5-tx-gate3-coverage-ledger.csv'
    fields=('bin_id','configuration','instance','source_files','metric','bin','status',
            'reason','evidence_hint')
    with ledger_path.open('w',newline='') as handle:
        writer=csv.DictWriter(handle,fieldnames=fields)
        writer.writeheader()
        for variant in args.variants:
            payload=json.loads((args.out/(variant+'_gap_ledger.json')).read_text())
            for record in payload['records']:
                writer.writerow({k:record[k] for k in fields})
    (args.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()
