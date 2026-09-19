function result = run_256qam_tid32_ofdm_demod(varargin)
%RUN_256QAM_TID32_OFDM_DEMOD OFDM-domain EVM for scalar or L=32 TIDSM.
%
% Unlike the historical time-domain exploratory screens, this model removes
% the cyclic prefix, FFT-demodulates each OFDM symbol and compares only active
% 256-QAM subcarriers after one complex gain correction.

cfg.fs_iq_hz = 7e9; cfg.fs_out_hz = 14e9; cfg.fc_hz = 3.5e9;
cfg.bandwidth_hz = 19.65e6; cfg.nfft = 4096; cfg.ncp = 512; cfg.nsym = 16;
cfg.drive = 0.35; cfg.seed = 20260915; cfg.implementation = "tid32";
cfg.thermo_offset = 8192;
cfg.thermo5_step = 4096;
cfg.input_normalization = "peak"; % legacy peak or fair_rms
cfg.rms_drive = 0.13;
cfg.receiver_mode = "legacy_iq"; % legacy_iq or fs4_ddc
cfg.max_ddc_delay = 128;
for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end
[x, active_bins, qam, actual_bw] = local_make_ofdm(cfg);
[input_rms,input_peak]=local_input_levels(x);
[y_i, y_q, y_rf, sample_start, latency, stream_mismatches] = local_modulate_with_flush(x, cfg);
n = numel(x); f = ((0:numel(y_i)-1).'-floor(numel(y_i)/2))*cfg.fs_iq_hz/numel(y_i);
if string(cfg.receiver_mode)=="fs4_ddc"
    % Exercise the physical digital modulation boundary: the actual raw
    % Fs/4 word is downconverted at 3.5 GHz, low-passed and decimated.  This
    % is required for comparing thermometric multi-PA candidates; the old
    % I/Q shortcut is retained below solely for historical compatibility.
    raw=y_rf(2*latency+1:end); nr=numel(raw); kr=(0:nr-1).';
    ddc=2*raw(:).*exp(-1j*2*pi*cfg.fc_hz/cfg.fs_out_hz*kr);
    fr=((0:nr-1).'-floor(nr/2))*cfg.fs_out_hz/nr;
    bb=ifft(ifftshift(fftshift(fft(ddc)).*(abs(fr)<=0.75*actual_bw)));
    guard=32*80; source=[zeros(guard,1);x;zeros(guard,1)];
    best=inf; z=[];
    for phase=0:1
        candidate=bb(phase+1:2:end);
        [score,gain,delay]=local_best_map(candidate,source,cfg.max_ddc_delay);
        if score<best
            best=score; z=zeros(size(source));
            ti=max(1,1-delay):min(numel(source),numel(candidate)-delay); ci=ti+delay;
            z(ti)=candidate(ci)*gain;
        end
    end
else
    y_i = y_i(latency+1:end); y_q = y_q(latency+1:end);
    % Historical I/Q shortcut; it does not validate the Fs/4 DDC boundary.
    f = ((0:numel(y_i)-1).'-floor(numel(y_i)/2))*cfg.fs_iq_hz/numel(y_i);
    lp = abs(f) <= 0.75*actual_bw;
    z = ifft(ifftshift(fftshift(fft(y_i)).*lp)) + 1j*ifft(ifftshift(fftshift(fft(y_q)).*lp));
end
% The TIDSM is a fixed-latency streaming machine.  A zero guard before and
% after the OFDM frame prevents the ideal receiver filter from seeing either
% reset/start-up state or a circular FFT boundary.  sample_start already
% is indexed after the implementation latency has been removed.
z = z(sample_start:sample_start+n-1);
frame = cfg.nfft + cfg.ncp;
z = reshape(z, frame, cfg.nsym);
Z = fftshift(fft(z(cfg.ncp+1:end,:), cfg.nfft, 1), 1);
rx = Z(active_bins,:);
gain = sum(conj(rx(:)).*qam(:)) / (sum(abs(rx(:)).^2)+eps);
rx = rx*gain;
err = rx-qam;
evm = 100*sqrt(mean(abs(err(:)).^2)/mean(abs(qam(:)).^2));
sndr = 10*log10(mean(abs(qam(:)).^2)/mean(abs(err(:)).^2));

y_rf = y_rf(2*latency+1:end);
nrf = numel(y_rf); frf=((0:nrf-1).'-floor(nrf/2))*cfg.fs_out_hz/nrf;
p=abs(fftshift(fft(y_rf))).^2; main=abs(frf-cfg.fc_hz)<=actual_bw/2;
adj_l=abs(frf-(cfg.fc_hz-1.5*actual_bw))<=actual_bw/2;
adj_h=abs(frf-(cfg.fc_hz+1.5*actual_bw))<=actual_bw/2;
aclr=10*log10((mean([sum(p(adj_l)),sum(p(adj_h))])+eps)/(sum(p(main))+eps));
result=table(actual_bw,cfg.fs_out_hz/(2*actual_bw),input_rms,input_peak,latency,stream_mismatches,evm,sndr,aclr, ...
    evm<=3.5 && sndr>=29.12,'VariableNames',{'OccupiedBW_Hz','OSR','InputRMS','InputPeak', ...
    'Latency_samples','StreamMismatches','EVM_percent','SNDR_dB','ACLR_dBc','Pass256QAM'});
disp(result);
end

function [x, bins, qam, bw] = local_make_ofdm(c)
rng(c.seed); df=c.fs_iq_hz/c.nfft;
nused=max(2,2*floor(c.bandwidth_hz/(2*df))); bw=nused*df;
bins=[c.nfft/2-nused/2+1:c.nfft/2, c.nfft/2+2:c.nfft/2+1+nused/2];
idx=randi([0 255],nused,c.nsym);
qam=complex(2*mod(idx,16)-15,2*floor(idx/16)-15);
qam=qam/sqrt(mean(abs(qam).^2,'all'));
X=zeros(c.nfft,c.nsym); X(bins,:)=qam;
s=ifft(ifftshift(X,1),c.nfft,1); x=[s(end-c.ncp+1:end,:);s]; x=x(:);
if string(c.input_normalization)=="fair_rms"
    x=c.rms_drive*x/(sqrt(mean(abs(x).^2))+eps);
    assert(max(abs(x))<=c.drive+eps, ...
        'fair_rms waveform exceeds configured peak drive; lower rms_drive or raise drive.');
else
    x=c.drive*x/max(abs(x));
end
assert(mod(numel(x),32)==0,'OFDM sample count must divide by 32.');
end

function [y_i,y_q,y_rf,sample_start,latency,stream_mismatches] = local_modulate_with_flush(x,c)
% A 2,560-sample guard is longer than the narrowest ideal LPF impulse
% response used by this test.  It makes scalar and pipelined implementations
% see the same settled input context before the first OFDM sample.
guard=32*80; source_len=numel(x);
x=[zeros(guard,1); x; zeros(guard,1)]; n=numel(x);
xi=int64(round(real(x)*32767)); xq=int64(round(imag(x)*32767));
y_i=zeros(n,1); y_q=zeros(n,1); y_rf=zeros(2*n,1);
if c.implementation == "tid32"
    state=[];
    for first=1:32:n
        [raw,state]=tid_pipelined_first_order_step(xi(first:first+31),xq(first:first+31),state,16);
        for lane=1:32
            ib=2*double(raw(2*lane-1))-1; qb=2*double(raw(2*lane))-1;
            if mod(lane-1,2)==0, y_i(first+lane-1)=ib; y_q(first+lane-1)=-qb;
            else, y_i(first+lane-1)=-ib; y_q(first+lane-1)=qb; end
            y_rf(2*(first+lane-1)-1)=ib; y_rf(2*(first+lane-1))=qb;
        end
    end
    latency=1056;
    % This independently checks the actual de-interleaved I/Q bit stream
    % used by the OFDM receiver, not just the abstract state-map contract.
    ref_i = zeros(n,1); ref_q = zeros(n,1); vi=int64(0); vq=int64(0);
    for k=1:n
        [ib,vi]=local_efm_bit(xi(k),vi); [qb,vq]=local_efm_bit(xq(k),vq);
        ref_i(k)=2*double(ib)-1; ref_q(k)=2*double(qb)-1;
    end
    stream_mismatches = nnz(y_i(latency+1:end) ~= ref_i(1:end-latency)) + ...
                        nnz(y_q(latency+1:end) ~= ref_q(1:end-latency));
elseif c.implementation == "scalar_efm"
    vi=int64(0); vq=int64(0);
    for k=1:n
        [ib,vi]=local_efm_bit(xi(k),vi); [qb,vq]=local_efm_bit(xq(k),vq);
        y_i(k)=2*double(ib)-1; y_q(k)=2*double(qb)-1;
        y_rf(2*k-1)=y_i(k); y_rf(2*k)=-y_q(k);
    end
    latency=0;
    stream_mismatches = 0;
elseif c.implementation == "scalar_bp3l_ef2" || c.implementation == "scalar_bp3l_ef4"
    % Behavioral feasibility only: a three-level Fs/4 bandpass EFDSM.  The
    % one real-valued RF stream is decomposed back into Cartesian I/Q before
    % the same OFDM receiver.  It is deliberately kept separate from the
    % pipelined-TID implementation until a scalar-vs-TID state contract has
    % been derived and proven.
    phase=mod((0:2*n-1).',4);
    in=zeros(2*n,1,'int64');
    in(1:2:end)=xi;
    in(2:2:end)=xq;
    in(phase==2 | phase==3)=-in(phase==2 | phase==3);
    if c.implementation == "scalar_bp3l_ef2"
        raw=double(bp_ef2_3level_fs4_model(in));
    else
        raw=double(bp_ef4_3level_fs4_model(in));
    end
    odd=(1:2:n).'; even=(2:2:n).';
    y_i(odd)=raw(2*odd-1);  y_i(even)=-raw(2*even-1);
    y_q(odd)=raw(2*odd);    y_q(even)=-raw(2*even);
    y_rf=raw;
    latency=0;
    stream_mismatches = 0;
elseif c.implementation == "tid32_thermo3"
    % Two independently pipelined first-order Cartesian TIDSM branches form
    % a thermometer-coded three-level output. Their input offsets are
    % symmetric, so the desired-signal DC terms cancel after equal-weight PA
    % combining. This remains a TID-friendly first-order architecture: each
    % branch is the already-proven L=32 state transform, not a hidden
    % high-order temporal recurrence.
    state=[];
    for first=1:32:n
        [raw_p,raw_m,state]=tid_thermo3_pipelined_step( ...
            xi(first:first+31),xq(first:first+31),state,16,c.thermo_offset);
        for lane=1:32
            [bpi,bpq]=local_decode_fs4(raw_p,lane);
            [bmi,bmq]=local_decode_fs4(raw_m,lane);
            y_i(first+lane-1)=0.5*(local_pm(bpi)+local_pm(bmi));
            y_q(first+lane-1)=0.5*(local_pm(bpq)+local_pm(bmq));
            y_rf(2*(first+lane-1)-1)=local_pm(raw_p(2*lane-1))+local_pm(raw_m(2*lane-1));
            y_rf(2*(first+lane-1))=local_pm(raw_p(2*lane))+local_pm(raw_m(2*lane));
        end
    end
    latency=1056;
    xi_p=local_sat16(xi+int64(c.thermo_offset)); xq_p=local_sat16(xq+int64(c.thermo_offset));
    xi_m=local_sat16(xi-int64(c.thermo_offset)); xq_m=local_sat16(xq-int64(c.thermo_offset));
    ref_pi=zeros(n,1); ref_pq=zeros(n,1); ref_mi=zeros(n,1); ref_mq=zeros(n,1);
    vip=int64(0); vqp=int64(0); vim=int64(0); vqm=int64(0);
    for k=1:n
        [bp,vip]=local_efm_bit(xi_p(k),vip); [bq,vqp]=local_efm_bit(xq_p(k),vqp);
        [bm,vim]=local_efm_bit(xi_m(k),vim); [bn,vqm]=local_efm_bit(xq_m(k),vqm);
        ref_pi(k)=local_pm(bp); ref_pq(k)=local_pm(bq);
        ref_mi(k)=local_pm(bm); ref_mq(k)=local_pm(bn);
    end
    ref_i=0.5*(ref_pi+ref_mi); ref_q=0.5*(ref_pq+ref_mq);
    stream_mismatches=nnz(y_i(latency+1:end) ~= ref_i(1:end-latency)) + ...
                      nnz(y_q(latency+1:end) ~= ref_q(1:end-latency));
elseif c.implementation == "tid32_thermo5"
    % Four symmetric first-order TID branches form five thermometric levels.
    % This is behavioral feasibility only until its four-serializer RTL and
    % scalar-vs-RTL raw-word contract are added.
    state=[];
    for first=1:32:n
        [raw,state]=tid_thermo5_pipelined_step(xi(first:first+31),xq(first:first+31), ...
            state,16,c.thermo5_step);
        for lane=1:32
            si=0; sq=0;
            for b=1:4
                [bi,bq]=local_decode_fs4(raw(:,b),lane);
                si=si+local_pm(bi); sq=sq+local_pm(bq);
            end
            y_i(first+lane-1)=0.25*si; y_q(first+lane-1)=0.25*sq;
            y_rf(2*(first+lane-1)-1)=sum(2*double(raw(2*lane-1,:))-1);
            y_rf(2*(first+lane-1))=sum(2*double(raw(2*lane,:))-1);
        end
    end
    latency=1056; offsets=int64([3 1 -1 -3])*int64(c.thermo5_step);
    ref_i=zeros(n,1); ref_q=zeros(n,1); vi=zeros(4,1,'int64'); vq=zeros(4,1,'int64');
    for k=1:n
        si=0; sq=0;
        for b=1:4
            [bi,vi(b)]=local_efm_bit(local_sat16(xi(k)+offsets(b)),vi(b));
            [bq,vq(b)]=local_efm_bit(local_sat16(xq(k)+offsets(b)),vq(b));
            si=si+local_pm(bi); sq=sq+local_pm(bq);
        end
        ref_i(k)=0.25*si; ref_q(k)=0.25*sq;
    end
    stream_mismatches=nnz(y_i(latency+1:end) ~= ref_i(1:end-latency)) + ...
                      nnz(y_q(latency+1:end) ~= ref_q(1:end-latency));
elseif c.implementation == "tid_mash11"
    % Ideal two-PA realization of the MASH digital cancellation.  For each
    % Cartesian sample, y=y1+y2-z^-1*y2 is in {-3,-1,+1,+3}.  It is exactly
    % represented by two 1-bit PA code planes with analog weights 1 and 2;
    % this model evaluates their weighted sum, not an invalid equal-weight
    % sum of the raw stage streams.
    state=[]; prev_i=false; prev_q=false;
    for first=1:32:n
        [s1,s2,state]=tid_mash11_pipelined_step(xi(first:first+31),xq(first:first+31),state,16);
        for lane=1:32
            [b1i,b1q]=local_decode_fs4(s1,lane);
            [b2i,b2q]=local_decode_fs4(s2,lane);
            y_i(first+lane-1)=local_pm(b1i)+local_pm(b2i)-local_pm(prev_i);
            y_q(first+lane-1)=local_pm(b1q)+local_pm(b2q)-local_pm(prev_q);
            prev_i=b2i; prev_q=b2q;
            y_rf(2*(first+lane-1)-1)=y_i(first+lane-1);
            y_rf(2*(first+lane-1))=-y_q(first+lane-1);
        end
    end
    % Two L=32 TID stages plus the reset/word-boundary alignment.  The guard
    % is longer than this value, so no start-up content enters the receiver.
    latency=2176;
    stream_mismatches = 0;
else
    error('Unsupported implementation: %s',c.implementation);
end
sample_start=guard+1;
assert(sample_start+source_len-1<=n, 'Guard/flush is shorter than required.');
end

function [bit,v]=local_efm_bit(x,v)
u=mod(int64(x)+int64(32768),int64(65536));
v=mod(u+mod(v,int64(65536)),int64(131072)); bit=v>=65536;
end

function [ib,qb]=local_decode_fs4(raw,lane)
if mod(lane-1,2)==0
    ib=raw(2*lane-1); qb=~raw(2*lane);
else
    ib=~raw(2*lane-1); qb=raw(2*lane);
end
end

function y=local_pm(bit)
if bit, y=1; else, y=-1; end
end

function y=local_sat16(x)
y=min(max(int64(x),int64(-32768)),int64(32767));
end
function [r,p]=local_input_levels(x), r=sqrt(mean(abs(x(:)).^2)); p=max(abs(x(:))); end
function [score,gain,delay]=local_best_map(y,x,maxdelay)
score=inf; gain=1; delay=0;
for d=-maxdelay:maxdelay
    ti=max(1,1-d):min(numel(x),numel(y)-d); ci=ti+d;
    if numel(ti)<32, continue; end
    yy=y(ci); xx=x(ti); g=(yy'*xx)/(yy'*yy+eps);
    e=mean(abs(yy*g-xx).^2)/(mean(abs(xx).^2)+eps);
    if e<score, score=e; gain=g; delay=d; end
end
end
