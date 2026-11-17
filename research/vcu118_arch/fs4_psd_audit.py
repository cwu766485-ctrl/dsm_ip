#!/usr/bin/env python3
"""Check four-phase Fs/4 mapping and PSD of actual accepted RTL PA words."""
import argparse,csv,json,hashlib
from pathlib import Path
import numpy as np
FS=14_000_000_000.0

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--pa0',type=Path,required=True);ap.add_argument('--pa1',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args()
 a.out.mkdir(parents=True,exist_ok=False)
 # Independent ideal I-only/Q-only mixer checks; these are amplitude samples,
 # not claims that an arbitrary complex waveform is one-bit quantized.
 i=np.tile([1,0,-1,0],1024);q=np.tile([0,-1,0,1],1024)
 assert np.array_equal(i[:4],[1,0,-1,0]) and np.array_equal(q[:4],[0,-1,0,1])
 f=np.fft.rfftfreq(len(i),1/FS);peak=float(f[np.argmax(abs(np.fft.rfft(i)))])
 assert peak==FS/4
 a0=[int(x,16) for x in a.pa0.read_text().split()];a1=[int(x,16) for x in a.pa1.read_text().split()]
 if len(a0)!=len(a1) or len(a0)<3000:raise ValueError('need same complete captured PA words')
 rf=np.empty(len(a0)*64,dtype=np.float64)
 for k,(w0,w1) in enumerate(zip(a0,a1)):
  for bit in range(64):rf[k*64+bit]=(2*((w0>>bit)&1)-1)+2*(2*((w1>>bit)&1)-1)
 n=65536;guard=2576*8;block=rf[guard:len(rf)-guard]
 starts=list(range(0,len(block)-n+1,n//2));window=np.hanning(n);power=np.zeros(n)
 for start in starts:power+=abs(np.fft.fft(block[start:start+n]*window))**2
 if not starts:raise ValueError('not enough active samples for PSD')
 power/=len(starts);freq=np.fft.fftfreq(n,1/FS);freq=np.fft.fftshift(freq);power=np.fft.fftshift(power)
 dist=abs(abs(freq)-FS/4);main=power[dist<=125e6].sum();adj=power[(dist>125e6)&(dist<=375e6)].sum()
 with (a.out/'actual_pa_psd.csv').open('w',newline='') as f:
  w=csv.writer(f);w.writerow(['frequency_hz','power_welch_unnormalized']);w.writerows(zip(freq,power))
 result={'sample_rate_hz':FS,'ideal_i_carrier_hz':peak,'ideal_q_sequence':q[:4].tolist(),'bit_order':'bit0 earliest',
 'raw_word_count':len(a0),'rf_samples':len(rf),'psd_windows':len(starts),'rf_main_band_hz':[3.375e9,3.625e9],
 'adjacent_band_proxy_dbc':10*np.log10(adj/main),'measurement':'accepted RTL PA bits; assumes uninterrupted nominal 14 Gb/s',
 'input_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in (a.pa0,a.pa1)}}
 (a.out/'result.json').write_text(json.dumps(result,indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
