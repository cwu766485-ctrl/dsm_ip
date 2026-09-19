function [Results, Coefficients, Detail] = run_tid32_thermo3_frontend_pa_dpd(varargin)
%RUN_TID32_THERMO3_FRONTEND_PA_DPD End-to-end behavioral frontend test.
%  1.75-GS/s 256-QAM OFDM -> x2 -> Q1.15/Q2.14 memory DPD -> x2 ->
%  7-GS/s Cartesian thermometric TID -> two or four 14-GS/s switching-PA
%  paths -> equal-weight combiner -> ideal BPF/DDC -> OFDM receiver.
%
% This is a reproducible behavioral-RF experiment.  It deliberately models
% the two PA paths, their gain/memory mismatch, BPF and DDC, but is not ADS,
% transistor, EM, board, GTH-jitter or measured-RF evidence.  The DPD uses
% the same Q1.15/Q2.14 4-tap, 1/3/5-order arithmetic convention as the RTL.

cfg = local_default_cfg();
for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end
assert(ismember(cfg.thermo_levels, [3 5]), 'thermo_levels must be 3 or 5.');
assert(isscalar(cfg.dpd_active_taps) && cfg.dpd_active_taps >= 1 && cfg.dpd_active_taps <= 4, ...
    'dpd_active_taps must be an integer in [1,4].');
cfg.dpd_active_taps = round(cfg.dpd_active_taps);

[fit_x, fit_meta] = local_ofdm(cfg, cfg.fit_seed, cfg.fit_nsym);
[val_x, val_meta] = local_ofdm(cfg, cfg.val_seed, cfg.val_nsym);
[test_x, test_meta] = local_ofdm(cfg, cfg.test_seed, cfg.test_nsym);

identity = local_identity_coeff();
% Gate 0: use exactly the generated PA words, without an RF receiver, and
% prove their de-interleaving against the scalar thermo3 transition.  This
% distinguishes a raw-word/order bug from a BPF/DDC modelling bug.
[~,~,~,~,tid_input,~,~,~,raw_words] = local_transmit(test_x, identity, cfg);
sanity = local_raw_word_sanity(raw_words, tid_input, cfg);
assert(sanity.mismatches == 0, 'raw-word de-interleave sanity mismatch');
rf_sanity = local_rf_ddc_sanity(raw_words, cfg);
if cfg.sanity_only
    Results=table(sanity.mismatches,sanity.latency,rf_sanity.nmse,rf_sanity.phase,rf_sanity.delay, ...
        'VariableNames',{'RawWordMismatches','Latency_samples','IdealRFDDC_NMSE','DDCPhase','DDCDelay'});
    Coefficients=local_coeff_table(identity,"identity");
    Detail=struct('raw_word_sanity',sanity,'rf_ddc_sanity',rf_sanity);
    if cfg.write_outputs
        if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
        writetable(Results,fullfile(cfg.out_dir,'tid32_thermo3_raw_word_sanity.csv'));
    end
    disp(Results);
    return;
end
% Indirect-learning is deliberately disabled until the ideal PA/BPF/DDC
% endpoint is accepted.  When enabled, identify a memory-polynomial
% post-distorter from the actual two-PA/BPF/DDC feedback at 3.5 GS/s, then
% reuse its quantized coefficients as the pre-distorter.  A validation
% comparison rejects a learned set that makes the fixed-point result worse.
if cfg.enable_dpd_training
    [fit_fb, fit_dpd_in] = local_endpoint_rate(fit_x, identity, cfg, 2);
    learned = local_fit_dpd_candidate(fit_fb, fit_dpd_in, cfg);
    validation_identity_mse = local_rate_mse(val_x, identity, cfg);
    validation_candidate_mse = local_rate_mse(val_x, learned, cfg);
    % The DPD deployment objective is OFDM demodulation, not raw sample MSE:
    % DSM noise and deterministic interpolation phase otherwise dominate the
    % ILA score.  Channel coefficients are fitted only on `fit_x`, then held
    % fixed while the independent validation waveform is decoded.
    [validation_identity_evm, validation_identity_sndr] = local_validation_ofdm( ...
        fit_x, fit_meta, val_x, val_meta, identity, cfg);
    [validation_candidate_evm, validation_candidate_sndr] = local_validation_ofdm( ...
        fit_x, fit_meta, val_x, val_meta, learned, cfg);
    candidate_validated = validation_candidate_evm <= validation_identity_evm && ...
        validation_candidate_sndr >= validation_identity_sndr && ...
        validation_candidate_evm <= 3.5 && validation_candidate_sndr >= 29.12;
    % Always retain the candidate as a diagnostic endpoint.  Deployment is
    % still governed independently by validation and held-out acceptance;
    % this makes spectra and EVM comparisons auditable even when rejection
    % correctly keeps the RTL coefficient table at identity.
    modes = {"identity", identity; "diagnostic_candidate_" + string(cfg.dpd_candidate_kind), learned};
