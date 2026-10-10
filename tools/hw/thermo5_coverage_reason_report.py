"""Audit every missing bin and compute explicitly scoped candidate metrics.

This never modifies a VDB, applies URG exclusions, or turns a proof into a hit.
Reachable counters and unreviewed vendor/proof-transfer bins stay in denominator.
"""
import argparse
from collections import Counter
import csv
import hashlib
import html
import json
from pathlib import Path
import re

from thermo5_coverage_denominator import inventory

ROOT = Path(__file__).resolve().parents[2]


def digest(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def fsm_gaps(report, ledger):
    """Resolve aggregate missing FSM counts to the saved URG transitions."""
    rows = []
    for record in ledger['records']:
        if record['metric'] != 'fsm':
            continue
        raw = record['raw']
        assert raw['metric'] == 'transitions'
        found = []
        for path in sorted(report.glob('mod*.html')):
            page = path.read_text(errors='replace')
            marker = 'State, Transition and Sequence Details for FSM :: ' + raw['fsm']
            if marker not in page:
                continue
            section = page.split(marker, 1)[1]
            tables = re.findall(r'<table\b[^>]*>.*?</table>', section, re.S)
            table = next(t for t in tables if '>transitions</td>' in t)
            for row in re.findall(r'<tr class="uRed">(.*?)</tr>', table, re.S):
                cells = [html.unescape(re.sub(r'<[^>]+>', '', c)).strip()
                         for c in re.findall(r'<td\b[^>]*>(.*?)</td>', row, re.S)]
                assert cells[2].replace('\xa0', ' ') == 'Not Covered'
                found.append(dict(instance=record['instance'], fsm=raw['fsm'],
                                  transition=cells[0], line=cells[1], category='OPEN_VENDOR',
                                  report_file=path.name, report_sha256=digest(path),
                                  reason='Exact unhit URG transition; legal trigger and proof remain OPEN.'))
        assert len(found) == raw['missing'], (raw['fsm'], len(found), raw['missing'])
        rows.extend(found)
    return rows


def reason(row):
    key, hint, inst = row['bin'], row['evidence_hint'], row['instance']
    if row['status'] == 'OPEN_VENDOR':
        return ('OPEN_VENDOR', 'Vendor source is in this denominator. Optional features, '
                'reset sequencing and FSM transitions have not been individually proven; '
                'vendor ownership alone is not an exclusion.', [])
    if row['status'] == 'OPEN_XPM_PROOF_TRANSFER':
        return ('OPEN_XPM_PROOF_TRANSFER', 'Generic FIFO proof does not establish this XPM '
                'instance. Requires a real-XPM proof or a separately validated compositional contract.', [])
    if 'sample_count[' in key:
        bit = int(re.search(r'sample_count\[(\d+)\]', key)[1])
        return ('OPEN_REACHABLE_COUNTER', f'Bit{bit} first rises after {2**bit} accepted '
                f'DPD vector words since reset. First natural fall needs {2**(bit+1)}; '
                'public reset can supply a fall after a rise. Existing stream checks16387 '
                'words. Full-width carry/hold proof is not a URG toggle hit.',
                ['rtl/dpd/dpd_memory_poly.v', 'dv/uvm/formal/thermo5_gap_harness.sv'])
    # Fixed coefficient ports are configuration evidence, not saturation evidence.
    if row['metric'] == 'toggle' and re.search(r':(?:dpd_active_taps|active_taps|c[135]_(?:re|im))\[', key):
        return ('CONFIGURATION', 'TB fixes active_taps=1, c1_re=16384, and all other '
                'coefficients=0 throughout the run. These ports cannot change without '
                'changing the frozen SKU stimulus contract.', ['dv/uvm/tb/thermo5_sku_uvm_tb.sv'])
    if row['status'] == 'ARITHMETIC_PROOF_AND_EXHAUSTIVE_RTL':
        return ('ANALYTICAL_IDENTITY', 'With one enabled tap, gain_re=16384, gain_im=0; '
                'term=(signed16_input*16384)>>>14 is the input, or zero for a disabled '
                'slot. Pair1=0. Thus signed64 sum stays in [-32768,32767]; neither '
                'saturator arm nor sat/saturation_count can assert. Stalls hold state. '
                'Exhaustive scalar-input RTL evidence corroborates the algebra; the '
                'full sequential arithmetic FPV experiment remains inconclusive.',
                ['rtl/dpd/dpd_memory_poly.v', 'rtl/dpd/dpd_poly.v',
                 'dv/verif/block/dpd/tb/tb_dpd_identity_exhaustive.sv'])
    if row['status'] == 'ARITHMETIC_INTERVAL_PROOF':
        return ('ANALYTICAL_INTERPOLATION', 'INTERP_TAPS=2 selects8192*x+8192*y. '
                'After Q14 rounding, its range is [-32768,32767]. Both saturation '
                'arms are unreachable for signed16 inputs; this is an interval '
                'argument, not a completed sequential FPV proof.',
                ['rtl/interp/dsm_interp_x2_polyphase_vector.sv'])
    if 'HOLD_STATE_ON_DISABLE0' in hint:
        return ('CONFIGURATION', 'ENABLE_LOW_POWER_CTRL=0 propagates HOLD_STATE_ON_DISABLE=0. '
                'The branch requires !HOLD_STATE_ON_DISABLE=0, a constant contradiction.',
                ['rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv'])
    if 'LEGAL_PARAMETER_ERROR' in hint:
        return ('CONFIGURATION', 'Legal elaboration: INTERP_TAPS=2, CHANNELS=32, '
                'VALID_BANKS=8, PARALLEL_W=GT_USER_W=64. The parameter-error arm '
                'requires violating one of these values.',
                ['dv/uvm/tb/thermo5_sku_uvm_tb.sv', 'rtl/gt/gt_tx_user_bridge.sv',
                 'rtl/tx_bandpass_if/tid32_cartesian_fs4_gt_tx.sv'])
    if 'INTERP_TAPS2_ALTERNATE' in hint or 'HISTORY1_LESS' in hint:
        return ('CONFIGURATION', 'INTERP_TAPS=2 removes the3/4-tap branches. '
                'HISTORY=INTERP_TAPS-1=1 is less than LANES_IN(8 or16), '
                'so history[h-LANES_IN] is never selected.',
                ['rtl/interp/dsm_interp_x2_polyphase_vector.sv'])
    if any(x in hint for x in ('EXTERNAL_TAPS1', 'TAPS1_HISTORY', 'VECTOR_HISTORY', 'MAX_TAPS1')):
        return ('CONFIGURATION', 'MAX_TAPS=1: comb_tap=0 always satisfies '
                'comb_tap<(MAX_TAPS+1)/2=1, pair1 is zero; loops tap<MAX_TAPS-1 '
                'or1<=tap<MAX_TAPS-1 are empty. USE_EXTERNAL_TAPS=1 bypasses internal '
                'input/history selection; vector tap=0 always satisfies tap<=lane. '
                'Vector HISTORY=1<LANES=16.',
                ['rtl/dpd/dpd_memory_poly.v', 'rtl/dpd/dpd_vector16_memory_poly.sv'])
    if row['status'] == 'CONFIGURATION_PROOF':
        if 'LOW_POWER' in hint or 'CORE_DRAIN' in hint or re.search(r':(?:core_drain|lp_)', key):
            return ('CONFIGURATION', 'ENABLE_LOW_POWER_CTRL=0 fixes lp_state/outstanding '
                    'and datapath/ingress controls; core_drain=ENABLE_LOW_POWER_CTRL '
                    '&& state_is_drain is always0. Opposite operand/toggle is impossible.',
                    ['rtl/tx_bandpass_if/tid32_thermo5_axis_frontend_tx.sv'])
        raise RuntimeError('No precise configuration argument for '+row['bin_id'])
    if row['status'] == 'SCOPED_FORMAL_PROVEN':
        if 'u_reset' in inst or inst.endswith(('.u_s_reset', '.u_c_reset')):
            return ('SCOPED_RESET', '!arst_n && sync_q[0] is uncoverable after falling-edge '
                    'runtime reset settles. Three nonvacuous assertions/four normal covers. '
                    'Same-active-edge scheduling and analog metastability are outside scope.',
                    ['rtl/axis/dsm_reset_sync.sv', 'dv/uvm/formal/thermo5_gap_harness.sv'])
        return ('SCOPED_GENERIC_CDC', 'Production generic CDC proves residual in '
                '{0,2,4,6,8,10,12}, unused residual bits223:192 zero and frame_marker '
                'implies out_valid; nine operating covers. Integrated core_enable=0 '
                'also makes frontend in_ready=0. Exact7:4 clock/reset model; '
                'no XPM or analog-reset transfer inferred.',
                ['rtl/axis/dsm_axis14_to_core8_cdc.sv', 'dv/uvm/formal/thermo5_gap_harness.sv'])
    raise RuntimeError('Unreviewed record '+row['bin_id'])


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('evidence', type=Path)
    ap.add_argument('out', type=Path)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    package = json.loads((args.evidence/'dv_package.json').read_text())
    assert package['status'] == 'PASS' and not package['errors']
    assert package['source']['rtl_dv_source_sha256'] == package['source_after']['rtl_dv_source_sha256']
    manifest = json.loads((args.evidence/'formal/formal_summary.json').read_text())
    assert manifest['status'] == 'PASS'
    assert all(digest(ROOT/p) == h for p,h in manifest['source_sha256'].items())
    assert {j['kind'] for j in manifest['jobs']} == {'reset','counter','counter_unbounded','cdc_residual'}
    for job in manifest['jobs']:
        assert job['status'] == 'PASS' and job['black_box_instances'] == ['0']
        assert all(a[0] == 'proven' for a in job['assertions'])
        assert all(c[0] == ('uncoverable' if c[1].endswith('c_collision_bin') else 'covered')
                   for c in job['covers'])
    closure = json.loads((args.evidence/'coverage/closure.json').read_text())
    counter_plan = []
    for test in closure['directed']:
        if test['golden_words'] != 16387:
            continue
        seconds_per_word = test['command']['duration_seconds']/16387
        for bit in range(15,32):
            counter_plan.append(dict(fifo=test['fifo'], bit=bit,
                                     accepted_words_for_first_rise=2**bit,
                                     accepted_words_for_natural_fall=2**(bit+1),
                                     ideal_min_hardware_seconds=2**bit/218.75e6,
                                     estimated_simulation_days_to_first_rise=seconds_per_word*2**bit/86400,
                                     basis='Linear extrapolation of measured long-stream wall time, not an executed result.',
                                     legal_checker='Extend independently generated payload/oracle; check all16 counts then public reset for fall.'))
    with (args.out/'reachable_counter_plan.csv').open('w', newline='', encoding='utf-8') as f:
        writer=csv.DictWriter(f, fieldnames=list(counter_plan[0]));writer.writeheader();writer.writerows(counter_plan)
    output = []
    for fifo in ('generic', 'xpm'):
        ledger = json.loads((args.evidence/'ledger'/f'{fifo}_gap_ledger.json').read_text())
        assert not ledger['extraction_gaps'] and not ledger['exclusions_applied']
        assert all(digest(ROOT/p) == h for p,h in ledger['source_sha256'].items())
        rows = []
        for row in ledger['records']:
            category, explanation, paths = reason(row)
            raw = row['raw']
            # Retain the actual unhit code/condition/signal from the saved URG
            # extraction. Vendor rows have report provenance, not project hashes.
            detail = raw.get('statement') or raw.get('expression') or raw.get('predicates')
            if not detail:
                detail = raw.get('signal') or raw.get('fsm') or ''
            rows.append(dict(bin_id=row['bin_id'], instance=row['instance'], metric=row['metric'],
                             bin=row['bin'], category=category, reason=explanation,
                             source=';'.join(paths), source_sha256=';'.join(digest(ROOT/p) for p in paths),
                             urg_detail=detail, urg_module_report=raw.get('module_file', '')))
        totals, _, _ = inventory(args.evidence/'coverage/baseline'/fifo/'coverage_after')
        metrics = []
        for metric in ('line','cond','branch','toggle'):
            total = sum(x['total'] for x in totals if x['metric'] == metric)
            covered = sum(x['covered'] for x in totals if x['metric'] == metric)
            missing = [x for x in rows if x['metric'] == metric]
            assert len(missing) == total-covered, (fifo, metric, len(missing), total-covered)
            # Candidate analytical/parameter/scoped disposition only. Actual URG is unchanged.
            justified = sum(not x['category'].startswith('OPEN') for x in missing)
            remaining = total-covered-justified
            metrics.append(dict(metric=metric, raw_total=total, raw_covered=covered,
                                candidate_disposition_bins=justified, remaining_open=remaining,
                                candidate_adjusted_percent=100*covered/(total-justified)))
        with (args.out/f'{fifo}_reasons.csv').open('w', newline='', encoding='utf-8') as f:
            writer = csv.DictWriter(f, fieldnames=list(rows[0])); writer.writeheader(); writer.writerows(rows)
        raw = next(x['after_dut'] for x in closure['fifo_reports'] if x['fifo']==fifo)
        transitions = fsm_gaps(args.evidence/'coverage/baseline'/fifo/'coverage_after', ledger)
        if transitions:
            with (args.out/f'{fifo}_fsm_gaps.csv').open('w', newline='', encoding='utf-8') as f:
                writer = csv.DictWriter(f, fieldnames=list(transitions[0]))
                writer.writeheader(); writer.writerows(transitions)
        output.append(dict(fifo=fifo, raw_urg=raw, reasons_complete=True, metrics=metrics,
                           reason_counts=dict(Counter(x['category'] for x in rows)),
                           exact_open_fsm_transitions=len(transitions),
                           full_code_coverage_100=False))
    result = dict(urg_exclusions_applied=False, status='AUDITED_OPEN',
                  basis='Candidate analytical/configuration/scoped adjustment; not an URG report or exclusion signoff.',
                  ci_commit=package['source']['git_commit'],
                  evidence_sha256={str(p.relative_to(args.evidence)):digest(p) for p in
                                   (args.evidence/'dv_package.json',args.evidence/'coverage/closure.json',
                                    args.evidence/'formal/formal_summary.json')}, results=output)
    (args.out/'summary.json').write_text(json.dumps(result, indent=2)+'\n')
    lines=['# Frozen thermo5 exact missing-bin reasons', '', result['basis'], '',
           'Reachable high counters and OPEN vendor/proof-transfer records remain in the denominator.', '',
           '| FIFO | Metric | Raw covered/total | Candidate disposition | Remaining OPEN | Candidate adjusted % |',
           '| --- | --- | ---: | ---: | ---: | ---: |']
    for item in output:
        for m in item['metrics']:
            lines.append(f"| {item['fifo']} | {m['metric']} | {m['raw_covered']}/{m['raw_total']} | "
                         f"{m['candidate_disposition_bins']} | {m['remaining_open']} | {m['candidate_adjusted_percent']:.4f} |")
    lines += ['', 'All missing rows retain URG code/condition/signal details, a reason and an explicit OPEN or scoped analytical disposition.',
              'Project dispositions include source/hash. OPEN vendor and proof-transfer rows retain saved-ledger provenance; no vendor source hash is invented.',
              'Vendor FSM aggregates reconcile to exact transitions in the FSM CSV; their legal trigger/proof review remains OPEN.',
              'No force/deposit, shortened production counter, VDB rewrite, or artificial race stimulus is used.']
    (args.out/'summary.md').write_text('\n'.join(lines)+'\n')
    print(json.dumps(result))


if __name__ == '__main__':
    main()
