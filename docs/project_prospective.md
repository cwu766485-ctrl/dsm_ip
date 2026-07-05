# Project Prospective

Timestamp: 2026-07-05 17:48:35 +08:00

## Current Position

This repository is now a reusable DSM digital IP prototype rather than a loose
algorithm collection. The current package includes MATLAB fixed-point models,
synthesizable RTL, XSim regression, Vivado IP packaging, and OOC timing/resource
evidence.

The verified baseline scope contains seven DSM paths:

- LPDSM
- LPDSM2
- EFDSM
- EFDSM2
- MASH11
- MASH111
- MASH22

The exploratory multibit scope adds seven Cartesian multibit DSM modes with
MATLAB/RTL bit-true regression over the P0 vector set.

## Recommended Next Steps

1. Add runtime algorithm selection in an outer wrapper.
   - Keep the timing-closed compile-time cores unchanged.
   - Instantiate selected algorithm branches explicitly.
   - Allow software switching only when the stream is idle or after software
     reset.

2. Move the interpolation/filter frontend from MATLAB to RTL.
   - Start with bypass and fixed-ratio halfband FIR modes.
   - Keep coefficient generation and fixed-point reference in MATLAB.
   - Add RTL/MATLAB bit-true vectors before connecting the frontend to DSM.

3. Strengthen verification.
   - Keep the existing XSim smoke and bit-true tests.
   - Add directed tests for runtime switching, illegal switch attempts, reset
     during active stream, counter behavior, and sticky error clearing.
   - Place future UVM work under `verif/uvm/`.

4. Build a ZU15EG board-level validation flow.
   - The current ZU15EG result is OOC module evidence only.
   - A full board flow still needs block design integration, constraints,
     bitstream generation, software control, and ILA capture.

5. Keep public release hygiene.
   - Do not publish restricted board files, schematics, BOMs, downloaded papers,
     licenses, server details, or generated Vivado/XSim artifacts.
   - Keep public documentation in English.

## Completion Criteria For The Next IP Upgrade

- Runtime algorithm wrapper passes simulation.
- Register map documents match RTL behavior.
- MATLAB/RTL bit-true status is preserved for all existing modes.
- ZU15EG OOC timing remains closed after the wrapper change.
- Documentation clearly separates verified IP behavior from planned features.
