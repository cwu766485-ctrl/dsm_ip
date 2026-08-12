# Fs/4 Mixer Vector Manifest

The directed test covers the exact phase sequence `+I`, `+Q`, `-I`, `-Q`.
`tb_bp_fs4_iq_mixer_random.sv` adds 257 deterministic pseudo-random samples,
signed extrema, input-valid bubbles, phase-hold checks, and a local in-TB
oracle. The reference mapping is `dsm_refmodel.bp_ef2.Fs4Mixer`.
