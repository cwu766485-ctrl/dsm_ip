# Weighted MASH Extended DV

The independent extended Icarus testbench passed 128 accepted and 128 produced
vectors, with every bit of both weighted PA branches matching the MATLAB
oracle. It checked output order, count, continuous II=1 and asserted the
35-word internal alignment parameter. The observed external first-output
latency is 6 cycles. The block has no downstream backpressure or STOP port;
those behaviors require a separate wrapper and remain OPEN.
