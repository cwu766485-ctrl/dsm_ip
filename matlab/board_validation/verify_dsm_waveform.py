#!/usr/bin/env python3
"""Basic scope waveform inspection for retained board-validation captures."""

from pathlib import Path

import matplotlib.pyplot as plt
import numpy as np
from scipy import signal


repo = Path(__file__).resolve().parents[2]
base_path = repo / "data" / "board_validation" / "cartesian_dsm"
ref_curve = np.loadtxt(base_path / "RefCurve_scope_aux.Wfm.csv")
dsm000 = np.loadtxt(base_path / "DSM000.Wfm.csv")

print("=" * 70)
print("DSM waveform inspection")
print("=" * 70)

for name, wave, window_us, step_ps in [
    ("RefCurve_scope_aux.Wfm.csv", ref_curve, 100, 50),
    ("DSM000.Wfm.csv", dsm000, 400, 100),
]:
    print(f"\n{name}")
    print(f"  samples      : {len(wave)}")
    print(f"  time window  : {window_us} us")
    print(f"  time step    : {step_ps} ps")
    print(f"  range        : [{wave.min():.6f}, {wave.max():.6f}]")
    print(f"  mean         : {wave.mean():.6f}")
    print(f"  std          : {wave.std():.6f}")

ref_levels = len(np.unique(np.round(ref_curve, 6)))
dsm_levels = len(np.unique(np.round(dsm000, 6)))

ref_psd = signal.periodogram(ref_curve)[1]
dsm_psd = signal.periodogram(dsm000)[1]

low_freq_ref = ref_psd[: len(ref_psd) // 10].sum()
high_freq_ref = ref_psd[len(ref_psd) // 10 :].sum()
low_freq_dsm = dsm_psd[: len(dsm_psd) // 10].sum()
high_freq_dsm = dsm_psd[len(dsm_psd) // 10 :].sum()

if len(ref_curve) > len(dsm000):
    correlation = np.corrcoef(ref_curve[: len(dsm000)], dsm000)[0, 1]
else:
    correlation = np.corrcoef(ref_curve, dsm000[: len(ref_curve)])[0, 1]

print("\nSummary")
print(f"  rounded levels, reference : {ref_levels}")
print(f"  rounded levels, DSM000    : {dsm_levels}")
print(f"  reference low/high energy : {low_freq_ref:.6e} / {high_freq_ref:.6e}")
print(f"  DSM000 low/high energy    : {low_freq_dsm:.6e} / {high_freq_dsm:.6e}")
print(f"  waveform correlation      : {correlation:.6f}")

ref_diff = np.diff(ref_curve)
dsm_diff = np.diff(dsm000)

print("\nDifference statistics")
print(f"  reference max/min step : {ref_diff.max():.6f} / {ref_diff.min():.6f}")
print(f"  reference mean abs step: {np.abs(ref_diff).mean():.6f}")
print(f"  DSM000 max/min step    : {dsm_diff.max():.6f} / {dsm_diff.min():.6f}")
print(f"  DSM000 mean abs step   : {np.abs(dsm_diff).mean():.6f}")

fig, axes = plt.subplots(3, 1, figsize=(14, 10))

t_ref = np.arange(len(ref_curve)) * 50e-3
t_dsm = np.arange(len(dsm000)) * 100e-3

axes[0].plot(t_ref, ref_curve, "b-", label="Reference capture", linewidth=0.5, alpha=0.8)
axes[0].set_ylabel("Voltage (V)")
axes[0].set_title("Reference waveform")
axes[0].grid(True, alpha=0.3)
axes[0].legend()

axes[1].plot(t_dsm, dsm000, "r-", label="DSM000 capture", linewidth=0.5, alpha=0.8)
axes[1].set_ylabel("Voltage (V)")
axes[1].set_title("DSM000 waveform")
axes[1].grid(True, alpha=0.3)
axes[1].legend()

freq_ref, psd_ref = signal.welch(ref_curve, nperseg=2048)
freq_dsm, psd_dsm = signal.welch(dsm000, nperseg=2048)

axes[2].semilogy(freq_ref, psd_ref, "b-", label="Reference PSD", linewidth=1, alpha=0.8)
axes[2].semilogy(freq_dsm, psd_dsm, "r-", label="DSM000 PSD", linewidth=1, alpha=0.8)
axes[2].set_xlabel("Frequency (normalized)")
axes[2].set_ylabel("Power spectral density")
axes[2].set_title("Frequency-domain comparison")
axes[2].grid(True, alpha=0.3, which="both")
axes[2].legend()

plt.tight_layout()
plt.savefig("dsm_waveform_analysis.png", dpi=150, bbox_inches="tight")
print("\nSaved dsm_waveform_analysis.png")
plt.show()
