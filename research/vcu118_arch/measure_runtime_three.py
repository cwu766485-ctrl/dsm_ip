#!/usr/bin/env python3
"""Compare real RTL PA captures for three modes using fixed architecture delays."""
import argparse,csv,json
from pathlib import Path
import numpy as np
from mash111_research import metrics,spectrum

def main():
 ap=argparse.ArgumentParser(description=__doc__);ap.add_argument('--prepared',type=Path,required=True);ap.add_argument('--capture',type=Path,required=True);ap.add_argument('--out',type=Path,required=True);a=ap.parse_args();a.out.mkdir(parents=True,exist_ok=False)
 stim=json.loads((a.prepared/'stimulus.json').read_text());stim['qam_rows']=[[complex(*v) for v in row] for row in stim['qam_rows']]
 results=[];spectra=[]
 # 32 accepted Stage1 words / four Pre-DSM samples per source sample;
 # EF2 directly emits one word for the same input word; corrected MASH 66 words.
 for name,phase,arch,weights,offset in [('EF1',2,0,[1,1,1,1],256),('EF2',0,1,[1,1,1,1],0),('MASH11',1,2,[1,2],528)]:
  words=[[int(v,16) for v in (a.capture/('phase%d_arch%d_pa%d.mem'%(phase,arch,p))).read_text().split()] for p in range(len(weights))]
  if not words or any(len(x)!=stim['words'] for x in words):raise ValueError('PA capture is incomplete')
  rf=np.array([sum(weight*(2*((plane[n]>>b)&1)-1) for weight,plane in zip(weights,words)) for n in range(len(words[0])) for b in range(64)],dtype=np.int8)
  case=dict(stim);case['data_start']=stim['data_start']+offset
  m=metrics(rf,case);freq,power,adj,count=spectrum(rf);spectra.append(power)
  results.append({'architecture':name,'seed':stim['seed'],'symbols':stim['symbols'],'fft_source_offset':offset,
   'evm_percent':m['evm_percent'],'sndr_db':m['sndr_db'],'bit_errors':m['uncoded_bit_errors_natural_binary'],
   'bits':m['qam_symbols']*8,'ber':m['uncoded_ber_natural_binary'],'adjacent_proxy_dbc':adj,
   'evidence':'RTL accepted PA words; offset from architecture recurrence','psd_windows':count})
 with (a.out/'actual_pa_psd.csv').open('w',newline='') as f:
  w=csv.writer(f);w.writerow(['frequency_hz','ef1','ef2','mash11']);w.writerows(zip(freq,*spectra))
 (a.out/'metrics.json').write_text(json.dumps(results,indent=2)+'\n');print(json.dumps(results,indent=2))
if __name__=='__main__':main()
