#!/usr/bin/env python3.12
"""Generate independent I-only/Q-only legal one-tap saturation witnesses."""
import argparse
import json
from pathlib import Path
from dsm_refmodel.thermo5 import (
    generate_source_vectors, one_tap_complex_coefficients,
    run_centered_cubic_frontend, run_centered_cubic_ef2_inputs,
    centered_cubic_dpd_saturation_by_lane, write_vectors,
)

def generate(output_dir, axis):
    i, q, starts, gains = generate_source_vectors(
        words=112, seed=210042, profile="range_stress",
        frame_start_words=(1,57), frame_gains=(16384,))
    if axis == "i":
        q = [[0]*len(word) for word in q]
    elif axis == "q":
        i = [[0]*len(word) for word in i]
    coefficients = one_tap_complex_coefficients(c1_re_q14=32767)
    kwargs = dict(dpd_coefficients=coefficients, dpd_active_taps=1)
    pa = run_centered_cubic_frontend(i,q,starts,gains,step=5120,
                                    tidsm_order=2,**kwargs)
    ef2 = run_centered_cubic_ef2_inputs(i,q,starts,gains,**kwargs)
    write_vectors(output_dir,i,q,starts,gains,pa,ef2_words=ef2)
    counts = centered_cubic_dpd_saturation_by_lane(
        i,q,starts,gains,coefficients,dpd_active_taps=1,lanes=16)
    (output_dir/"thermo5_dpd_saturation_count.mem").write_text(
        "".join(f"{value}\n" for value in counts))
    (output_dir/"axis_witness.json").write_text(json.dumps(dict(
        axis=axis, seed=210042, words=112, packet_beats=32,
        sample_count_per_lane=114, saturation_counts=counts),indent=2)+"\n")

if __name__ == "__main__":
    parser=argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--output-dir",type=Path,required=True)
    parser.add_argument("--axis",choices=("i","q","both"),required=True)
    args=parser.parse_args()
    generate(args.output_dir,args.axis)