else
    learned = identity; candidate_validated = false;
    validation_identity_mse = NaN; validation_candidate_mse = NaN;
    validation_identity_evm = NaN; validation_identity_sndr = NaN;
    validation_candidate_evm = NaN; validation_candidate_sndr = NaN;
    modes = {"identity_untrained", identity};
end
rows = repmat(local_empty_row(), size(modes,1), 1);
detail = struct();
for k = 1:size(modes,1)
    [rx, reference, rf, rf_pre_bpf, rf_pa_input] = local_endpoint_ofdm(test_x, modes{k,2}, cfg);
    [cal_rx, cal_reference] = local_endpoint_ofdm(val_x, modes{k,2}, cfg);
    channel = local_ofdm_channel(cal_rx, cal_reference, val_meta);
    [evm, sndr, single_evm, single_sndr] = local_ofdm_metrics(rx, reference, test_meta, channel);
    rows(k).Mode = modes{k,1}; rows(k).EVM_percent = evm;
    rows(k).SNDR_dB = sndr;
    rows(k).SingleGainEVM_percent = single_evm;
    rows(k).SingleGainSNDR_dB = single_sndr;
    rows(k).PA_ACLR_dBc = local_aclr(rf_pre_bpf, cfg, test_meta.actual_bw_hz);
    rows(k).Filtered_ACLR_dBc = local_aclr(rf, cfg, test_meta.actual_bw_hz);
    rows(k).Pass256QAM = evm <= 3.5 && sndr >= 29.12;
    rows(k).ValidationIdentityMSE = validation_identity_mse;
    rows(k).ValidationCandidateMSE = validation_candidate_mse;
    rows(k).ValidationIdentityEVM_percent = validation_identity_evm;
    rows(k).ValidationIdentitySNDR_dB = validation_identity_sndr;
    rows(k).ValidationCandidateEVM_percent = validation_candidate_evm;
    rows(k).ValidationCandidateSNDR_dB = validation_candidate_sndr;
    detail.(char(modes{k,1})) = struct('rx',rx,'reference',reference,'rf',rf,'rf_pre_bpf',rf_pre_bpf,'rf_pa_input',rf_pa_input,'channel',channel);
end
Results = struct2table(rows);
deployment = identity; deployment_name = "identity_no_memory_dpd"; heldout_accept = false;
if cfg.enable_dpd_training && candidate_validated
    candidate_row = 2;
    heldout_accept = Results.EVM_percent(candidate_row) <= Results.EVM_percent(1) && ...
        Results.SNDR_dB(candidate_row) >= Results.SNDR_dB(1) && Results.Pass256QAM(candidate_row);
    if heldout_accept
        deployment = learned; deployment_name = "deployed_q214_memory_poly";
    end
end
Results.HeldOutDeploymentAccepted = repmat(heldout_accept,height(Results),1);
Coefficients = local_coeff_table(deployment, deployment_name);
Detail.dpd_validation = struct('identity_mse',validation_identity_mse, ...
    'candidate_mse',validation_candidate_mse,'candidate_validated',candidate_validated, ...
    'identity_evm_percent',validation_identity_evm,'identity_sndr_dB',validation_identity_sndr, ...
    'candidate_evm_percent',validation_candidate_evm,'candidate_sndr_dB',validation_candidate_sndr, ...
    'heldout_deployment_accepted',heldout_accept);
Detail.endpoints = detail;
Detail.pa_profile = local_pa_profile_table(cfg);
Results.RawWordMismatches = repmat(sanity.mismatches,height(Results),1);
disp(Results); disp(Coefficients);
if cfg.write_outputs
    if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
    writetable(Results, fullfile(cfg.out_dir,'tid32_thermo3_frontend_pa_dpd_results.csv'));
    writetable(Coefficients, fullfile(cfg.out_dir,'tid32_thermo3_frontend_pa_dpd_coefficients.csv'));
    writetable(Detail.pa_profile, fullfile(cfg.out_dir,'tid32_thermo3_frontend_pa_profile.csv'));
    if cfg.enable_dpd_training
        writetable(local_coeff_table(learned,"validation_candidate_" + string(cfg.dpd_candidate_kind)), ...
            fullfile(cfg.out_dir,'tid32_thermo3_frontend_pa_dpd_candidate_coefficients.csv'));
    end
end
end

