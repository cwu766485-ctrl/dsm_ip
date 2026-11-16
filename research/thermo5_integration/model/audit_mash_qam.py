#!/usr/bin/env python3
"""P0-P2 isolation from actual RTL captures, with an independent scalar EFM.

No offset optimization is used for acceptance. Correlation is diagnostic only.
Algorithmic word delays come from the registered recurrence: L for Stage 1,
twice L+1 for the aligned MASH outputs. Transport cycles are measured separately.
"""
import argparse
import csv
import hashlib
import json
from pathlib import Path
import sys

import numpy as np

ROOT = Path(__file__).resolve().parents[3]
sys.path.insert(0, str(ROOT/'dv/uvm/refmodel/python'))
from benchmark_thermo5_tid_receiver import (
    RAW_FS_HZ, RX_FIR_TAPS, _blackman_lowpass, _linear_fir_decimate,
    demodulate_metrics, NCP, NFFT,
)

LANES = 32
STAGE1_WORD_DELAY = LANES
# The 35-entry alignment includes the two raw boundary clock stages. In the
# accepted output sequence it contributes 32 words, and the two explicit
# reset-phase FIFO words contribute another two: 32 + 32 + 2 = 66.
MASH_WORD_DELAY = 2 * LANES + 2


def rows(path):
    with path.open() as f:
        return list(csv.DictReader(f))


def scalar_efm(iq):
    """Unsigned first-order error-feedback accumulator, one sample at a time.

    Input signed Q1.15 -> offset binary; carry is the quantizer bit. Reset
    fractional residue is zero. No parallel matrix, DUT state, or stage output
    is used. Fs/4 packing is independently checked at every raw bit.
    """
    residue = [0, 0]
    result = np.empty((len(iq), 2), dtype=np.int8)
    for n, sample in enumerate(iq):
        for c in range(2):
            total = residue[c] + int(sample[c]) + 32768
            result[n, c] = total >> 16
            residue[c] = total & 65535
    return result


def unpack_words(words):
    return np.array([[(w >> b) & 1 for b in range(64)] for w in words],
                    dtype=np.int8).reshape(-1)


def pack_fs4(bits):
    out = bits.copy()
    out[1::2, 0] ^= 1
    out[0::2, 1] ^= 1
    return out.reshape(-1)


def decode_fs4(raw):
    bits = raw.reshape(-1, 2).copy()
    bits[1::2, 0] ^= 1
    bits[0::2, 1] ^= 1
    return 2*bits.astype(np.int16)-1


def ideal_rf(iq):
    """Unquantized Fs/4 digital RF sample stream, with no DSM or PA encoder."""
    rf = np.asarray(iq, dtype=float).copy()
    rf[1::2, 0] *= -1
    rf[0::2, 1] *= -1
    return rf.reshape(-1)


def receive(rf):
    # Exactly the production evaluation's LO, two FIRs, and decimation phases.
    lo = (1+0j, -1j, -1+0j, 1j)
    mixed = [2*float(v)*lo[n & 3] for n, v in enumerate(rf)]
    h0 = _blackman_lowpass(0.75*250e6, RAW_FS_HZ, RX_FIR_TAPS)
    at7g = _linear_fir_decimate(mixed, h0, 2, phase=0)
    h1 = _blackman_lowpass(0.75*250e6, RAW_FS_HZ/2, RX_FIR_TAPS)
    return _linear_fir_decimate(at7g, h1, 4, phase=0), at7g


def metrics(bb, stimulus, source_offset):
    # Offset is a named contract argument, never the result of a lag search.
    meta = dict(stimulus)
    meta['data_start'] += source_offset
    return demodulate_metrics(bb, meta)


def correlation(reference, actual, path, maxlag=768):
    """Normalized linear correlation, actual[n+lag] vs reference[n]."""
    x, y = np.asarray(reference), np.asarray(actual)
    nfft = 1 << (len(x)+len(y)-2).bit_length()
    cross = np.fft.ifft(np.fft.fft(y,nfft)*np.conj(np.fft.fft(x,nfft)))
    ex = np.r_[0., np.cumsum(abs(x)**2)]
    ey = np.r_[0., np.cumsum(abs(y)**2)]
    best = (0., 0)
    with path.open('w') as f:
        w = csv.writer(f); w.writerow(['lag_source_samples','normalized_magnitude'])
        for lag in range(-maxlag, maxlag+1):
            a=max(0,-lag); b=min(len(x),len(y)-lag)
            denom=np.sqrt(max(1e-300,(ex[b]-ex[a])*(ey[b+lag]-ey[a+lag])))
            value=float(abs(cross[lag % nfft])/denom)
            w.writerow([lag,value])
            if value>best[0]: best=(value,lag)
    return {'peak_normalized_magnitude':best[0], 'diagnostic_lag_source_samples':best[1]}


