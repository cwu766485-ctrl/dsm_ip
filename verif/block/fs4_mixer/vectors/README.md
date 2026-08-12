# Fs/4 Mixer Vectors

`tb_bp_fs4_iq_mixer.sv` uses a compact directed set that covers `I`, `Q`,
`-I`, `-Q`, valid gaps, reset, and the signed minimum-value negation corner.
The full-chain, Python-generated vector format is `bp_ef2_equivalence.csv`,
produced by `uvm_verif/refmodel/python/generate_bp_ef2_vectors.py` and consumed
by the IF/DSM subsystem test.