function c = local_default_cfg()
c.fs_in_hz=1.75e9; c.fs_dpd_hz=3.5e9; c.fs_iq_hz=7e9; c.fs_rf_hz=14e9; c.fc_hz=3.5e9;
c.bandwidth_hz=17.09e6; c.nfft=4096; c.ncp=512; c.fit_nsym=12; c.val_nsym=10; c.test_nsym=12;
c.fit_seed=101; c.val_seed=137; c.test_seed=211; c.drive=0.35; c.threshold=8192;
c.thermo_levels=3; c.thermo5_step=7168;
c.input_normalization="peak"; c.rms_drive=0.11;
% Causal fractional-delay interpolation for the even output sample.  The
% four-tap default exactly matches the deployed vector RTL and bit-true
% generator; longer candidates are MATLAB-only exploration until promoted.
c.interp_even_coeff=[5 15 -5 1]/16;
c.interp_mode="legacy_lagrange4"; % legacy_lagrange4 | fir31_exploration
c.dpd_limit=0.78; c.pa_p_gain=1.012; c.pa_m_gain=0.988;
c.dpd_active_taps=4;
c.pa_p_fir=[0.950 0.075 -0.025]; c.pa_m_fir=[0.935 0.090 -0.030];
% Parameterized switching-DPA profile.  These are behavioral nominal values,
% deliberately kept as explicit configuration inputs so that a later PA
% sweep or measured feedback fit can replace them without changing the
% digital/DSM model.  They are not board or transistor calibration data.
c.pa_profile="behavioral_switching_dpa_v1";
c.pa_p_thermal_alpha=0.90; c.pa_m_thermal_alpha=0.88;
c.pa_p_amam=0.12; c.pa_m_amam=0.10;
c.pa_p_switch_asym=0.016; c.pa_m_switch_asym=-0.012;
c.pa_p_ampm_rad=0.080; c.pa_m_ampm_rad=-0.065;
c.bpf_model="analog_2nd_order"; c.bpf_q=100; c.bpf_insertion_loss_db=0.60;
c.bpf_bw_factor=1.50; c.rx_bw_factor=1.50;
% The L=32 state transform has a fixed 1,056-sample latency at the 7-GS/s
% complex interface.  It is 264 samples at the ingress OFDM rate, so the
% behavioural receiver must search beyond a small FIR-delay window.
c.max_delay=640;
c.out_dir=fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','tid32_thermo3_frontend_pa_dpd');
c.write_outputs=true;
c.sanity_only=false;
c.enable_dpd_training=false;
c.dpd_candidate_kind="memory_poly"; % memory_poly | memoryless_poly | lut
c.dpd_fit_ridge=0.25;
c.dpd_c1_main_limit=20480; c.dpd_c1_other_limit=2048; c.dpd_nonlinear_limit=1024;
end

function [x,m] = local_ofdm(c, seed, nsym)
rng(seed,'twister'); df=c.fs_in_hz/c.nfft; nused=2*floor(c.bandwidth_hz/(2*df));
bins=[c.nfft/2-nused/2+1:c.nfft/2, c.nfft/2+2:c.nfft/2+1+nused/2];
idx=randi([0 255],nused,nsym); q=complex(2*mod(idx,16)-15,2*floor(idx/16)-15);
q=q/sqrt(mean(abs(q).^2,'all')); X=zeros(c.nfft,nsym); X(bins,:)=q;
s=ifft(ifftshift(X,1),c.nfft,1); x=[s(end-c.ncp+1:end,:);s]; x=x(:);
if string(c.input_normalization) == "fair_rms"
    x=c.rms_drive*x/(sqrt(mean(abs(x).^2))+eps);
    assert(max(abs(x)) <= c.drive+eps, ...
        'fair_rms waveform exceeds configured peak drive; lower rms_drive or raise drive.');
else
    x=c.drive*x/max(abs(x));
end
% integer number of 8-sample fabric words is a hard interface condition.
assert(mod(numel(x),8)==0,'OFDM frame must be an integer number of ingress words.');
m=struct('bins',bins,'qam',q,'actual_bw_hz',nused*df,'frame',c.nfft+c.ncp,'nsym',nsym,'nfft',c.nfft,'ncp',c.ncp);
end

function [rx, reference, rf, rf_pre_bpf, rf_pa_input] = local_endpoint_ofdm(x, coeff, c)
guard=8*64; source=[zeros(guard,1);x;zeros(guard,1)];
[rf, ~, ~, ~, ~, rf_pre_bpf, ~, rf_pa_input] = local_transmit(source, coeff, c);
[bb, ref_all] = local_receive(rf, source, c, 8);
% The receiver alignment establishes a common sequence origin.  Crop the
% inner frame only after that alignment, so FFT symbols retain their CP edge.
start=guard+1; stop=guard+numel(x);
rx=bb(start:stop); reference=ref_all(start:stop);
end

function [feedback, dpd_in] = local_endpoint_rate(x, coeff, c, decim)
guard=8*64; source=[zeros(guard,1);x;zeros(guard,1)];
[rf, dpd_in_all] = local_transmit(source, coeff, c);
[feedback, dpd_in] = local_receive(rf, dpd_in_all, c, decim);
end

function score = local_rate_mse(x, coeff, c)
[fb, ref] = local_endpoint_rate(x, coeff, c, 2);
[a,b]=local_align(fb,ref,c.max_delay); score=mean(abs(a-b).^2)/(mean(abs(b).^2)+eps);
end

