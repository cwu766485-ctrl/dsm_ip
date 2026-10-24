#!/usr/bin/env python3
"""Guard ASIC mapping wrapper against the canonical FPGA thermo5 OOC config."""

import re
from pathlib import Path


ROOT = Path(__file__).resolve().parents[2]
FPGA_TCL = ROOT / "syn" / "run_ooc_tid32_thermo5_axis_frontend_tx.tcl"
FPGA_TOP = ROOT / "rtl" / "tx_bandpass_if" / "tid32_thermo5_axis_frontend_tx.sv"
FPGA_UVM = ROOT / "dv" / "uvm" / "tb" / "thermo5_sku_uvm_tb.sv"
ASIC_RTL = ROOT / "syn" / "rtl" / "thermo5_frozen_asic.sv"


def _read_fpga_generics(text):
    match = re.search(r"-generic\s+\{([^}]+)\}", text)
    if not match:
        raise ValueError("FPGA OOC generic list was not found")
    result = {}
    for token in match.group(1).split():
        if "=" not in token:
            continue
        key, value = token.split("=", 1)
        result[key] = value
    return result


def _read_asic_parameters(text):
    result = {}
    for name in ("INTERP_TAPS", "DPD_MAX_TAPS", "FPGA_USE_XPM_FIFO",
                 "ENABLE_LOW_POWER_CTRL"):
        match = re.search(r"\." + name + r"\(([^)]+)\)", text)
        if not match:
            raise ValueError("ASIC wrapper parameter %s was not found" % name)
        value = match.group(1).strip().replace("1'b", "")
        result[name] = value
    bypass = re.search(r"\.BYPASS_DPD\(1'b([01])\)", text)
    if not bypass:
        raise ValueError("ASIC wrapper BYPASS_DPD parameter was not found")
    result["BYPASS_DPD"] = bypass.group(1)
    return result


def check_config():
    fpga = _read_fpga_generics(FPGA_TCL.read_text())
    fpga_top = FPGA_TOP.read_text()
    fpga_uvm = FPGA_UVM.read_text()
    asic = _read_asic_parameters(ASIC_RTL.read_text())
    common = ("INTERP_TAPS", "DPD_MAX_TAPS", "ENABLE_LOW_POWER_CTRL")
    errors = []
    for name in common:
        if fpga.get(name) != asic.get(name):
            errors.append("%s differs: FPGA=%s ASIC=%s" % (
                name, fpga.get(name), asic.get(name)))
    if asic.get("BYPASS_DPD") != "0":
        errors.append("ASIC DPD must remain enabled like the frozen FPGA SKU")
    if not re.search(r"parameter\s+bit\s+BYPASS_DPD\s*=\s*1'b0", fpga_top):
        errors.append("FPGA top default BYPASS_DPD must remain zero")
    for name, expected in (("W", "16"), ("STEP", "7168")):
        if not re.search(r"parameter\s+int\s+" + name + r"\s*=\s*" + expected + r"\b", fpga_top):
            errors.append("FPGA top default %s must remain %s" % (name, expected))
    if not re.search(r"\.INTERP_TAPS\(2\),\.DPD_MAX_TAPS\(1\),\.BYPASS_DPD\(1'b0\)", fpga_uvm):
        errors.append("frozen FPGA UVM instance must use interpolation 2 / DPD1 / DPD enabled")
    if not re.search(r"identity_c1\s*=\s*16'd16384", fpga_uvm):
        errors.append("frozen FPGA UVM identity coefficient must remain Q2.14 unity")
    if not re.search(r"\.dpd_active_taps\(3'd1\).*?\.c1_re\(\{48'd0,identity_c1\}\).*?\.c1_im\(64'd0\)", fpga_uvm, re.S):
        errors.append("frozen FPGA UVM instance must tie one active identity DPD tap")
    for name in ("c3_re", "c3_im", "c5_re", "c5_im"):
        if not re.search(r"\." + name + r"\(64'd0\)", fpga_uvm):
            errors.append("frozen FPGA UVM instance must tie %s to zero" % name)
    if fpga.get("FPGA_USE_XPM_FIFO") != "1" or asic.get("FPGA_USE_XPM_FIFO") != "0":
        errors.append("expected FPGA OOC XPM FIFO and ASIC generic FIFO selections")
    if not re.search(r"\.dpd_active_taps\(3'd1\)", ASIC_RTL.read_text()):
        errors.append("ASIC wrapper must tie one active identity DPD tap")
    if not re.search(r"\.c1_re\(64'h4000\)", ASIC_RTL.read_text()):
        errors.append("ASIC wrapper must tie unity Q2.14 c1_re")
    for name in ("c1_im", "c3_re", "c3_im", "c5_re", "c5_im"):
        if not re.search(r"\." + name + r"\(64'd0\)", ASIC_RTL.read_text()):
            errors.append("ASIC wrapper must tie %s to zero" % name)
    if errors:
        raise ValueError("\n".join(errors))
    return fpga, asic


def main():
    fpga, asic = check_config()
    print("THERMO5_ASIC_FPGA_CONFIG=PASS")
    print("canonical FPGA parameters: INTERP_TAPS=%s DPD_MAX_TAPS=%s "
          "BYPASS_DPD=%s ENABLE_LOW_POWER_CTRL=%s" % (
              fpga["INTERP_TAPS"], fpga["DPD_MAX_TAPS"],
              asic["BYPASS_DPD"], fpga["ENABLE_LOW_POWER_CTRL"]))
    print("functional DPD image: one active tap at Q2.14 unity")
    print("FIFO implementation: FPGA XPM / ASIC generic")
    print("PPA caveat: FPGA OOC preserves runtime DPD coefficient pins; ASIC map ties identity constants")


if __name__ == "__main__":
    main()
