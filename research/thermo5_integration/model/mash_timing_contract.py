"""Accepted-word timing contract for the L=32 historical MASH boundaries.

The 32-register pre-sum accounts for Stage 1's 32-word stream delay. The
35-entry q1 alignment includes two raw-boundary cycles and contributes 32
more words at the Stage 2 observation edge; two explicit reset FIFO words
give a total 66-word MASH delay. Transport cycles never remove raw samples.
Both offline receiver FIRs already compensate their own group delay.
"""
CHANNELS = 32
STAGE1_STREAM_DELAY_WORDS = CHANNELS
MASH_STREAM_DELAY_WORDS = 2 * CHANNELS + 2
RAW_BITS_PER_COMPLEX = 2
FRONTEND_INTERPOLATION = 4
MASH_SOURCE_SAMPLE_OFFSET = MASH_STREAM_DELAY_WORDS * CHANNELS // FRONTEND_INTERPOLATION
