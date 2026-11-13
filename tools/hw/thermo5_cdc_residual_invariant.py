#!/usr/bin/env python3.12
"""Exhaust the control abstraction of the frozen 14:8 gearbox.

This is a source-reviewed finite-state proof, not an RTL formal tool result.
FIFO timing is overapproximated: any next beat may be available or delayed.
Enable, backpressure, drain and common reset may occur in every state.
Frame ends may occur at any positive multiple of 32 accepted source beats.
"""
import argparse
import hashlib
import json
from collections import deque
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / 'rtl/axis/dsm_axis14_to_core8_cdc.sv'


def explore(legal=True):
    # phase = number of FIFO beats consumed modulo 32; all FIFO beats ordered.
    initial = (0, 0, False, 0, False)
    seen = {initial}
    todo = deque([initial])
    transitions = 0
    end_values = set()
    witnesses = []
    while todo:
        state = todo.popleft()
        phase, rem, pending, remaining, valid = state
        end_values.add(remaining)
        if legal:
            assert rem in (0, 2, 4, 6, 8, 10, 12)
            assert remaining in (0, 8)
            assert not pending or (rem == remaining == 8)
        # Reset at any point; disable/blocked output holds every register.
        successors = {initial, state}
        # advance = enable && (!out_valid || ready); all false cases hold.
        if rem >= 8:
            if pending and remaining > 8:
                witnesses.append(dict(state=state, target='line151'))
            successors.add((phase, rem-8, False if pending and remaining <= 8 else pending,
                            0 if pending and remaining <= 8 else remaining-8 if pending else remaining,
                            True))
        else:
            successors.add((phase, rem, pending, remaining, False))  # FIFO unavailable
            for last in ((False, True) if not legal or phase == 31 else (False,)):
                new_remaining = rem+14-8 if last else remaining
                new_pending = True if last else pending
                successors.add(((phase+1) % 32, rem+6, new_pending, new_remaining, True))
        for nxt in successors:
            transitions += 1
            if nxt not in seen:
                seen.add(nxt)
                todo.append(nxt)
    return dict(states=len(seen), transitions=transitions,
                end_remaining_values=sorted(end_values), line151_witnesses=witnesses[:3])


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    legal = explore()
    illegal = explore(False)
    assert not legal['line151_witnesses']
    assert illegal['line151_witnesses']  # do not generalize to arbitrary TLAST
    result = dict(source=str(SOURCE.relative_to(ROOT)),
                  source_sha256=hashlib.sha256(SOURCE.read_bytes()).hexdigest(),
                  legal=legal, arbitrary_tlast_counterexample=illegal,
                  abstraction='FIFO order preserved; arbitrary availability, stall, enable, reset; drain does not change residual transitions',
                  limitation='Source-reviewed transition abstraction, not machine equivalence proof; independent review pending')
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2)+'\n')
    print(json.dumps(result, indent=2))


if __name__ == '__main__':
    main()