def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--capture', type=Path, required=True)
    ap.add_argument('--output', type=Path, required=True)
    args=ap.parse_args()
    cap=args.capture.resolve(); out=args.output.resolve()
    out.mkdir(parents=True,exist_ok=False)
    stimulus=json.loads((cap/'stimulus.json').read_text())
    stimulus['qam_rows']=[[complex(*v) for v in row] for row in stimulus['qam_rows']]
    pre=rows(cap/'pre_words.csv'); stage=rows(cap/'stage1_words.csv')
    pairs=rows(cap/'stage_pairs.csv'); events=rows(cap/'events.csv')
    assert len(pre)==len(stage)==len(pairs)==stimulus['frontend_words']
    iq=np.array([[(lambda v: v-65536 if v&32768 else v)((int(r[k],16)>>(16*l))&65535)
                  for k in ('i_hex','q_hex')] for r in pre for l in range(32)],dtype=np.int32)
    np.savetxt(out/'pre_dsm_cartesian.csv',iq,delimiter=',',fmt='%d',header='i,q',comments='')

    # P0: independent known DC, tone and impulse. DC amplitude/phase is checked
    # before fitting gain, so conjugation or a reversed LO cannot pass unnoticed.
    count=65536; n=np.arange(count); tests={}
    for name, z in (
        ('dc_i', np.ones(count,dtype=complex)*0.2),
        ('dc_q', np.ones(count,dtype=complex)*0.2j),
        ('tone', 0.2*np.exp(2j*np.pi*40e6*n/(RAW_FS_HZ/2))),
        ('impulse', np.where(n==count//2,0.2+0.1j,0j)),
    ):
        bb,_=receive(ideal_rf(np.c_[z.real,z.imag]))
        bb=np.array(bb); target=z[::4]
        valid=slice(2048,-2048)
        if name.startswith('dc'):
            error=float(np.max(abs(bb[valid]-target[valid])))
            assert error<1e-5,(name,error)
            tests[name]={'max_complex_error':error}
        elif name=='tone':
            # Fs/4 multiplexing staggers I and Q by one raw sample, leaving a
            # small image. Fit phase over the full interior instead of treating
            # the biased one-step autocorrelation as an exact frequency meter.
            phase=np.unwrap(np.angle(bb[valid]))
            measured=float(np.polyfit(np.arange(len(phase)),phase,1)[0]*(RAW_FS_HZ/8)/(2*np.pi))
            resolution=(RAW_FS_HZ/8)/len(phase)
            assert abs(measured-40e6)<resolution,measured
            tests[name]={'measured_frequency_hz':measured,'expected_frequency_hz':40e6}
        else:
            peak=int(np.argmax(abs(bb)))
            assert peak==count//8,peak
            tests[name]={'peak_source_sample':peak,'expected_source_sample':count//8}
        print('P0',name,tests[name],flush=True)

    # P1: compare all RTL bits, including the defined reset fill. The final
    # 33 input words do not emerge before stream end and are explicitly counted.
    scalar=scalar_efm(iq)
    scalar_raw=pack_fs4(scalar)
    actual=unpack_words([int(r['raw_hex'],16) for r in stage])
    fill=pack_fs4(np.zeros((STAGE1_WORD_DELAY*32,2),dtype=np.int8))
    expected=np.r_[fill,scalar_raw][:len(actual)]
    bad=np.flatnonzero(actual!=expected)
    with (out/'stage1_bittrue.csv').open('w') as f:
        w=csv.writer(f);w.writerow(['output_word','raw_bit','source_sample','component','rtl','golden','vcd_time_ps','mismatch'])
        for idx,(a,b) in enumerate(zip(actual,expected)):
            word=idx//64; sample=idx//2-STAGE1_WORD_DELAY*32
            w.writerow([word,idx%64,sample,'IQ'[idx%2],int(a),int(b),stage[word]['time_ps'],int(a!=b)])
    unshifted=np.flatnonzero(actual!=scalar_raw)
    p1={'samples_captured':len(iq),'raw_bits_compared':len(actual),
        'total_mismatch':len(bad),'first_mismatch':int(bad[0]) if len(bad) else None,
        'algorithmic_delay_words':STAGE1_WORD_DELAY,
        'valid_source_samples_compared':len(iq)-STAGE1_WORD_DELAY*32,
        'unemitted_tail_samples':STAGE1_WORD_DELAY*32,
        'unshifted_first_mismatch':int(unshifted[0]) if len(unshifted) else None,
        'first_output_time_ps':stage[0]['time_ps'],
        'last_output_time_ps':stage[-1]['time_ps'],
        'input_bubbles':sum(int(r['pre_valid'])==0 for r in events),
        'stage1_output_bubbles':sum(int(r['stage1_valid'])==0 for r in events),
        'word_transport_cycles':sorted(set(int(s['cycle'])-int(p['cycle']) for p,s in zip(pre,stage)))}
    (out/'stage1_summary.json').write_text(json.dumps(p1,indent=2)+'\n')
    assert not len(bad),p1
    print('P1',p1,flush=True)

    # P2 four isolation paths, same receiver and source. A includes the actual
    # frontend interpolation, but no DSM. B is purely scalar from captured input.
    pa0=unpack_words([int(r['pa0_hex'],16) for r in pairs])
    pa1=unpack_words([int(r['pa1_hex'],16) for r in pairs])
    rf_cases={'A_ideal_fs4':(ideal_rf(iq/32768.),0),
              'B_scalar_stage1':(2*scalar_raw.astype(float)-1,0),
              'C_rtl_stage1':(2*actual.astype(float)-1,STAGE1_WORD_DELAY*32//4),
              'D_rtl_weighted_mash':(2*pa0.astype(float)-1+2*(2*pa1.astype(float)-1),MASH_WORD_DELAY*32//4)}
    results={}; reference=None
    for name,(rf,offset) in rf_cases.items():
        bb,_=receive(rf)
        if reference is None:reference=bb
        corr=correlation(reference,bb,out/(name+'_correlation_vs_lag.csv'))
        before=metrics(bb,stimulus,0); after=metrics(bb,stimulus,offset)
        results[name]={'fixed_contract_source_offset':offset,'before':before,'after':after,'correlation':corr}
        if name=='A_ideal_fs4':
            assert after['evm_percent']<=3.5,after
            tests['qam256']=after
        print('P2',name,'offset',offset,'EVM',after['evm_percent'],'lag',corr,flush=True)
    summary={'status':'P0_P1_P2_COMPLETE_P3_P4_PENDING','p0':tests,'p1':p1,'isolation':results,
        'timing_contract':{'source_guard_samples':stimulus['data_start'],'lane_samples_per_word':32,
            'stage1_algorithmic_words':STAGE1_WORD_DELAY,'mash_output_algorithmic_words':MASH_WORD_DELAY,
            'stage_alignment_register_entries':35,'encoder_cycles':1,
            'raw_bits_per_complex_sample':2,'stage1_raw_bit_offset':STAGE1_WORD_DELAY*64,
            'mash_raw_bit_offset':MASH_WORD_DELAY*64,'fir0_group_delay_raw_samples':(RX_FIR_TAPS-1)//2,
            'fir1_group_delay_7g_samples':(RX_FIR_TAPS-1)//2,
            'fir_delay_policy':'Both existing FIR functions explicitly compensate group delay before decimation.',
            'decimation_phases':[0,0],'cp_samples':NCP,'fft_samples':NFFT,
            'acceptance_offset_policy':'fixed recurrence-derived delay; no diagnostic correlation result enters metrics'},
        'input_sha256':{n:hashlib.sha256((cap/n).read_bytes()).hexdigest()
                        for n in ('pre_words.csv','stage1_words.csv','stage_pairs.csv','audit.vcd','stimulus.json')}}
    (out/'isolation_summary.json').write_text(json.dumps(summary,indent=2)+'\n')


if __name__=='__main__':
    main()
