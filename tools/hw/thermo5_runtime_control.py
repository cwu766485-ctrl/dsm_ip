"""Software handover for the canonical thermo5 runtime AXI-Lite product.

Supply board-specific read32(offset) / write32(offset, value) callbacks.
The producer must finish its already-open packet and remain quiescent until
this call returns. The receiver/PA routing must accept the returned contract
before the caller writes CONTROL.RUN=1.
"""
from dataclasses import dataclass
import time


@dataclass(frozen=True)
class PAContract:
    architecture: int
    channel_mask: int
    weights: tuple


def select_architecture(read32, write32, architecture, timeout_s=1.0):
    """STOP, drain, commit and verify; leave RUN cleared for PA reconfiguration."""
    if architecture not in (0, 1, 2):
        raise ValueError('architecture must be EF1=0, EF2=1 or MASH=2')
    if read32(0x0c) != 0x54483502:
        raise RuntimeError('Connected top does not support runtime DSM selection')
    deadline=time.monotonic()+timeout_s
    def wait(predicate):
        while not predicate():
            if time.monotonic()>=deadline:
                raise TimeoutError('thermo5 handover timed out; RUN remains stopped')
            time.sleep(0.00001)
    write32(0x00,0)
    wait(lambda: not (read32(0x04)&0x19)) # cfg busy, TX active, draining
    write32(0x44,0x600)                  # clear prior DONE / ERROR
    write32(0x40,architecture)
    wait(lambda: not (read32(0x44)&0x100))
    status=read32(0x44)
    if status&0x400 or not status&0x200 or (status&3)!=architecture or read32(0x40)!=architecture:
        raise RuntimeError('thermo5 core rejected architecture handover')
    return PAContract(architecture,0x3 if architecture==2 else 0xf,
                      (1,2) if architecture==2 else (1,1,1,1))
