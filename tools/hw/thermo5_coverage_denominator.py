"""Export raw URG instance denominators and exact red line/branch records.

No exclusions are applied. Missing metric sections fail the inventory gates.
"""
import argparse
from collections import Counter
import html
import importlib.util
import json
from pathlib import Path
import re

import thermo5_audit_reports as audit

ROOT = Path(__file__).resolve().parents[2]
spec = importlib.util.spec_from_file_location(
    'frozen', ROOT / 'dv/uvm/sim/run_thermo5_frozen_regression.py')
frozen = importlib.util.module_from_spec(spec)
spec.loader.exec_module(frozen)


def clean(value):
    return html.unescape(re.sub(r'<[^>]+>', '', value)).strip()


def disposition(instance, metric, line, statement=''):
    if audit.ownership(instance) == 'VENDOR_XPM':
        return 'OPEN_VENDOR_BIN_REVIEW'
    if 'u_interp_' in instance:
        if metric == 'line' and 178 <= line <= 191:
            return 'FIXED_INTERP_TAPS2_ALTERNATE_IMPLEMENTATION'
        if metric == 'line' and line in (214, 215):
            return 'FIXED_HISTORY1_LESS_THAN_LANES'
        if line in (91, 92):
            return 'PROOF_INTERP2_CONVEX_AVERAGE_NO_SATURATION'
        if line in (76,77):
            return 'FIXED_LEGAL_PARAMETER_ERROR_ARM'
        if metric == 'branch' and line == 100:
            return 'FIXED_HOLD_STATE_ON_DISABLE0_ELSE_ARM'
    if 'u_dpd' in instance:
        if '.u_sat_' in instance:
            return 'PROOF_IDENTITY_NO_SATURATION'
        if line in (337, 336) or metric == 'branch' and line == 198:
            return 'PROOF_IDENTITY_NO_SATURATION'
        if metric == 'line':
            if line in (237,238,239,241,242):
                return 'FIXED_EXTERNAL_TAPS1_INTERNAL_INPUT_PATH'
            return 'FIXED_DPD_TAPS1_HISTORY_OR_UNUSED_PAIR1'
    if 'u_memory_dpd' in instance:
        if metric=='line' and line in (56,57,75,76):
            return 'FIXED_DPD_TAPS1_VECTOR_HISTORY_UNUSED'
    if 'u_frame_gain' in instance:
        if metric=='branch' and line==64:
            return 'FIXED_HOLD_STATE_ON_DISABLE0_ELSE_ARM'
        if line in (57,58):
            return 'OPEN_LEGAL_GAIN_MAGNITUDE_SATURATION'
    if instance.endswith('.u_cdc'):
        return 'OPEN_FORMAL_RESIDUAL_CORRUPTION_DEFAULT'
    if 'u_bridge' in instance or '.u_tid' in instance:
        return 'REVIEW_FIXED_LEGAL_PARAMETER_ERROR_ARM'
    return 'OPEN_PROJECT_BIN_REVIEW'