function [evm,sndr] = local_validation_ofdm(fit_x, fit_meta, val_x, val_meta, coeff, c)
[cal_rx, cal_reference] = local_endpoint_ofdm(fit_x, coeff, c);
channel = local_ofdm_channel(cal_rx, cal_reference, fit_meta);
[val_rx, val_reference] = local_endpoint_ofdm(val_x, coeff, c);
[evm,sndr] = local_ofdm_metrics(val_rx, val_reference, val_meta, channel);
end

function [rf, dpd_input, pp, mm, x2, rf_pre_bpf, dpd_output, rf_pa_input, pa_words] = local_transmit(x, coeff, c)
x1=local_x2(x,c); dpd_input=x1;
d=local_apply_dpd(x1,coeff,c); dpd_output=d; x2=local_x2(d,c);
assert(mod(numel(x2),32)==0);
state=[]; branches=2+(c.thermo_levels==5)*2;
pa_words=false(2*numel(x2),branches);
for first=1:32:numel(x2)
  xi=int64(round(real(x2(first:first+31))*32767));
  xq=int64(round(imag(x2(first:first+31))*32767));
  if c.thermo_levels == 5
    [raw,state]=tid_thermo5_pipelined_step(xi,xq,state,16,c.thermo5_step);
  else
    [p,m,state]=tid_thermo3_pipelined_step(xi,xq,state,16,c.threshold);
    raw=[p,m];
  end
  pa_words(2*first-1:2*(first+31),:)=raw;
end
pp=pa_words(:,1); mm=pa_words(:,2);
if c.thermo_levels == 3
  vp=2*double(pp)-1; vm=2*double(mm)-1;
  rf_pa_input=0.5*(vp+vm);
% Each thermometric PA branch is a parameterized switching-DPA model.  It
% combines pulse-density thermal AM-AM, polarity asymmetry, finite output
% memory, and an envelope-dependent AM-PM phase.  This is deliberately a
% model boundary: its parameters must be fitted to feedback data before it
% can represent a particular hardware PA.
yp=local_switching_dpa(vp,c.pa_p_gain,c.pa_p_fir,c.pa_p_thermal_alpha, ...
    c.pa_p_amam,c.pa_p_switch_asym,c.pa_p_ampm_rad);
ym=local_switching_dpa(vm,c.pa_m_gain,c.pa_m_fir,c.pa_m_thermal_alpha, ...
    c.pa_m_amam,c.pa_m_switch_asym,c.pa_m_ampm_rad);
rf_pre_bpf=0.5*(yp+ym);
else
  v=2*double(pa_words)-1; rf_pa_input=mean(v,2); y=zeros(size(v));
  gains=[c.pa_p_gain*[1.003 0.997], c.pa_m_gain*[1.003 0.997]];
  for branch=1:4
    if branch <= 2
      y(:,branch)=local_switching_dpa(v(:,branch),gains(branch),c.pa_p_fir, ...
        c.pa_p_thermal_alpha,c.pa_p_amam,c.pa_p_switch_asym,c.pa_p_ampm_rad);
    else
      y(:,branch)=local_switching_dpa(v(:,branch),gains(branch),c.pa_m_fir, ...
        c.pa_m_thermal_alpha,c.pa_m_amam,c.pa_m_switch_asym,c.pa_m_ampm_rad);
    end
  end
  rf_pre_bpf=mean(y,2);
end
if c.bpf_model == "ideal_fft"
  rf=local_fft_bandpass(rf_pre_bpf,c.fs_rf_hz,c.fc_hz,c.bpf_bw_factor*c.bandwidth_hz);
else
  rf=local_analog_bpf(rf_pre_bpf,c);
end
end

function [out, refout] = local_receive(rf, reference, c, decim)
n=(0:numel(rf)-1).';
ddc=2*rf(:).*exp(-1j*2*pi*c.fc_hz/c.fs_rf_hz*n);
bb=local_fft_lowpass(ddc,c.fs_rf_hz,c.rx_bw_factor*c.bandwidth_hz);
% The Fs/4 DDC image is cancelled after one of the two possible raw-time
% phases is selected and the rate is first reduced 14 -> 7 GS/s.  The phase
% is a deterministic receiver timing calibration; do not hard-code it, since
% a causal BPF can move the optimum by one 14-GS/s sample.  Subsequent
% decimation is a normal complex-baseband operation.
assert(mod(decim,2)==0,'DDC decimation must include the 14-to-7 GS/s step.');
remaining=decim/2;
best=inf; out=[]; refout=reference(:);
for fs4_phase=0:1
 for phase=0:remaining-1
  candidate=bb(fs4_phase+1:2:end);
  candidate=candidate(phase+1:remaining:end);
  target=reference(:);
  [e,g,d]=local_best_map(candidate,target,c.max_delay);
  if e<best
    best=e; out=zeros(size(target));
    ti=max(1,1-d):min(numel(target),numel(candidate)-d); ci=ti+d;
    out(ti)=candidate(ci)*g;
  end
 end
