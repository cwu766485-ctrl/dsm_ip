#!/usr/bin/env python3
"""Welch PSD of captured weighted PA RF before receiver filtering."""
import argparse
import csv
import json
from pathlib import Path
import numpy as np
from mash_timing_contract import MASH_SOURCE_SAMPLE_OFFSET


def main():
    p=argparse.ArgumentParser(description=__doc__)
    p.add_argument('--capture',type=Path,required=True)
    p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    def bits(name):
        words=[int(v,16) for v in (a.capture/name).read_text().split()]
        return np.array([2*((v>>b)&1)-1 for v in words for b in range(64)],dtype=float)
    rf=bits('captured_mash_pa0.mem')+2*bits('captured_mash_pa1.mem')
    meta=json.loads((a.capture/'stimulus.json').read_text())
    start=(meta['data_start']+MASH_SOURCE_SAMPLE_OFFSET)*8
    data=rf[start:start+meta['data_samples']*8]
    nfft=65536;fs=14e9;carrier=fs/4;bw=250e6
    window=np.blackman(nfft);window_energy=float(np.sum(window**2))
    spectra=[abs(np.fft.rfft(data[n:n+nfft]*window))**2/(fs*window_energy)
             for n in range(0,len(data)-nfft+1,nfft//2)]
    if not spectra:raise ValueError('Insufficient payload for PSD')
    psd=np.mean(spectra,axis=0);psd[1:-1]*=2
    freq=np.fft.rfftfreq(nfft,1/fs);df=fs/nfft;delta=abs(freq-carrier)
    main=float(np.sum(psd[delta<=bw/2])*df)
    left=float(np.sum(psd[(freq>=carrier-1.5*bw)&(freq<carrier-bw/2)])*df)
    right=float(np.sum(psd[(freq>carrier+bw/2)&(freq<=carrier+1.5*bw)])*df)
    with (a.output/'weighted_rf_raw_psd.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['frequency_hz','one_sided_psd','relative_to_main_db_per_hz'])
        for hz,power in zip(freq,psd):w.writerow([hz,power,10*np.log10(max(power,1e-30)/main)])
    result={'source':'actual 1:2 bipolar RTL PA pair, before DDC/LPF',
        'sample_rate_hz':fs,'carrier_hz':carrier,'main_bandwidth_hz':bw,'fft_size':nfft,
        'window':'Blackman','segments':len(spectra),'payload_start_raw_sample':start,
        'left_adjacent_equal_bandwidth_dbc':float(10*np.log10(left/main)),
        'right_adjacent_equal_bandwidth_dbc':float(10*np.log10(right/main)),
        'total_adjacent_equal_bandwidth_dbc':float(10*np.log10((left+right)/main)),
        'note':'Digital sequence measurement; not calibrated RF ACLR or an emissions signoff.'}
    (a.output/'raw_psd_summary.json').write_text(json.dumps(result,indent=2)+'\n')
    print(json.dumps(result),flush=True)


if __name__=='__main__':main()
