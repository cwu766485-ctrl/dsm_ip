"""Independent integer port of MATLAB range_stress oracle; validate before use.

Preserves signed rounding, modulo 17-bit state, update order and four-plane
word packing. Does not read DUT state or simulate RTL. Golden MATLAB fixtures
must match every output before a larger stream is emitted.
"""
import argparse, hashlib, json
from pathlib import Path
import numpy as np

ROOT=Path(__file__).resolve().parents[2]
NAMES=('i','q','frame_start','frame_gain','pa0','pa1','pa2','pa3')

def samples(words):
    low=((np.arange(words)//4)%2)==0
    i=np.where(low[:,None],-32768,32767)*np.ones((1,8),dtype=np.int64)
    q=np.where(low[:,None],32767,-32768)*np.ones((1,8),dtype=np.int64)
    i[0]=[-32768,-24000,-1,0,1,12000,24000,32767]
    q[0]=[32767,24000,1,0,-1,-12000,-24000,-32768]
    return i,q

def interpolate(x):
    flat=x.ravel();previous=np.concatenate(([0],flat[:-1]))
    acc=(flat+previous)*8192
    rounded=np.where(acc>=0,(acc+8192)//16384,-((-acc+8192)//16384))
    result=np.empty(flat.size*2,dtype=np.int64)
    result[::2]=flat;result[1::2]=np.clip(rounded,-32768,32767)
    return result.reshape(len(x),-1)

def oracle(words):
    i,q=samples(words)
    xi=interpolate(interpolate(i));xq=interpolate(interpolate(q))
    offsets=np.array([3,1,-1,-3],dtype=np.int64)*7168
    ai=np.zeros((4,32,32),dtype=np.int64);aq=ai.copy()
    vi=np.zeros((4,32),dtype=np.int64);vq=vi.copy()
    result=np.empty((words,4),dtype=np.uint64)
    index=np.arange(1,32);weights=np.left_shift(np.uint64(1),np.arange(64,dtype=np.uint64))
    def wrap(x):return (x+65536)%131072-65536
    for word in range(words+1):
        yi=vi<0;yq=vq<0
        yi[:,1:]=yi[:,1:]^yi[:,:-1];yq[:,1:]=yq[:,1:]^yq[:,:-1]
        yi[:,1::2]=~yi[:,1::2];yq[:,::2]=~yq[:,::2]
        if word:
            bits=np.empty((4,64),dtype=np.uint64);bits[:,::2]=yi;bits[:,1::2]=yq
            result[word-1]=bits@weights
        if word==words:break
        ni=np.empty_like(ai);nq=np.empty_like(aq)
        ni[:,:,0]=wrap((np.clip(xi[word][None,:]+offsets[:,None],-32768,32767)+32768)%65536)
        nq[:,:,0]=wrap((np.clip(xq[word][None,:]+offsets[:,None],-32768,32767)+32768)%65536)
        ni[:,:,1:]=ai[:,:,:-1];nq[:,:,1:]=aq[:,:,:-1]
        ni[:,index,index]=wrap(ai[:,index-1,index-1]+ai[:,index,index-1])
        nq[:,index,index]=wrap(aq[:,index-1,index-1]+aq[:,index,index-1])
        vi=wrap(ai[:,:,31]+(vi[:,31]%65536)[:,None]);vq=wrap(aq[:,:,31]+(vq[:,31]%65536)[:,None])
        ai,aq=ni,nq
    frame=np.zeros(words,dtype=np.int64);frame[np.array([1,15,36])-1]=1
    return dict(i=i.ravel(),q=q.ravel(),frame_start=frame,frame_gain=np.full(words,16384),
                **{f'pa{b}':result[:,b] for b in range(4)})

def read(p):return np.array([int(s,16) for s in p.read_text().split()],dtype=np.uint64)

def main():
    ap=argparse.ArgumentParser(description=__doc__)
    ap.add_argument('--matlab-fixture',type=Path,required=True)
    ap.add_argument('--words',type=int,required=True)
    ap.add_argument('--out',type=Path,required=True)
    args=ap.parse_args()
    assert args.words>=56 and args.words%7==0
    assert ROOT/'runs' in args.out.resolve().parents and not args.out.exists()
    count=len((args.matlab_fixture/'tid32_thermo5_frontend_pa0.mem').read_text().split())
    validation=oracle(count);hashes={}
    for name in NAMES:
        path=args.matlab_fixture/f'tid32_thermo5_frontend_{name}.mem'
        assert np.array_equal(validation[name].astype(np.uint64) & (65535 if name in ('i','q') else 2**64-1),read(path)),('MATLAB mismatch',name)
        hashes[path.name]=hashlib.sha256(path.read_bytes()).hexdigest()
    print(f'MATLAB_ALL_EIGHT_FILES_MATCH words={count}',flush=True)
    vectors=oracle(args.words);args.out.mkdir(parents=True)
    for name,values in vectors.items():
        width=16 if name.startswith('pa') else 4
        mask=2**64-1 if width==16 else 65535
        (args.out/f'tid32_thermo5_frontend_{name}.mem').write_text(''.join(f'{int(v)&mask:0{width}X}\n' for v in values),newline='\n')
    sources=[ROOT/'tools/hw/thermo5_range_oracle.py',*[ROOT/'matlab/tx_bandpass_if'/n for n in ('gen_tid32_thermo5_frontend_bittrue_vectors.m','tid_thermo5_pipelined_step.m','tid_pipelined_first_order_step.m')]]
    manifest={'status':'MATLAB_VALIDATED_INDEPENDENT_INTEGER_ORACLE','words':args.words,'fixture_words':count,'fixture_sha256':hashes,'source_sha256':{p.relative_to(ROOT).as_posix():hashlib.sha256(p.read_bytes()).hexdigest() for p in sources},'output_sha256':{p.name:hashlib.sha256(p.read_bytes()).hexdigest() for p in args.out.glob('*.mem')}}
    (args.out/'oracle_manifest.json').write_text(json.dumps(manifest,indent=2)+'\n')
    print(f'ORACLE_COMPLETE words={args.words}',flush=True)

if __name__=='__main__':main()