end
end

function result = local_raw_word_sanity(pa_words, x2, c)
% Decode the exact stored raw-word bit order, then compare it against an
% independently stepped scalar thermo3 machine.  The known L=32 transform
% latency is 1,056 samples at this 7-GS/s complex interface.
n=numel(x2); got_i=zeros(n,1); got_q=zeros(n,1); branches=size(pa_words,2);
for k=1:n
  a=mean(2*double(pa_words(2*k-1,:))-1);
  b=mean(2*double(pa_words(2*k,:))-1);
  if mod(k-1,2)==0, got_i(k)=a; got_q(k)=-b; else, got_i(k)=-a; got_q(k)=b; end
end
xi=int64(round(real(x2)*32767)); xq=int64(round(imag(x2)*32767));
ref_i=zeros(n,1); ref_q=zeros(n,1);
if c.thermo_levels == 5, offsets=int64([3 1 -1 -3])*int64(c.thermo5_step); else, offsets=int64([1 -1])*int64(c.threshold); end
vi=zeros(branches,1,'int64'); vq=zeros(branches,1,'int64');
for k=1:n
  si=0; sq=0;
  for branch=1:branches
    [bi,vi(branch)]=local_efm_bit(local_sat16(xi(k)+offsets(branch)),vi(branch));
    [bq,vq(branch)]=local_efm_bit(local_sat16(xq(k)+offsets(branch)),vq(branch));
    si=si+(2*double(bi)-1); sq=sq+(2*double(bq)-1);
  end
  ref_i(k)=si/branches; ref_q(k)=sq/branches;
end
latency=1056; assert(n>latency);
result=struct('latency',latency,'mismatches',nnz(got_i(latency+1:end)~=ref_i(1:end-latency))+nnz(got_q(latency+1:end)~=ref_q(1:end-latency)));
end

function result = local_rf_ddc_sanity(pa_words, c)
% A real Fs/4 stream has alternating I and Q components.  DDC at Fs/4 makes
% the desired component baseband and the image alternate at Fs/2; low-pass
% then decimate-by-two must reproduce the digital de-interleave reference.
n=size(pa_words,1)/2; raw=mean(2*double(pa_words)-1,2);
ref_i=zeros(n,1); ref_q=zeros(n,1);
for k=1:n
  a=raw(2*k-1); b=raw(2*k);
  if mod(k-1,2)==0, ref_i(k)=a; ref_q(k)=-b; else, ref_i(k)=-a; ref_q(k)=b; end
end
ref=local_fft_lowpass(ref_i+1j*ref_q,c.fs_iq_hz,c.rx_bw_factor*c.bandwidth_hz);
rf=local_fft_bandpass(raw,c.fs_rf_hz,c.fc_hz,c.bpf_bw_factor*c.bandwidth_hz);
t=(0:numel(rf)-1).'; ddc=2*rf.*exp(-1j*2*pi*c.fc_hz/c.fs_rf_hz*t);
bb=local_fft_lowpass(ddc,c.fs_rf_hz,c.rx_bw_factor*c.bandwidth_hz);
best=inf; result=struct('nmse',inf,'phase',NaN,'delay',NaN);
for phase=0:1
  [score,~,delay]=local_best_map(bb(phase+1:2:end),ref,c.max_delay);
  if score<best, best=score; result=struct('nmse',score,'phase',phase,'delay',delay); end
end
end

function [score,gain,delay] = local_best_map(y,x,maxdelay)
score=inf; gain=1; delay=0;
for d=-maxdelay:maxdelay
  ti=max(1,1-d):min(numel(x),numel(y)-d); ci=ti+d;
  if numel(ti)<32, continue; end
  yy=y(ci); xx=x(ti); g=(yy'*xx)/(yy'*yy+eps); e=mean(abs(yy*g-xx).^2)/(mean(abs(xx).^2)+eps);
  if e<score, score=e; gain=g; delay=d; end
end
end

function [a,b] = local_align(y,x,maxdelay)
best=inf; a=[]; b=[];
for d=-maxdelay:maxdelay
  if d>=0, yy=y(1+d:end); xx=x(1:min(numel(x),numel(yy))); yy=yy(1:numel(xx));
  else, xx=x(1-d:end); yy=y(1:min(numel(y),numel(xx))); xx=xx(1:numel(yy)); end
  g=(yy'*xx)/(yy'*yy+eps); yy=yy*g; e=mean(abs(yy-xx).^2);
  if e<best, best=e; a=yy; b=xx; end
end
end

function h = local_ofdm_channel(rx, reference, m)
frame=m.frame; count=floor(min(numel(rx),numel(reference))/frame);
rx=reshape(rx(1:count*frame),frame,count); reference=reshape(reference(1:count*frame),frame,count);
R=fftshift(fft(rx(m.ncp+1:end,:),m.nfft,1),1); X=fftshift(fft(reference(m.ncp+1:end,:),m.nfft,1),1);
r=R(m.bins,:); q=X(m.bins,:);
% Least-squares pilot channel estimate, one complex coefficient per active
% OFDM carrier.  It models the deterministic interpolation/BPF transfer,
% not stochastic PA or DSM errors.
h=sum(r.*conj(q),2)./(sum(abs(q).^2,2)+eps);
end

