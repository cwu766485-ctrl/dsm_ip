# Weighted MASH Timing Audit

The preserved VCU118 routed baseline is WNS/WHS `+1.090/+0.032 ns`, with
14,279 LUT, 13,440 FF, 1,004 CARRY8, and no DSP/BRAM. The worst path is the
293-sink `s1_valid` enable net: 0.079 ns cell delay and 3.200 ns net delay.
`check_timing` reports 1,025 inputs without input delay and 129 outputs
without output delay. No artificial interface delay or false path was added;
parent timing-contract closure remains OPEN.