def inventory(report):
    denominators, lines, branches = [], [], []
    for path in sorted(report.glob('mod*.html')):
        page = path.read_text(errors='replace')
        for tag_name,block,single in audit.instance_blocks(page):
            name = re.search(r'(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>', block, re.S)
            if not name or not clean(name[1]).startswith('thermo5_sku_uvm_tb.dut'):
                continue
            instance = clean(name[1])
            for metric, label in (('Line', 'TOTAL'), ('Cond', 'Conditions'),
                                  ('Toggle', 'Total Bits'), ('Branch', 'Branches')):
                prefix='' if single else tag_name+'_'
                anchor = re.search(r'<a name="'+prefix+metric+r'"></a>', block)
                if not anchor:
                    continue
                section = block[anchor.end():]
                next_metric=re.search(r'<a name="(?:'+prefix+r')(?:Line|Cond|Toggle|Branch|Fsm|FSM|Assert)"></a>',section)
                if next_metric: section=section[:next_metric.start()]
                parser = frozen.TableRows()
                parser.feed(section)
                summary = next((r for r in parser.rows if r and r[0] == label), None)
                if summary is None:
                    raise RuntimeError(f'Missing {metric} denominator: {instance}')
                cells = summary[2:4] if metric in ('Line', 'Branch') else summary[1:3]
                total, covered = map(int, cells)
                denominators.append(dict(instance=instance, ownership=audit.ownership(instance),
                    metric=metric.lower(), total=total, covered=covered, missing=total-covered))
                if metric == 'Line':
                    code = re.search(r'<pre class="code">(.*?)</pre>', section, re.S)
                    if not code:
                        split_source=re.search(r'href="([^"]+_l\d+\.html)"',section)
                        if split_source:
                            source_page=(report/split_source[1]).read_text(errors='replace')
                            code=re.search(r'<pre class="code">(.*?)</pre>',source_page,re.S)
                    if not code:
                        raise RuntimeError(f'Missing line detail: {instance}')
                    # Macro headers aggregate the expanded bins below. Count
                    # expanded lines only, preserving dotted source locations.
                    source_code=re.sub(r'<span onclick=.*?</span>', '', code[1], flags=re.S)
                    for raw in clean(source_code).splitlines():
                        match = re.match(r'^\s*(\d+(?:\.\d+)?)\s+(\d+)/(\d+)\s*(?:==>\s*)?(.*)$', raw)
                        if not match or int(match[2]) == int(match[3]):
                            continue
                        line, hits, bins, statement = match.groups()
                        source_line=int(line.split('.')[0])
                        lines.append(dict(instance=instance, ownership=audit.ownership(instance),
                            line=line, covered=int(hits), total=int(bins),
                            missing=int(bins)-int(hits), statement=statement,
                            disposition=disposition(instance, 'line', source_line, statement)))
                if metric == 'Branch':
                    # URG reports chained IF arms at the first line. Preserve
                    # the actual decision vector; a missing arm is never a hit.
                    pattern = r'<td>(?:IF|CASE)</td>\s*<td class="rt">(\d+)</td>\s*<td class="rt">(\d+)</td>\s*<td class="rt">(\d+)</td>'
                    summary_lines = [int(m[0]) for m in re.findall(pattern, section)]
                    details = list(re.finditer(r'<pre class="code">(.*?)</pre>\s*<br clear=all>\s*<span class=repname>Branches:</span>\s*<br clear=all>\s*<table.*?</table>', section, re.S))
                    for number, detail in enumerate(details):
                        if number >= len(summary_lines):
                            raise RuntimeError(f'Unmatched branch detail: {instance}')
                        code = detail[1]
                        predicates = []
                        code_lines = code.splitlines()
                        for j, raw in enumerate(code_lines):
                            marker = re.search(r'<font color = "(?:green|red)">-(\d+)-</font>', raw)
                            if marker:
                                predicates.append(f'{marker[1]}:{clean(code_lines[j-1])}')
                        for row in re.findall(r'<tr class="uRed">(.*?)</tr>', detail[0], re.S):
                            cells = [clean(c) for c in re.findall(r'<td[^>]*>(.*?)</td>', row, re.S)]
                            line = summary_lines[number]
                            branches.append(dict(instance=instance, ownership=audit.ownership(instance),
                                line=line, decisions='/'.join(cells[:-1]), predicates='; '.join(predicates),
                                status=cells[-1], disposition=disposition(instance, 'branch', line)))
    if not denominators or not lines or not branches:
        raise RuntimeError('Incomplete denominator/line/branch inventory')
    # Ensure no raw line bin disappeared during extraction.
    if sum(r['missing'] for r in lines) != sum(r['missing'] for r in denominators if r['metric']=='line'):
        by_detail=Counter()
        for r in lines: by_detail[r['instance']]+=r['missing']
        errors=[(r['instance'],r['missing'],by_detail[r['instance']]) for r in denominators
                if r['metric']=='line' and r['missing']!=by_detail[r['instance']]]
        raise RuntimeError(f'Line gap detail does not reconcile with denominator: {errors}')
    if len(branches) != sum(r['missing'] for r in denominators if r['metric']=='branch'):
        raise RuntimeError('Branch arm detail does not reconcile with denominator')
    return denominators, lines, branches