function [evm,sndr,single_evm,single_sndr] = local_ofdm_metrics(rx, reference, m, h)
frame=m.frame; count=floor(min(numel(rx),numel(reference))/frame);
rx=reshape(rx(1:count*frame),frame,count); reference=reshape(reference(1:count*frame),frame,count);
R=fftshift(fft(rx(m.ncp+1:end,:),m.nfft,1),1); X=fftshift(fft(reference(m.ncp+1:end,:),m.nfft,1),1);
r=R(m.bins,:); q=X(m.bins,:);
g=sum(conj(r(:)).*q(:))/(sum(abs(r(:)).^2)+eps); e_single=r*g-q;
single_evm=100*sqrt(mean(abs(e_single).^2,'all')/(mean(abs(q).^2,'all')+eps));
single_sndr=10*log10(mean(abs(q).^2,'all')/(mean(abs(e_single).^2,'all')+eps));
e=r./h-q;
evm=100*sqrt(mean(abs(e).^2,'all')/(mean(abs(q).^2,'all')+eps));
sndr=10*log10(mean(abs(q).^2,'all')/(mean(abs(e).^2,'all')+eps));
end

function a=local_aclr(rf,c,bw)
f=local_freq(numel(rf),c.fs_rf_hz); p=abs(fft(rf)).^2;
main=abs(abs(f)-c.fc_hz)<=bw/2; lo=abs(abs(f)-(c.fc_hz-1.5*bw))<=bw/2; hi=abs(abs(f)-(c.fc_hz+1.5*bw))<=bw/2;
a=10*log10((max(sum(p(lo)),sum(p(hi)))+eps)/(sum(p(main))+eps));
end

function y=local_x2(x,c)
if string(c.interp_mode) == "fir31_exploration"
  % MATLAB-only diagnostic: a 31-tap, gain-two, windowed-sinc interpolation
  % FIR.  Its group delay and coefficients are not in the deployed vector
  % RTL, so this mode may identify the needed response but is never bit-true
  % or FPGA evidence until a pipelined vector implementation is added.
  n=(0:30).'; mid=15; win=0.54-0.46*cos(2*pi*n/30);
  h=sinc((n-mid)/2).*win; h=h/h(mid+1);
  up=zeros(2*numel(x),1); up(1:2:end)=x;
  y=filter(h,1,up);
  return;
end
coef=c.interp_even_coeff(:); h=zeros(numel(coef)-1,1); y=zeros(2*numel(x),1);
for k=1:numel(x)
  y(2*k-1)=x(k); v=[x(k);h]; y(2*k)=sum(coef.*v);
  h=[x(k);h(1:end-1)];
end
end

function y=local_apply_dpd(x,model,c)
% The four-way behavioural comparison deliberately shares the exact same
% interpolation, TID, two-PA, BPF and receiver path.  Only this DPD block
% changes.  `lut` follows dpd_lut.v's 16-bin max(I,Q) addressing and Q2.14
% complex gain convention; it is a model-level candidate until vector RTL
% integration receives its own bit-true regression.
if ~isfield(model,'kind'), model.kind="memory_poly"; end
switch string(model.kind)
  case "memoryless_poly"
    y=local_q214_dpd_taps(x,model,c,1);
  case "lut"
    y=local_q214_lut_dpd(x,model,c);
  otherwise % identity and memory_poly retain the established Q2.14 path
    taps=c.dpd_active_taps;
    if isfield(model,'taps'), taps=model.taps; end
    y=local_q214_dpd_taps(x,model,c,taps);
end
end

function y=local_q214_dpd(x,cq,c)
% Backward-compatible helper used by archived callers.
y=local_q214_dpd_taps(x,cq,c,c.dpd_active_taps);
end

function y=local_q214_dpd_taps(x,cq,c,taps)
h=zeros(3,1); y=zeros(size(x));
for n=1:numel(x)
  v=[x(n);h]; acc=0;
  for t=1:taps
    mag2=abs(v(t))^2; gain=(double(cq.c1(t))+double(cq.c3(t))*mag2+double(cq.c5(t))*mag2^2)/2^14;
    acc=acc+v(t)*gain;
  end
  if abs(acc)>c.dpd_limit, acc=acc*c.dpd_limit/abs(acc); end
  y(n)=round(real(acc)*32767)/32767 + 1j*round(imag(acc)*32767)/32767;
  h=[x(n);h(1:2)];
end
end

