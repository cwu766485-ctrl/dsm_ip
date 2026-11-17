#!/usr/bin/env python3
"""Compute separate 250-MHz adjacent-band power ratios from digital RF PSD."""
import argparse,csv,json,math
from pathlib import Path

def main():
 p=argparse.ArgumentParser(description=__doc__);p.add_argument('psd',type=Path);p.add_argument('--out',type=Path,required=True);a=p.parse_args()
 if a.out.exists():raise FileExistsError(a.out)
 with a.psd.open(newline='') as f:
  rows=csv.DictReader(f);keys=[k for k in rows.fieldnames if k!='frequency_hz'];sums={k:[0.,0.,0.] for k in keys}
  for row in rows:
   freq=float(row['frequency_hz']);d=freq-3.5e9
   band=0 if -125e6<=d<125e6 else 1 if -375e6<=d< -125e6 else 2 if 125e6<=d<375e6 else -1
   if band>=0:
    for k in keys:sums[k][band]+=float(row[k])
 result={k:{'main_power':v[0],'lower_adjacent_dbc':10*math.log10(v[1]/v[0]),'upper_adjacent_dbc':10*math.log10(v[2]/v[0])} for k,v in sums.items()}
 a.out.write_text(json.dumps({'integration':'positive-frequency, rectangular 250 MHz bands centered at 3.25/3.50/3.75 GHz','not_standard_rf_aclr':True,'values':result},indent=2)+'\n');print(json.dumps(result,indent=2))
if __name__=='__main__':main()
