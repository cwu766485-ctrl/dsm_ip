"""Validate same-build closure, exact counter/TID bins, and raw denominators."""
import argparse
import csv
import json
from pathlib import Path

from thermo5_coverage_denominator import inventory, frozen


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('closure_dir',type=Path)
    args=ap.parse_args()
    manifest=json.loads((args.closure_dir/'closure.json').read_text())
    assert manifest['status']=='PASS' and not manifest['errors']
    assert len(manifest['directed'])==10, 'Expect five directed tests per FIFO'
    results=[]
    for fifo in ('generic','xpm'):
        report=next(r for r in manifest['fifo_reports'] if r['fifo']==fifo)
        # Manifest paths are recorded by Rocky. Locate their outputs locally.
        build=args.closure_dir/'baseline'/fifo
        assert report['tid_bits_before']==162 and report['tid_bits_hit_both']==162
        with (build/'toggle_bit_delta.csv').open(newline='') as stream:
            rows=list(csv.DictReader(stream))
        counter_rows=[r for r in rows if r['signal'].startswith('sample_count[') and '.u_dpd' in r['instance']]
        for bit in range(5,15):
            bits=[r for r in counter_rows if r['signal']==f'sample_count[{bit}]']
            assert len(bits)==16 and all(r['status']=='HIT_BOTH_DIRECTIONS' for r in bits), (fifo,bit)
        for bit in range(15,32):
            bits=[r for r in counter_rows if r['signal']==f'sample_count[{bit}]']
            assert len(bits)==16 and all(r['after_1_to_0']=='No' and r['after_0_to_1']=='No' for r in bits), (fifo,bit)
        records=[r for r in manifest['directed'] if r['fifo']==fifo]
        assert len({r['simv_sha256'] for r in records})==1
        for record in records:
            log=build/Path(record['log']).name
            content=log.read_text(errors='replace')
            assert 'UVM_ERROR :    0' in content and 'UVM_FATAL :    0' in content
            if record['test']=='thermo5_sku_long_counter_test':
                assert 'source=9364 output=16387' in content
                assert 'THERMO5_LONG_COUNTER_RESET_PASS' in content
        totals,lines,arms=inventory(build/'coverage_after')
        metrics=frozen.parse_dut_code_coverage(build/'coverage_after/hierarchy.html')
        assert not any('u_frame_gain' in r['instance'] and r['line'] in ('57','58') for r in lines)
        results.append(dict(fifo=fifo,raw_dut=metrics,line_missing=sum(r['missing'] for r in lines),
                            branch_missing=len(arms),tid_both=162,counter_bits5_to14_both_all16=True))
    output={'status':'PASS','exclusions_applied':False,'results':results}
    (args.closure_dir/'closure_validation.json').write_text(json.dumps(output,indent=2)+'\n')
    print(json.dumps(output))


if __name__=='__main__': main()