function y=local_q214_lut_dpd(x,lut,c)
% Match dpd_lut.v's magnitude address: mag[14:11] for signed Q1.15 data.
% The final round-to-Q1.15 is intentionally stated as behavioral; RTL uses
% an arithmetic right shift followed by saturation and has not yet been
% connected to the vector16 thermo3 frontend.
y=zeros(size(x));
for n=1:numel(x)
  ii=max(min(round(real(x(n))*32767),32767),-32768);
  qq=max(min(round(imag(x(n))*32767),32767),-32768);
  idx=min(16,max(1,floor(max(abs(ii),abs(qq))/2^11)+1));
  g=(double(lut.gain_re(idx))+1j*double(lut.gain_im(idx)))/2^14;
  acc=x(n)*g;
  if abs(acc)>c.dpd_limit, acc=acc*c.dpd_limit/abs(acc); end
  y(n)=round(real(acc)*32767)/32767 + 1j*round(imag(acc)*32767)/32767;
end
end

function model=local_fit_dpd_candidate(y,x,c)
switch string(c.dpd_candidate_kind)
  case "memoryless_poly"
    c1=c; c1.dpd_active_taps=1;
    model=local_fit_q214_postdistorter(y,x,c1); model.kind="memoryless_poly"; model.taps=1;
  case "lut"
    model=local_fit_q214_lut_postdistorter(y,x,c);
  otherwise
    model=local_fit_q214_postdistorter(y,x,c); model.kind="memory_poly"; model.taps=c.dpd_active_taps;
end
end

function cq=local_fit_q214_postdistorter(y,x,c)
% Ridge-regularized ILA around the identity DPD.  The prior and per-term
% Q2.14 limits prevent DSM quantization noise from producing a clipped
% high-order inverse that looks better only on the fit window.
n=min(numel(y),numel(x)); y=y(1:n); x=x(1:n); rows=(4:n).'; A=[];
for t=0:c.dpd_active_taps-1
  z=y(rows-t); A=[A z z.*abs(z).^2 z.*abs(z).^4]; %#ok<AGROW>
end

