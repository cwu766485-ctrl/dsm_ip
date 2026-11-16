#!/usr/bin/env python3
"""Independent Fs/4 receiver smoke; no RTL, DSM, DPD, or PA oracle required."""
import argparse
import json
from pathlib import Path
import numpy as np
from audit_mash_qam import ideal_rf,receive,metrics,RAW_FS_HZ
from benchmark_thermo5_tid_receiver import make_256qam_ofdm


def main():
    p=argparse.ArgumentParser(description=__doc__);p.add_argument('--output',type=Path,required=True)
    a=p.parse_args();a.output.mkdir(parents=True,exist_ok=False)
    n=np.arange(32768);results={}
    for name,z in [('dc_i',np.full(len(n),.2+0j)),('dc_q',np.full(len(n),.2j)),
                   ('tone',.2*np.exp(2j*np.pi*40e6*n/(RAW_FS_HZ/2))),
                   ('impulse',np.where(n==16384,.2+.1j,0j))]:
        bb,_=receive(ideal_rf(np.c_[z.real,z.imag]));bb=np.asarray(bb)
        if name.startswith('dc'):
            error=float(np.max(abs(bb[2048:-2048]-z[::4][2048:-2048])))
            assert error<1e-5;results[name]={'complex_error':error}
        elif name=='tone':
            phase=np.unwrap(np.angle(bb[2048:-2048]));freq=float(np.polyfit(np.arange(len(phase)),phase,1)[0]*RAW_FS_HZ/8/(2*np.pi))
            assert abs(freq-40e6)<(RAW_FS_HZ/8)/len(phase)
            results[name]={'positive_frequency_hz':freq}
        else:
            peak=int(np.argmax(abs(bb)));assert peak==4096
            results[name]={'peak_source_sample':peak}
    stim=make_256qam_ofdm(281001,symbols=2,rms_drive=.09)
    x=np.array([complex(i,q)/32768. for i,q in stim['source_iq']])
    # Ideal band-limited interpolation by four in the DFT domain. Source
    # sample positions are unchanged; this does not invoke the RTL frontend.
    spec=np.fft.fft(x);dense=np.zeros(4*len(x),dtype=complex);half=len(x)//2
    dense[:half]=spec[:half];dense[-half:]=spec[-half:]
    iq=np.fft.ifft(dense)*4
    bb,_=receive(ideal_rf(np.c_[iq.real,iq.imag]))
    result=metrics(bb,stim,0)
    assert result['evm_percent']<=3.5 and result['sndr_db']>=29.12,result
    results['qam256']=result
    results['contract']={'raw_mapping':'I0,-Q0,-I1,Q1; bit0 first',
        'ddc_lo':[str(v) for v in (1+0j,-1j,-1+0j,1j)],
        'decimation_phases':[0,0],'fir_delay':'centered offline FIRs compensate group delay',
        'fft_window':'source data_start + CP, zero DSM offset',
        'ideal_input':'unquantized digital RF samples; a binary ideal RF signal would require quantization'}
    (a.output/'receiver_smoke.json').write_text(json.dumps(results,indent=2)+'\n')
    print('RECEIVER_SMOKE_PASS '+json.dumps(results['qam256']),flush=True)


if __name__=='__main__':main()