def fsm_inventory(report):
    rows=[]
    for path in sorted(report.glob('mod*.html')):
        for tag_name,block,single in audit.instance_blocks(path.read_text(errors='replace')):
            name=re.search(r'(?:Module Instance|\w+ Coverage for Instance)\s*:\s*<a[^>]*>(.*?)</a>',block,re.S)
            if not name or not clean(name[1]).startswith('thermo5_sku_uvm_tb.dut'): continue
            instance=clean(name[1]); prefix='' if single else tag_name+'_'
            anchor=re.search(r'<a name="'+prefix+r'FSM"></a>',block)
            if not anchor: continue
            section=block[anchor.end():]
            for fsm,table in re.findall(r'<caption><b>Summary for FSM :: (.*?)</b></caption>(.*?)</table>',section,re.S):
                parser=frozen.TableRows(); parser.feed('<table>'+table+'</table>')
                for row in parser.rows:
                    if row and row[0] in ('States','Transitions','Sequences'):
                        total,covered=map(int,row[1:3])
                        rows.append(dict(instance=instance,ownership=audit.ownership(instance),fsm=clean(fsm),
                            metric=row[0].lower(),total=total,covered=covered,missing=total-covered))
    return rows


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('report', type=Path)
    ap.add_argument('out', type=Path)
    args = ap.parse_args()
    args.out.mkdir(parents=True, exist_ok=True)
    totals, lines, branches = inventory(args.report)
    for name, rows in (('denominators', totals), ('line_gaps', lines), ('branch_arms', branches)):
        audit.write_csv(args.out/(name+'.csv'), list(rows[0]), rows)
    fsms=fsm_inventory(args.report)
    if fsms: audit.write_csv(args.out/'fsm_denominators.csv',list(fsms[0]),fsms)
    assertions=audit.assertion_rows(args.report/'asserts.html')
    if assertions: audit.write_csv(args.out/'assertions.csv',list(assertions[0]),assertions)
    dut_assertions=[r for r in assertions if r['assertion'].startswith('thermo5_sku_uvm_tb.dut')]
    summary = {'raw_dut': frozen.parse_dut_code_coverage(args.report/'hierarchy.html'),
               'exclusions_applied': False, 'metrics': [],
               'line_gap_dispositions': dict(Counter(r['disposition'] for r in lines)),
               'branch_gap_dispositions': dict(Counter(r['disposition'] for r in branches)),
               'fsm_denominators':fsms,
               'assertion_status_counts':dict(Counter(r['status'] for r in assertions)),
               'dut_assertion_status_counts':dict(Counter(r['status'] for r in dut_assertions)),
               'expected_negative_assertions':[r for r in dut_assertions if r['status']=='FAILURE']}
    for owner in ('PROJECT_RTL', 'VENDOR_XPM'):
        for metric in ('line','cond','toggle','branch'):
            records = [r for r in totals if r['ownership']==owner and r['metric']==metric]
            total = sum(r['total'] for r in records)
            covered = sum(r['covered'] for r in records)
            summary['metrics'].append(dict(ownership=owner, metric=metric, total=total,
                covered=covered, missing=total-covered,
                percent=round(100*covered/total,4) if total else None))
    (args.out/'summary.json').write_text(json.dumps(summary,indent=2)+'\n')
    print(json.dumps(summary))


if __name__ == '__main__':
    main()