prior=zeros(3*c.dpd_active_taps,1); prior(1)=1;
gram=A'*A; ridge=c.dpd_fit_ridge*trace(gram)/size(gram,1);
coef=(gram+ridge*eye(size(gram)))\(A'*x(rows)+ridge*prior);
cq.c1=zeros(4,1); cq.c3=zeros(4,1); cq.c5=zeros(4,1);
for t=1:c.dpd_active_taps
  if t==1, c1_limit=c.dpd_c1_main_limit; else, c1_limit=c.dpd_c1_other_limit; end
  cq.c1(t)=local_qcoef(coef(3*(t-1)+1),c1_limit);
  cq.c3(t)=local_qcoef(coef(3*(t-1)+2),c.dpd_nonlinear_limit);
  cq.c5(t)=local_qcoef(coef(3*(t-1)+3),c.dpd_nonlinear_limit);
end
end

function lut=local_fit_q214_lut_postdistorter(y,x,c)
% Least-squares complex gain per dpd_lut.v magnitude bin.  Use the same
% feedback endpoint as the polynomial candidates; train/test sets remain
% isolated in the caller.
[yy,xx]=local_align_unscaled(y,x,c.max_delay);
lut.kind="lut"; lut.gain_re=16384*ones(16,1); lut.gain_im=zeros(16,1);
ii=max(min(round(real(yy)*32767),32767),-32768);
qq=max(min(round(imag(yy)*32767),32767),-32768);
bin=min(16,max(1,floor(max(abs(ii),abs(qq))/2^11)+1));
for k=1:16
  use=(bin==k);
  if nnz(use)<8, continue; end
  g=sum(conj(yy(use)).*xx(use))/(sum(abs(yy(use)).^2)+eps);
  lut.gain_re(k)=max(min(round(real(g)*2^14),c.dpd_c1_main_limit),-c.dpd_c1_main_limit);
  lut.gain_im(k)=max(min(round(imag(g)*2^14),c.dpd_c1_main_limit),-c.dpd_c1_main_limit);
end
end

function [yy,xx]=local_align_unscaled(y,x,maxdelay)
[~,~,d]=local_best_map(y,x,maxdelay);
ti=max(1,1-d):min(numel(x),numel(y)-d); ci=ti+d;
yy=y(ci); xx=x(ti);
end

function q=local_qcoef(x,limit)
q=complex(max(min(round(real(x)*2^14),limit),-limit),max(min(round(imag(x)*2^14),limit),-limit));
end
function [bit,v]=local_efm_bit(x,v), u=mod(int64(x)+int64(32768),int64(65536)); v=mod(u+mod(v,int64(65536)),int64(131072)); bit=v>=65536; end
function y=local_sat16(x), y=min(max(int64(x),int64(-32768)),int64(32767)); end
function c=local_identity_coeff(), c.kind="identity"; c.taps=1; c.c1=complex([16384;0;0;0]); c.c3=zeros(4,1); c.c5=zeros(4,1); end
function f=local_freq(n,fs), k=(0:n-1).'; k(k>=ceil(n/2))=k(k>=ceil(n/2))-n; f=k*fs/n; end
function y=local_fft_lowpass(x,fs,bw), f=local_freq(numel(x),fs); y=ifft(fft(x).*(abs(f)<=bw/2)); end
function y=local_fft_bandpass(x,fs,fc,bw), f=local_freq(numel(x),fs); y=real(ifft(fft(x).*((abs(f-fc)<=bw/2)|(abs(f+fc)<=bw/2)))); end
function y=local_switching_dpa(v,gain,fir,alpha,amam,switch_asym,ampm_rad)
% Duty-cycle state gives AM-AM memory.  The analytic representation applies
% AM-PM without violating the real passband branch output at the combiner.
on=0.5*(v(:)+1); duty=filter(1-alpha,[1 -alpha],on);
thermal_gain=1-amam*(duty-0.5);
levels=gain*v(:).*(1+switch_asym*v(:)).*thermal_gain;
y=filter(fir(:),1,levels);
if ampm_rad~=0
  z=local_analytic_signal(y);
  y=real(z.*exp(1j*ampm_rad*(duty-0.5)));
end
end
function z=local_analytic_signal(x)
n=numel(x); h=zeros(n,1);
if mod(n,2)==0, h(1)=1; h(n/2+1)=1; h(2:n/2)=2;
else, h(1)=1; h(2:(n+1)/2)=2; end
z=ifft(fft(x(:)).*h);
end
function y=local_analog_bpf(x,c)
% Causal second-order RLC-equivalent BPF, bilinear transformed at 14 GS/s.
fs=c.fs_rf_hz; fc=c.fc_hz; k=2*fs; w0=2*fs*tan(pi*fc/fs); b=w0/c.bpf_q;
a0=k^2+b*k+w0^2; a1=2*(w0^2-k^2); a2=k^2-b*k+w0^2;
b0=b*k; b2=-b*k; gain=10^(-c.bpf_insertion_loss_db/20);
x=x(:); y=zeros(size(x)); x1=0; x2=0; y1=0; y2=0;
for n=1:numel(x)
  yn=(b0*x(n)+b2*x2-a1*y1-a2*y2)/a0;
  y(n)=gain*yn; x2=x1; x1=x(n); y2=y1; y1=yn;
end
end
function r=local_empty_row(), r=struct('Mode',"",'EVM_percent',NaN,'SNDR_dB',NaN,'SingleGainEVM_percent',NaN,'SingleGainSNDR_dB',NaN,'PA_ACLR_dBc',NaN,'Filtered_ACLR_dBc',NaN,'Pass256QAM',false,'ValidationIdentityMSE',NaN,'ValidationCandidateMSE',NaN,'ValidationIdentityEVM_percent',NaN,'ValidationIdentitySNDR_dB',NaN,'ValidationCandidateEVM_percent',NaN,'ValidationCandidateSNDR_dB',NaN); end
function T=local_pa_profile_table(c)
name=["profile";"pa_p_gain";"pa_m_gain";"pa_p_fir";"pa_m_fir"; ...
  "pa_p_thermal_alpha";"pa_m_thermal_alpha";"pa_p_amam";"pa_m_amam"; ...
  "pa_p_switch_asym";"pa_m_switch_asym";"pa_p_ampm_rad";"pa_m_ampm_rad"; ...
  "bpf_model";"bpf_q";"bpf_insertion_loss_db"];
value=[string(c.pa_profile);string(c.pa_p_gain);string(c.pa_m_gain); ...
  string(mat2str(c.pa_p_fir));string(mat2str(c.pa_m_fir)); ...
  string(c.pa_p_thermal_alpha);string(c.pa_m_thermal_alpha);string(c.pa_p_amam);string(c.pa_m_amam); ...
  string(c.pa_p_switch_asym);string(c.pa_m_switch_asym);string(c.pa_p_ampm_rad);string(c.pa_m_ampm_rad); ...
  string(c.bpf_model);string(c.bpf_q);string(c.bpf_insertion_loss_db)];
T=table(name,value,'VariableNames',{'Parameter','Value'});
end
function T=local_coeff_table(c,name)
if isfield(c,'kind') && string(c.kind)=="lut"
  T=table(repmat(string(name),16,1),(0:15).',double(c.gain_re(:)),double(c.gain_im(:)), ...
      'VariableNames',{'Mode','LUTBin','Q2_14_Real','Q2_14_Imag'});
  return;
end
r=repmat(struct('Mode',string(name),'Tap',0,'Order',0,'Q2_14_Real',0,'Q2_14_Imag',0),12,1); k=0;
orders=[1 3 5];
for t=1:4, for o=1:3, k=k+1; a={c.c1,c.c3,c.c5}; r(k).Tap=t-1; r(k).Order=orders(o); r(k).Q2_14_Real=real(a{o}(t)); r(k).Q2_14_Imag=imag(a{o}(t)); end, end
T=struct2table(r);
end
