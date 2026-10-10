"""Run actual-vendor scoped XPM proofs with complete source provenance.

Run in the licensed Linux environment. A partial transition proof is OPEN.
"""
import argparse, hashlib, json, os, re, subprocess
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def main():
    ap = argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--scope', choices=('reset_defaults', 'fwft_transition'), required=True)
    ap.add_argument('--xpm-root', type=Path, required=True)
    ap.add_argument('--out', type=Path, required=True)
    args = ap.parse_args()
    out = args.out.resolve()
    assert ROOT / 'runs' in out.parents and not out.exists()
    top = 'thermo5_xpm_' + args.scope
    sources = [ROOT / 'tools/hw' / (top + '.sv')]
    if args.scope == 'fwft_transition':
        sources += [ROOT / 'rtl/axis' / n for n in
                    ('dsm_reset_sync.sv', 'dsm_async_fifo.sv', 'dsm_xpm_async_fifo.sv')]
    sources += [args.xpm_root.resolve() / 'data/ip/xpm' / n / 'hdl' / (n + '.sv')
                for n in ('xpm_cdc', 'xpm_memory', 'xpm_fifo')]
    assert all(p.is_file() for p in sources)
    out.mkdir(parents=True)
    tcl = out / 'run.tcl'
    tcl.write_text('''set_fml_appmode FPV
fv_setup_config -check reset -disable
fv_setup_config -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -enable -severity error
read_file -top ''' + top + ' -format sverilog -sva -vcs [list ' +
                   ' '.join('{' + str(p) + '}' for p in sources) + ''' -assert svaext]
create_clock wr_clk -period 14
create_clock rd_clk -period 8
create_reset boot_n -sense low
''' + ('sim_run 40\n' if args.scope == 'fwft_transition' else '') + '''sim_run -stable
sim_save_reset
set_fml_var fml_coi_reduction true
set_fml_var fml_max_time 3m
set_fml_var fml_property_time_limit 2m
set_fml_var fml_max_mem 8GB
set_fml_var fml_cov_gen_trace on
check_fv_setup -check {clock comb_loop glitch multi_driver osc_loop osc_seq} -block
report_fv_setup -list > setup.txt
check_fv -block
report_fv -list > properties.txt
''', newline='\n')
    hashes = {str(p): sha(p) for p in [*sources, tcl, Path(__file__).resolve()]}
    command = ['vcf', '-batch', '-fmode', 'FPV', '-f', str(tcl)]
    with (out / 'console.log').open('w') as log:
        code = subprocess.call(command, cwd=out, env=os.environ.copy(), stdout=log, stderr=subprocess.STDOUT)
    text = (out / 'properties.txt').read_text() if (out / 'properties.txt').exists() else ''
    properties = re.findall(r'\[\s*\d+\]\s+(proven|covered|inconclusive(?:\(depth=\d+\))?|falsified)\s+(?:\(non_vacuous\)\s+)?-\s+(\S+)', text)
    setup = (out / 'setup.txt').read_text() if (out / 'setup.txt').exists() else ''
    console = (out / 'console.log').read_text()
    clean = (code == 0 and bool(setup) and not re.search(r':\s+[1-9]\d*\s*$', setup, re.M)
             and bool(re.search(r'Number of Black-Box Instances\s*=\s*0', console))
             and all(sha(Path(p)) == h for p, h in hashes.items()))
    proven = [name for status, name in properties if status == 'proven']
    covers = [name for status, name in properties if status == 'covered']
    full = clean and ((len(proven) == 3 and len(covers) == 3) if args.scope == 'reset_defaults'
                      else len(proven) == 2 and len(covers) == 2)
    manifest = dict(status='PASS' if full else 'FAIL_OR_INCONCLUSIVE', exit_code=code,
                    command=command, source_sha256=hashes,
                    sources_unchanged=all(sha(Path(p)) == h for p, h in hashes.items()),
                    proven_properties=proven, covered_properties=covers, setup_clean=clean,
                    tool_version_lines=[line for line in console.splitlines() if 'Version' in line][:5],
                    scope='Actual installed vendor RTL; independent clocks 14:8, inactive-edge public reset. No assumed DUT state.')
    (out / 'manifest.json').write_text(json.dumps(manifest, indent=2) + '\n')
    print(json.dumps(manifest), flush=True)
    return 0 if clean and (full or top + '.a_fwft_legal' in proven) else 1


if __name__ == '__main__':
    raise SystemExit(main())
