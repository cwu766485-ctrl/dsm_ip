#!/usr/bin/env python3
"""Write the exact compile-time product VCS filelist used by the Linux run."""
import argparse
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--vivado-root', type=Path, required=True)
    args = parser.parse_args()
    entries = (ROOT / 'dv/uvm/sim/thermo5_sku_filelist.f').read_text().splitlines()
    lines = []
    for line in entries:
        if line.startswith('+incdir+'):
            lines.append('+incdir+' + str(ROOT / line[8:]))
        elif line.startswith('rtl/'):
            lines.append(str(ROOT / line))
    lines.append('+incdir+' + str(ROOT / 'dv/uvm/tests/thermo5_runtime'))
    for name in ('dv/uvm/agent/interfaces/thermo5_runtime_if.sv',
                 'dv/uvm/env/thermo5_runtime/thermo5_runtime_uvm_pkg.sv',
                 'dv/uvm/tb/thermo5_compiletime_uvm_tb.sv'):
        lines.append(str(ROOT / name))
    for name in ('xpm_cdc', 'xpm_memory', 'xpm_fifo'):
        lines.append(str(args.vivado_root / 'data/ip/xpm' / name / 'hdl' / (name + '.sv')))
    lines.append(str(args.vivado_root / 'data/verilog/src/glbl.v'))
    args.output.write_text('\n'.join(lines) + '\n')


if __name__ == '__main__':
    main()
