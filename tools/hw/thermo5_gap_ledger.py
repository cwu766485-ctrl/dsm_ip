"""Exact raw URG gap ledger. Evidence is scoped; OPEN never becomes a waiver."""
import argparse
from collections import Counter
import hashlib
import json
from pathlib import Path
import re
import thermo5_audit_reports as audit
from thermo5_coverage_denominator import inventory, fsm_inventory

ROOT=Path(__file__).resolve().parents[2]

def classify(instance, metric, key, hint):
    if audit.ownership(instance)=='VENDOR_XPM':
        return 'OPEN_VENDOR', 'Vendor configuration and reset/clock reachability require individual review.'
    if 'sample_count[' in key:
        return 'OPEN_REACHABLE_FORMAL_TRANSITION_PROVEN', '32-bit carry/increment/hold proof; raw URG high bits still unhit. No exclusion.'
    if ('IDENTITY' in hint or any(s in key for s in ('saturation_count','sat_i','sat_q')) or ':sat:' in key):
        return 'ARITHMETIC_PROOF_AND_EXHAUSTIVE_RTL', 'Identity gain=16384, imaginary/nonlinear gains=0; full signed domain and exhaustive RTL pipeline check. Not full sequential FPV signoff.'
    if 'CONVEX_AVERAGE' in hint:
        return 'ARITHMETIC_INTERVAL_PROOF', 'Two nonnegative 8192 coefficients; rounded convex average stays in [-32768,32767].'
    if 'EXTERNAL_TAPS' in hint or 'HISTORY_OR_UNUSED_PAIR1' in hint or 'VECTOR_HISTORY_UNUSED' in hint or 'pair1' in key:
        return 'CONFIGURATION_PROOF', 'MAX_TAPS=1, USE_EXTERNAL_TAPS=1: history/pair1 alternative implementation absent or zero.'
    if 'FIXED' in hint or any(s in key for s in ('c1_re[','c1_im[','c3_re[','c3_im[','c5_re[','c5_im[','active_taps[','lp_state','lp_outstanding','lp_ingress_enable','lp_datapath_enable','core_drain')):
        return 'CONFIGURATION_PROOF', 'Frozen elaboration parameters/identity coefficient ports; see SKU TB and parameter guards.'
    if metric=='cond' and 'u_reset' in instance or metric=='cond' and instance.endswith(('.u_s_reset','.u_c_reset')):
        return 'SCOPED_FORMAL_PROVEN', 'Reset collision operand 1/0 uncoverable with falling-edge runtime reset; other normal/reset covers hit.'
    if metric=='cond' and instance.endswith('.u_cdc') and key=='117:0/1/1':
        return 'SCOPED_FORMAL_PROVEN', 'Expanded generic CDC proof: out_frame_start_q implies out_valid_q; core_enable=0 makes core_ready=0 in integrated frontend. Exact 7:4 clock/reset scope.'
    if 'rem_i_q[' in key or 'rem_q_q[' in key:
        return 'SCOPED_FORMAL_PROVEN', 'Expanded generic CDC proof: bits223:192 stay zero after reset; nine nonvacuous operating covers. XPM transfer not inferred.'
    if 'RESIDUAL' in hint or 'rem_count_q[0]' in key:
        return 'SCOPED_FORMAL_PROVEN' if '.g_generic_fifo' in instance or instance.endswith('.u_cdc') else 'OPEN', 'Generic FIFO exact 7:4 clocks: residual {0,2,4,6,8,10,12}; nine covers. XPM transfer not inferred.'
    return 'OPEN', 'Needs legal stimulus/checker/URG hit or specific proof; do not exclude.'

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('closure',type=Path);ap.add_argument('out',type=Path)
    args=ap.parse_args();args.out.mkdir(parents=True,exist_ok=True)
    result=[]
    for fifo in ('generic','xpm'):
        report=args.closure/'baseline'/fifo/'coverage_after'
        totals,lines,branches=inventory(report)
        conditions,toggles,_,_=audit.condition_rows(report)
        records=[]
        def add(instance,metric,key,hint,raw):
            status,reason=classify(instance,metric,key,hint)
            if fifo=='xpm' and status=='SCOPED_FORMAL_PROVEN' and 'generic CDC' in reason: status='OPEN_XPM_PROOF_TRANSFER'
            if fifo=='xpm' and status=='SCOPED_FORMAL_PROVEN' and 'residual' in reason.lower(): status='OPEN_XPM_PROOF_TRANSFER'
            identity='|'.join((fifo,instance,metric,key))
            records.append(dict(bin_id=hashlib.sha256(identity.encode()).hexdigest()[:20],
                fifo=fifo,instance=instance,metric=metric,bin=key,status=status,reason=reason,
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
        for r in fsm_inventory(report):
            if r['missing']:add(r['instance'],'fsm',r['fsm']+':'+r['metric'], 'OPEN_VENDOR_FSM_DETAIL',r)
        assert len([r for r in records if r['metric']=='line'])==sum(r['missing'] for r in totals if r['metric']=='line')
        assert len([r for r in records if r['metric']=='branch'])==sum(r['missing'] for r in totals if r['metric']=='branch')
        # Vendor memory has condition tables with nonstandard macro formatting.
        # Retain an explicit extraction gap instead of inventing bin identities.
        condition_detail=Counter(r['instance'] for r in records if r['metric']=='cond')
        extraction_gaps=[dict(instance=r['instance'],metric='cond',
            missing_details=r['missing']-condition_detail[r['instance']],status='OPEN_REPORT_EXTRACTION')
            for r in totals if r['metric']=='cond' and r['missing']!=condition_detail[r['instance']]]
        assert all(audit.ownership(r['instance'])=='VENDOR_XPM' for r in extraction_gaps)
        payload={'fifo':fifo,'exclusions_applied':False,'status_counts':dict(Counter(r['status'] for r in records)),
                 'source_sha256':{str(p.relative_to(ROOT)):hashlib.sha256(p.read_bytes()).hexdigest() for p in (ROOT/'rtl').rglob('*') if p.suffix in ('.v','.sv')},
                 'records':records,'extraction_gaps':extraction_gaps,
                 'toggle_note':'Directional bins expanded from URG packed rows; raw toggle denominator counts covered bits, not directions.'}
        (args.out/(fifo+'_gap_ledger.json')).write_text(json.dumps(payload,indent=2)+'\n')
        result.append({k:v for k,v in payload.items() if k not in ('records','source_sha256')})
    (args.out/'summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()
