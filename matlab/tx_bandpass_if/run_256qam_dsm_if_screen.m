function results = run_256qam_dsm_if_screen(varargin)
% RUN_256QAM_DSM_IF_SCREEN Comparable 256-QAM real-IF DSM screening gate.
% All supported candidates use Fs=14 GS/s, Fc=Fs/4, ideal IF BPF/DDC and
% identical OFDM vectors.  This is a behavioral feasibility screen only.

  cfg.fs_hz = 14e9; cfg.fc_hz = 3.5e9; cfg.bandwidth_hz = [5 10 20 40]*1e6;
  cfg.nfft = 8192; cfg.ncp = 1024; cfg.nsym = 8; cfg.seed = 20260915;
  cfg.drive = 0.35; cfg.out_dir = fullfile(fileparts(fileparts(mfilename('fullpath'))),'out','dsm_256qam_if_screen');
  cfg.bp_ef4_c2_num = -2; cfg.bp_ef4_c4_num = -1;
  cfg.bp3l_threshold_num = 1; cfg.bp3l_threshold_den = 2;
  for k = 1:2:numel(varargin), cfg.(varargin{k}) = varargin{k+1}; end
  if ~exist(cfg.out_dir,'dir'), mkdir(cfg.out_dir); end
  names = ["cartesian_ef1" "ti64_lp1" "bpdsm2_single" "bp_efdsm2" "bp_efdsm4" "bp3l_efdsm2" "bp3l_efdsm4" "ti64_bp2" "smash_bp2"];
  rows = repmat(empty_row(),numel(cfg.bandwidth_hz)*numel(names),1); r = 0;
  for bw = cfg.bandwidth_hz
    [x, actual_bw] = make_ofdm(cfg,bw);
    for name = names
      r = r + 1; rows(r).Candidate = name; rows(r).RequestedBW_Hz = bw; rows(r).ActualBW_Hz = actual_bw;
      y = modulate(x,name,cfg);
      [evm,sndr,aclr] = score_if(y,x,actual_bw,cfg);
      rows(r).EVM_percent = evm; rows(r).SNDR_dB = sndr; rows(r).ACLR_dBc = aclr;
      rows(r).Status = tern(evm <= 3.5 && sndr >= 29.12,"PASS","FAIL");
    end
  end
  results = struct2table(rows); writetable(results,fullfile(cfg.out_dir,'screen.csv')); disp(results);
end

function [x,bw] = make_ofdm(c,bw_req)
  rng(c.seed + round(bw_req)); df = c.fs_hz/c.nfft;
  nused = max(2,2*floor(bw_req/(2*df))); nused = min(nused, c.nfft/4); bw = nused*df;
  X = zeros(c.nfft,c.nsym); side=16; idx=randi([0 255],nused,c.nsym);
  q = complex(2*mod(idx,side)-(side-1),2*floor(idx/side)-(side-1)); q=q/sqrt(mean(abs(q).^2,'all'));
  bins=[c.nfft/2-nused/2+1:c.nfft/2, c.nfft/2+2:c.nfft/2+1+nused/2]; X(bins,:)=q;
  s=ifft(ifftshift(X,1),c.nfft,1); x=[s(end-c.ncp+1:end,:);s]; x=x(:); x=c.drive*x/max(abs(x));
end

