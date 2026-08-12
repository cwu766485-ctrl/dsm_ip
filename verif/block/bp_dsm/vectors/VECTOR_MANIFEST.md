# BP EFDSM2 Vector Manifest

`uvm_verif/refmodel/python/generate_bp_ef2_vectors.py` produces the single
golden CSV. The block runner uses `--samples 4096 --seed 20260812`; the seed
selects reproducible random Q1.15 I/Q inputs while forcing `-32768` and
`+32767` at periodic rows. The directed and random RTL tests check bit,
signed output, and quantizer state against every golden row.
