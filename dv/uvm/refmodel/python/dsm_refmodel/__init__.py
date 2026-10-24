"""Bit-exact integer reference models for DSM IP verification."""

from .dpd import ComplexCoeff, memory_poly
from .fixed import arithmetic_shift_right, check_signed, saturate_signed, signed_limits, wrap_signed
from .interp import interp_frontend
from .thermo5 import (
    apply_q14_gain,
    interp_x2_vector,
    run_frozen_frontend,
    tid_word,
)

__all__ = [
    "ComplexCoeff",
    "apply_q14_gain",
    "arithmetic_shift_right",
    "check_signed",
    "interp_frontend",
    "interp_x2_vector",
    "memory_poly",
    "run_frozen_frontend",
    "saturate_signed",
    "signed_limits",
    "tid_word",
    "wrap_signed",
]

# The optional legacy BP EFDSM2 module is absent from this branch. Retain its
# names automatically if that module is supplied by another project view.
try:
    from .bp_ef2 import BpEf2, BpEf2Step, BpEf4, BpEf4Step, Fs4Mixer, TxBpEf2Model, TxBpEf2Step
except ImportError as error:
    if "dsm_refmodel.bp_ef2" not in str(error):
        raise
else:
    __all__ += [
        "BpEf2", "BpEf2Step", "BpEf4", "BpEf4Step", "Fs4Mixer",
        "TxBpEf2Model", "TxBpEf2Step",
    ]
