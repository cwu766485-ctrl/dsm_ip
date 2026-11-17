#!/usr/bin/env python3
"""Matched-input scalar MASH 1-1 vs 1-1-1, digital receiver and RF PSD.

This is a behavioral recurrence study; it is not a hardware PPA measurement.
"""
import argparse
import csv
import json
import math
from pathlib import Path
import sys
import numpy as np
ROOT=Path(__file__).resolve().parents[2]
sys.path.insert(0,str(ROOT/'dv/uvm/refmodel/python'))
from benchmark_thermo5_tid_receiver import RAW_FS_HZ,RX_FIR_TAPS,_blackman_lowpass,_linear_fir_decimate,demodulate_metrics
from dsm_refmodel.thermo5 import read_source_vectors,run_centered_cubic_ef2_inputs,one_tap_complex_coefficients

Q=32768

def model(samples,order):
    if order not in (2,3):raise ValueError('order must be 2 or 3')
    r=[[0,0] for _ in range(order)]
    previous=[[-1,-1] for _ in range(order)]
    previous2=[[-1,-1] for _ in range(order)]
    previous_r3=[[0,0] for _ in range(3)]
    levels=np.empty((len(samples),2),dtype=np.int8)
    for n,pair in enumerate(samples):
      for c,x in enumerate(pair):
        values=[]
        for stage in range(order):
          v=int(x)+Q if stage==0 else r[stage-1][c]
          u=r[stage][c]+v
          bit=u>>16
          if bit not in (0,1):raise ValueError('residue overflow')
          r[stage][c]=u&65535
          values.append(2*bit-1)
        y=values[0]+values[1]-previous[1][c]
        if order==3:
          y+=values[2]-2*previous[2][c]+previous2[2][c]
          # The exact integer identity independently verifies the residual
          # finite-difference cancellation for every sample and component.
          d3=r[2][c]-3*previous_r3[0][c]+3*previous_r3[1][c]-previous_r3[2][c]
          if Q*y != int(x)-d3:raise AssertionError('third-order integer identity')
          previous_r3[2][c]=previous_r3[1][c];previous_r3[1][c]=previous_r3[0][c];previous_r3[0][c]=r[2][c]
        bound=3 if order==2 else 7
        if y not in range(-bound,bound+1,2):raise AssertionError('invalid output level')
        levels[n,c]=y
        for stage in range(1,order):previous2[stage][c]=previous[stage][c];previous[stage][c]=values[stage]
    return levels


def raw_fs4(levels):
    parity=np.arange(len(levels))&1
    rf=np.empty(len(levels)*2,dtype=np.int8)
    rf[0::2]=levels[:,0]*np.where(parity,-1,1)
    rf[1::2]=levels[:,1]*np.where(parity,1,-1)
    return rf


def metrics(rf,stim):
    lo=(1+0j,-1j,-1+0j,1j)
    ddc=[2*int(v)*lo[i&3] for i,v in enumerate(rf)]
    a=_linear_fir_decimate(ddc,_blackman_lowpass(.75*250e6,RAW_FS_HZ,RX_FIR_TAPS),2,phase=0)
    b=_linear_fir_decimate(a,_blackman_lowpass(.75*250e6,RAW_FS_HZ/2,RX_FIR_TAPS),4,phase=0)
    return demodulate_metrics(b,stim)


def spectrum(rf):
    n=32768;window=np.hanning(n);power=np.zeros(n);count=0
    # Welch windows use only the active OFDM payload, not the zero guard.
    for start in range(2576*8,len(rf)-2576*8-n+1,n//2):
      fft=np.fft.fft(rf[start:start+n]*window);power+=np.abs(fft)**2;count+=1
    if not count:raise ValueError('insufficient samples for PSD')
    power/=count;freq=np.fft.fftfreq(n,1/RAW_FS_HZ);dist=np.abs(np.abs(freq)-RAW_FS_HZ/4)
    main=power[dist<=125e6].sum();adj=power[(dist>125e6)&(dist<=375e6)].sum()
    return freq,power,10*math.log10(adj/main),count


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--prepared',type=Path,required=True);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
    a.out.mkdir(parents=True,exist_ok=False)
    stim=json.loads((a.prepared/'stimulus.json').read_text());stim['qam_rows']=[[complex(*v) for v in row] for row in stim['qam_rows']]
    iw,qw,starts,gains=read_source_vectors(a.prepared/'input')
    front=run_centered_cubic_ef2_inputs(iw,qw,starts,gains,dpd_coefficients=one_tap_complex_coefficients(16384,0,0,0,0,0),dpd_active_taps=1)
    iq=[(i,q) for iv,qv in front for i,q in zip(iv,qv)]
    records=[];spectra=[]
    for order in (2,3):
      levels=model(iq,order);rf=raw_fs4(levels);m=metrics(rf,stim)
      freq,power,adj,windows=spectrum(rf);spectra.append(power)
      idx=(levels.astype(np.int16)+(3 if order==2 else 7))//2
      decoded=np.zeros_like(idx)
      for bit in range(order):decoded+=(2*((idx>>bit)&1)-1)*(1<<bit)
      if not np.array_equal(decoded,levels):raise AssertionError('weighted PA encoding mismatch')
      records.append({'architecture':'MASH11' if order==2 else 'MASH111','seed':stim['seed'],'symbols':stim['symbols'],
        'rms_drive':stim['rms_drive_target'],'cartesian_samples':len(iq),'evm_percent':m['evm_percent'],'sndr_db':m['sndr_db'],
        'bit_errors':m['uncoded_bit_errors_natural_binary'],'bits':m['qam_symbols']*8,'ber':m['uncoded_ber_natural_binary'],
        'adjacent_proxy_dbc':adj,'psd_windows':windows,'peak_abs_level':int(np.max(np.abs(levels))),
        'distinct_levels':sorted(int(x) for x in np.unique(levels)),'weighted_planes':order,
        'evidence':'scalar model, no RTL or physical serializer','offset_source_samples':0})
    with (a.out/'raw_psd.csv').open('w',newline='') as f:
      w=csv.writer(f);w.writerow(['frequency_hz','mash11_power','mash111_power'])
      w.writerows(zip(freq,spectra[0],spectra[1]))
    (a.out/'metrics.json').write_text(json.dumps(records,indent=2)+'\n')
    print(json.dumps(records,indent=2))
if __name__=='__main__':main()
