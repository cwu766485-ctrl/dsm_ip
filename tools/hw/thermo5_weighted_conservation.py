#!/usr/bin/env python3.12
"""Check local real/synthetic token conservation; not a full RTL proof.

Real word weight1; synthetic-tail weight0. Reset discards epoch credit.
STOP closes admission after legal packet end, but does not discard tokens.
The abstract queue checks are necessary obligations, not RTL refinement.
"""
import itertools,json,argparse
from pathlib import Path

def check():
    cases=0
    for count in range(3):
        for tags in itertools.product((0,1),repeat=count):
            # 1=real,0=synthetic. Stage1 accepts only real; stage2 may drop tail.
            for push,pop,in_real in itertools.product((False,True),repeat=3):
                if pop and not count or count==2 and push and not pop:continue
                before=sum(tags);after=list(tags)
                emitted=after.pop(0) if pop else 0
                if push:after.append(int(in_real))
                assert sum(after)-before==int(push)*int(in_real)-emitted
                cases+=1
    # Stage1 creates zero-weight synthetic output; may stall while pending.
    for pending,emit_real,emit_synthetic in itertools.product((0,1),repeat=3):
        if emit_synthetic and not pending:continue
        assert 0*pending+emit_real-emit_real-0*emit_synthetic==0
    # Capacity of real words in product; pending synthetic register has weight0.
    slots={'ingress_fifo':2,'gain':3,'stage1_queue':2,'interp_to_dpd':2,
           'dpd':11,'dpd_to_interp':2,'stage2_queue':2,'interp2_to_tid':2,
           'ef2_input_register':1,'pa_bridge':1,'pending_synthetic_tail':0}
    assert sum(slots.values())==28
    return {'local_queue_cases':cases,'local_conservation':'PASS',
            'weighted_sum':'R=ingress+gain+stage1+elastic1+DPD_real+elastic2_real+stage2_real+elastic3+EF2+PA',
            'epoch_balance':'outstanding=accepted_core_real-accepted_PA_real-reset_discarded_real',
            'conditional_real_capacity_upper_bound':28,'strict_maximum_reachable':'UNPROVEN',
            'slot_weights':slots,'stop_rule':'No discard; accepted open packet completes then drain',
            'reset_rule':'Discard all weighted tokens and reset balance in common reset epoch',
            'remaining_refinement_obligations':['DPD lane lockstep/valid and meta_pipe alignment under arbitrary stalls',
             'Stage1 synthetic creation neither duplicates nor drops real head',
             'Stage2 q0_tail drop and queue shifts preserve weight and metadata',
             'All four PA branches keep valid/accept lockstep',
             'Common reset and synchronized enable/STOP cannot discard live real tokens without balance reset'],
            'decision':'OPEN; local algebra/capacity does not prove full RTL invariant or reachability of maximum'}
if __name__=='__main__':
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True);a=p.parse_args()
    a.output.parent.mkdir(parents=True,exist_ok=True);a.output.write_text(json.dumps(check(),indent=2)+'\n')
