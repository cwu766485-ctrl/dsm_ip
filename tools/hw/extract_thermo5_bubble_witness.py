#!/usr/bin/env python3
"""Extract pre-edge signal evidence from an unoptimized hierarchy VCD."""
import argparse
import csv
from pathlib import Path


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('vcd',type=Path);ap.add_argument('--time-ps',type=int,default=1360170)
    ap.add_argument('--out',type=Path,required=True);a=ap.parse_args()
    scopes=[];names={};values={};header=True
    with a.vcd.open() as stream:
        for line in stream:
            f=line.split()
            if not f:continue
            if header:
                if f[0]=='$scope':scopes.append(f[2])
                elif f[0]=='$upscope':scopes.pop()
                elif f[0]=='$var':names['.'.join(scopes+[f[4]])]=f[3]
                elif f[0]=='$enddefinitions':header=False
            elif line.startswith('#'):
                # Values immediately before this edge match a posedge monitor's
                # observations before the DUT nonblocking assignments commit.
                if int(line[1:])>=a.time_ps:break
            elif line[0] in 'bB':
                value,symbol=line[1:].split();values[symbol]=value
            elif line[0] in '01xXzZ':values[line[1:].strip()]=line[0]
    base='thermo5_sku_uvm_tb.';interp=base+'dut.u_frontend.g_interp2_centered.u_interp_2.'
    selected=[base+'bus.pa_valid',base+'bus.pa_ready']
    selected += [interp+n for n in ('q_count','q0_tail','q0_end','in_valid','in_ready','out_valid','out_ready')]
    selected += [base+'dut.u_frontend.u_interp2_to_tid_fifo.'+n for n in ('count_q','in_valid','in_ready','out_valid','out_ready')]
    with a.out.open('w',newline='') as out:
        w=csv.DictWriter(out,fieldnames=('sample_edge_ps','phase','signal','binary','integer'));w.writeheader()
        for name in selected:
            value=values[names[name]]
            w.writerow(dict(sample_edge_ps=a.time_ps,phase='pre-edge',signal=name,binary=value,integer=int(value,2)))
    if values[names[interp+'q_count']]!='10':raise ValueError('Witness does not show the directly sampled two-entry queue')
    print('BUBBLE_VCD_WITNESS_PASS '+str(a.out))

if __name__=='__main__':main()
