# DPD Reference Model

- MATLAB fixed-point signoff model: `matlab/dpd/`.
- Python integer regression model: `uvm_verif/refmodel/python/dsm_refmodel/dpd.py`.

MATLAB and Python must agree before Python-generated vectors are consumed by a
Linux/VCS UVM regression.
