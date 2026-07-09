#!/usr/bin/env python3
"""PS-side DSM DPD control helper for Zynq UltraScale+ Linux.

This script writes the DSM IP AXI-Lite register map through /dev/mem. It is
intended for board bring-up and calibration experiments where a PS-side
program computes polynomial or LUT DPD parameters and updates the PL datapath.
"""

from __future__ import annotations

import argparse
import mmap
import os
import struct
from dataclasses import dataclass


REG_CTRL = 0x00
REG_STATUS = 0x04
REG_VERSION = 0x14
REG_INPUT_SAMPLE_COUNT = 0x18
REG_OUTPUT_SAMPLE_COUNT = 0x1C
REG_ERROR_STATUS = 0x24
REG_FRONTEND_SAMPLE_COUNT = 0x28
REG_INPUT_STALL_COUNT = 0x2C
REG_INTERP_MODE = 0x30
REG_DPD_CTRL = 0x40
REG_DPD_C1 = 0x44
REG_DPD_C3 = 0x48
REG_DPD_C5 = 0x4C
REG_DPD_SAMPLE_COUNT = 0x50
REG_DPD_SATURATION_COUNT = 0x54
REG_DPD_LUT_ADDR = 0x58
REG_DPD_LUT_DATA = 0x5C
REG_DPD_LUT_COMMIT = 0x60

DPD_BYPASS = 0
DPD_POLY = 1
DPD_LUT = 2

PAGE_SIZE = mmap.PAGESIZE
MAP_SIZE = 0x1000


def parse_u32(text: str) -> int:
    value = int(text, 0)
    if value < 0 or value > 0xFFFFFFFF:
        raise argparse.ArgumentTypeError(f"value out of uint32 range: {text}")
    return value


def parse_lut_entry(text: str) -> tuple[int, int]:
    if "=" not in text:
        raise argparse.ArgumentTypeError("LUT entry must be INDEX=WORD")
    idx_s, word_s = text.split("=", 1)
    idx = int(idx_s, 0)
    if idx < 0 or idx > 15:
        raise argparse.ArgumentTypeError("LUT index must be 0..15")
    return idx, parse_u32(word_s)


@dataclass
class AxiLite:
    base: int
    dry_run: bool = False
    devmem: str = "/dev/mem"

    def __post_init__(self) -> None:
        self.page_base = self.base & ~(PAGE_SIZE - 1)
        self.page_off = self.base - self.page_base
        self._fd = None
        self._mem = None
        if not self.dry_run:
            self._fd = os.open(self.devmem, os.O_RDWR | os.O_SYNC)
            self._mem = mmap.mmap(
                self._fd,
                MAP_SIZE,
                mmap.MAP_SHARED,
                mmap.PROT_READ | mmap.PROT_WRITE,
                offset=self.page_base,
            )

    def close(self) -> None:
        if self._mem is not None:
            self._mem.close()
        if self._fd is not None:
            os.close(self._fd)

    def _pos(self, offset: int) -> int:
        pos = self.page_off + offset
        if pos < 0 or pos + 4 > MAP_SIZE:
            raise ValueError(f"offset 0x{offset:02X} outside mapped page")
        return pos

    def read32(self, offset: int) -> int:
        if self.dry_run:
            print(f"READ  [0x{self.base + offset:08X}]")
            return 0
        assert self._mem is not None
        return struct.unpack_from("<I", self._mem, self._pos(offset))[0]

    def write32(self, offset: int, value: int) -> None:
        value &= 0xFFFFFFFF
        if self.dry_run:
            print(f"WRITE [0x{self.base + offset:08X}] = 0x{value:08X}")
            return
        assert self._mem is not None
        struct.pack_into("<I", self._mem, self._pos(offset), value)


def write_poly(bus: AxiLite, args: argparse.Namespace) -> None:
    bus.write32(REG_DPD_CTRL, DPD_BYPASS)
    bus.write32(REG_DPD_C1, args.c1)
    bus.write32(REG_DPD_C3, args.c3)
    bus.write32(REG_DPD_C5, args.c5)
    bus.write32(REG_DPD_CTRL, DPD_POLY)


def write_lut(bus: AxiLite, args: argparse.Namespace) -> None:
    bus.write32(REG_DPD_CTRL, DPD_BYPASS)
    default_word = args.lut_default
    entries = {idx: word for idx, word in args.lut_entry}
    for idx in range(16):
        bus.write32(REG_DPD_LUT_ADDR, idx)
        bus.write32(REG_DPD_LUT_DATA, entries.get(idx, default_word))
    bus.write32(REG_DPD_LUT_COMMIT, 1)
    bus.write32(REG_DPD_CTRL, DPD_LUT)


def print_status(bus: AxiLite) -> None:
    regs = [
        ("VERSION", REG_VERSION),
        ("STATUS", REG_STATUS),
        ("INTERP_MODE", REG_INTERP_MODE),
        ("DPD_CTRL", REG_DPD_CTRL),
        ("INPUT_SAMPLE_COUNT", REG_INPUT_SAMPLE_COUNT),
        ("FRONTEND_SAMPLE_COUNT", REG_FRONTEND_SAMPLE_COUNT),
        ("DPD_SAMPLE_COUNT", REG_DPD_SAMPLE_COUNT),
        ("OUTPUT_SAMPLE_COUNT", REG_OUTPUT_SAMPLE_COUNT),
        ("INPUT_STALL_COUNT", REG_INPUT_STALL_COUNT),
        ("ERROR_STATUS", REG_ERROR_STATUS),
        ("DPD_SATURATION_COUNT", REG_DPD_SATURATION_COUNT),
        ("DPD_LUT_ACTIVE_BANK", REG_DPD_LUT_COMMIT),
    ]
    for name, offset in regs:
        print(f"{name:24s} = 0x{bus.read32(offset):08X}")


def main() -> int:
    parser = argparse.ArgumentParser(
        description="Configure DSM IP DPD registers from the MPSoC PS side."
    )
    parser.add_argument("--dsm-base", type=parse_u32, required=True)
    parser.add_argument("--dry-run", action="store_true")
    parser.add_argument("--devmem", default="/dev/mem")

    sub = parser.add_subparsers(dest="cmd", required=True)

    p_poly = sub.add_parser("poly", help="enable polynomial DPD")
    p_poly.add_argument("--c1", type=parse_u32, default=0x00004000)
    p_poly.add_argument("--c3", type=parse_u32, default=0x00000000)
    p_poly.add_argument("--c5", type=parse_u32, default=0x00000000)

    p_lut = sub.add_parser("lut", help="enable LUT DPD")
    p_lut.add_argument("--lut-default", type=parse_u32, default=0x00004000)
    p_lut.add_argument(
        "--lut-entry",
        action="append",
        type=parse_lut_entry,
        default=[],
        help="override one LUT entry as INDEX=WORD, for example 3=0x00003F00",
    )

    sub.add_parser("bypass", help="disable DPD correction")
    sub.add_parser("status", help="read status and counters")

    args = parser.parse_args()
    bus = AxiLite(args.dsm_base, dry_run=args.dry_run, devmem=args.devmem)
    try:
        if args.cmd == "poly":
            write_poly(bus, args)
            print_status(bus)
        elif args.cmd == "lut":
            write_lut(bus, args)
            print_status(bus)
        elif args.cmd == "bypass":
            bus.write32(REG_DPD_CTRL, DPD_BYPASS)
            print_status(bus)
        elif args.cmd == "status":
            print_status(bus)
        else:
            raise RuntimeError(f"unsupported command: {args.cmd}")
    finally:
        bus.close()
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