function y = modulate(x,name,c)
  xi=int64(round(real(x)*32767)); xq=int64(round(imag(x)*32767)); n=(0:numel(x)-1).'; ph=mod(n,4); signif=ones(size(n)); signif(ph>=2)=-1;
  switch name
    case "cartesian_ef1"
      bi=2*double(p0_dsm_bittrue(xi,'ef1'))-1; bq=2*double(p0_dsm_bittrue(xq,'ef1'))-1;
      y=bi; y(ph==1)=bq(ph==1); y(ph==2)=-bi(ph==2); y(ph==3)=-bq(ph==3);
    case "ti64_lp1"
      st=zeros(64,1,'int64'); y=zeros(numel(x),1); fs=int64(32767);
      for k=1:numel(x)
        lane=mod(k-1,64)+1; in=xi(k); if mod(k-1,4)==1 || mod(k-1,4)==3, in=xq(k); end
        v=st(lane)+in; bit=(v>=0); st(lane)=v-(2*int64(bit)-1)*fs; y(k)=(2*double(bit)-1)*signif(k);
      end
    case "bpdsm2_single"
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3); y=2*double(bp_single_fs4_model(in))-1;
    case "bp_efdsm2"
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3); y=2*double(bp_ef2_fs4_model(in))-1;
    case "bp_efdsm4"
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3); y=2*double(bp_ef4_fs4_model(in,'c2_num',c.bp_ef4_c2_num,'c4_num',c.bp_ef4_c4_num))-1;
    case "bp3l_efdsm2"
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3);
      y=double(bp_ef2_3level_fs4_model(in,'threshold_num',c.bp3l_threshold_num,'threshold_den',c.bp3l_threshold_den));
    case "bp3l_efdsm4"
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3);
      y=double(bp_ef4_3level_fs4_model(in,'threshold_num',c.bp3l_threshold_num,'threshold_den',c.bp3l_threshold_den));
    case "ti64_bp2"
      % Exact temporal 64-word packing does not change the serial BP-EFDSM2
      % recurrence. This is the packed-oracle result, not 64 independent lanes.
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3); y=2*double(bp_ef2_fs4_model(in))-1;
    case "smash_bp2"
      % Existing BP MASH1-1 is multilevel; retain its combiner amplitude.
      in=xi; in(ph==1)=xq(ph==1); in(ph==2)=-xi(ph==2); in(ph==3)=-xq(ph==3); y=double(bp_mash11_exploratory_model(in));
  end
end

function [evm,sndr,aclr] = score_if(y,x,bw,c)
  % The Fs/4 transmitter is a four-phase commutator, not a conventional
  % pointwise complex mixer. Recover I/Q on their own phase slots first.
  n=numel(y); k=(0:n-1).'; ph=mod(k,4); i=zeros(n,1); q=zeros(n,1);
  i(ph==0)=y(ph==0); i(ph==2)=-y(ph==2);
  q(ph==1)=y(ph==1); q(ph==3)=-y(ph==3);
  f=((0:n-1).'-floor(n/2))*c.fs_hz/n; lp=abs(f)<=0.75*bw;
  z=2*(ifft(ifftshift(fftshift(fft(i)).*lp)) + 1j*ifft(ifftshift(fftshift(fft(q)).*lp)));
  trim=min(round(c.nfft),floor(n/8)); z=z(trim+1:end-trim); ref=x(trim+1:end-trim);
  best=inf; bestz=[]; bestr=[];
  for lag=-16:16
    if lag>=0, zz=z(1+lag:end); rr=ref(1:numel(zz));
    else, rr=ref(1-lag:end); zz=z(1:numel(rr)); end
    g=(zz'*rr)/(zz'*zz+eps); zz=zz*g; e=mean(abs(zz-rr).^2);
    if e<best, best=e; bestz=zz; bestr=rr; end
  end
  pe=mean(abs(bestz-bestr).^2); ps=mean(abs(bestr).^2); evm=100*sqrt(pe/(ps+eps)); sndr=10*log10(ps/(pe+eps));
  Y=fftshift(fft(y)); main=abs(f-c.fc_hz)<=bw/2;
  p=abs(Y).^2; adj1=abs(f-(c.fc_hz-1.5*bw))<=bw/2; adj2=abs(f-(c.fc_hz+1.5*bw))<=bw/2;
  aclr=10*log10((mean([sum(p(adj1)) sum(p(adj2))])+eps)/(sum(p(main))+eps));
end

function s=tern(c,a,b), if c,s=a;else,s=b;end,end
function r=empty_row(), r=struct('Candidate',"",'RequestedBW_Hz',NaN,'ActualBW_Hz',NaN,'EVM_percent',NaN,'SNDR_dB',NaN,'ACLR_dBc',NaN,'Status',""); end
