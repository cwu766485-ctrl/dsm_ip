#!/usr/bin/env python3
"""Extract source-status and reset transitions from native CDC VCDs.

This diagnostic preserves failed checks. It never assigns waivers or PASS.
Waveforms stay in ignored runs/; only normalized observations are exported.
"""
import argparse
import hashlib
import json
from pathlib import Path

SIGNALS = {
    's_axil_aresetn', 's_axis_aresetn', 'core_aresetn',
    'tx_active_status_c', 'draining_status_c', 'core_enable',
    'core_tx_active_q', 'wr_gray_q', 'rd_gray_q',
    'prefill_ready_s', 'run_s2',
}
RESETS = {'s_axil_aresetn', 's_axis_aresetn', 'core_aresetn'}


def extract(text):
    names, values, transitions = {}, {}, []
    timestamp = 0
    timescale = None
    lines = iter(text.splitlines())
    for line in lines:
        parts = line.split()
        if line.startswith('$timescale'):
            scale = ' '.join(parts[1:]).replace('$end', '').strip()
            timescale = scale or next(lines).strip()
        elif line.startswith('$var') and len(parts) >= 6:
            if parts[4] in SIGNALS:
                names[parts[3]] = parts[4]
        elif line.startswith('#'):
            timestamp = int(line[1:])
        elif line and line[0] in '01xzXZ':
            code, value = line[1:].strip(), line[0].lower()
            if code in names and values.get(code) != value:
                transitions.append(dict(time=timestamp, signal=names[code], value=value))
                values[code] = value
        elif line.startswith('b') and len(parts) == 2:
            code, value = parts[1], parts[0][1:].lower()
            if code in names and values.get(code) != value:
                transitions.append(dict(time=timestamp, signal=names[code], value=value))
                values[code] = value
    reset_rows = [r for r in transitions if r['signal'] in RESETS]
    # Unknown or missing reset observations cannot establish reset inactivity.
    held = {r['signal'] for r in reset_rows} == RESETS and all(
        r['value'] == '1' for r in reset_rows)
    pulses = []
    for signal in ('tx_active_status_c', 'draining_status_c'):
        rows = [r for r in transitions if r['signal'] == signal]
        for previous, current in zip(rows, rows[1:]):
            # Initial level is not a bounded pulse; two edges are required.
            if previous['time'] > 0 and previous['value'] in ('0', '1') and current['value'] in ('0', '1'):
                pulses.append(dict(signal=signal, level=previous['value'],
                                   start=previous['time'], end=current['time'],
                                   duration=current['time']-previous['time']))
    return dict(timescale=timescale, all_resets_observed_held_released=held,
                transitions=transitions, bounded_status_pulses=pulses,
                disposition='OPEN_REQUIRES_PROTOCOL_REVIEW')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('vcd', nargs='+', type=Path)
    parser.add_argument('--output', required=True, type=Path)
    args = parser.parse_args()
    result = []
    for path in args.vcd:
        raw = path.read_bytes()
        result.append(dict(file=path.name, sha256=hashlib.sha256(raw).hexdigest(),
                           **extract(raw.decode())))
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n')


if __name__ == '__main__':
    main()
