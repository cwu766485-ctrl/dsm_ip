"""Mapped area and timing are independent gates; architectural rate is explicit."""
import argparse
import hashlib
import json
from pathlib import Path
import re


def main():
    ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('run',type=Path)
    args=ap.parse_args();run=args.run
    def read(name):return (run/'reports'/name).read_text(errors='replace')
    area=read('area.rpt');setup=read('timing_setup.rpt');hold=read('timing_hold.rpt')
    def number(pattern,text):
        m=re.search(pattern,text,re.I);return float(m[1]) if m else None
    cell_area=number(r'Total cell area:\s*([\d.eE+-]+)',area)
    setup_slacks=[float(x) for x in re.findall(r'slack\s*\([^)]*\)\s*([\d.eE+-]+)',setup)]
    hold_slacks=[float(x) for x in re.findall(r'slack\s*\([^)]*\)\s*([\d.eE+-]+)',hold)]
    check_timing=read('check_timing.rpt');constraints=read('constraints.rpt')
    mapped=(run/'mapping_status.txt').read_text().strip()=='unmapped_cells=0'
    eqlog=run/'fm_shell.log';equivalence=eqlog.exists() and 'THERMO5_RTL_NETLIST_EQUIVALENCE_PASS' in eqlog.read_text(errors='replace')
    netlist=run/'netlist/thermo5_frozen_asic_syn.v'
    result={'mapping':'PASS' if mapped and netlist.is_file() else 'FAIL',
        'equivalence':'PASS' if equivalence else 'OPEN',
        'timing':'PASS' if setup_slacks and hold_slacks and min(setup_slacks)>=0 and min(hold_slacks)>=0 and 'VIOLATED' not in constraints else 'FAIL_OR_INCOMPLETE',
        'cell_area_library_units':cell_area,
        'cell_area_unit_basis':'TSMC library area attribute; confirm permitted library unit metadata before quoting square micrometres',
        'setup_slack_ns':min(setup_slacks) if setup_slacks else None,
        'hold_slack_ns':min(hold_slacks) if hold_slacks else None,
        'ideal_source_complex_samples_per_s':14*125e6,'ideal_core_input_complex_samples_per_s':8*218.75e6,
        'ideal_interpolated_complex_samples_per_s':32*218.75e6,
        'ideal_plane_code_bits_per_s':64*218.75e6,'ideal_all_plane_code_bits_per_s':4*64*218.75e6,
        'source_samples_per_s_per_area_unit':1.75e9/cell_area if cell_area else None,
        'rates_basis':'Architectural one accepted word per cycle without stalls; actual sustainable rate requires matching clock/ready duty and timing.',
        'netlist_sha256':hashlib.sha256(netlist.read_bytes()).hexdigest(),
        'limitations':['TT0.9V25C standard-cell pre-layout, ZeroWireload; no extracted parasitics/CTS/physical signoff',
                        'I/O budgets are IP assumptions; reset recovery/removal retained; inspect unconstrained endpoints and exceptions',
                        'Vectorless power is not measured power'],
        'check_timing':check_timing}
    (run/'de_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result))

if __name__=='__main__':main()
