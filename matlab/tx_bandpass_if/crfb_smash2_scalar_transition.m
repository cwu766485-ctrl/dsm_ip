function [out, st] = crfb_smash2_scalar_transition(x, st, varargin)
% CRFB_SMASH2_SCALAR_TRANSITION Causal two-stage CRFB-SMASH state update.
%
% This is the discrete realization of Xu et al. Eq. (8)--(10).  Let
% F_i=NTF_i and H_i=1-F_i.  The i-th stage uses
%   y_i = e_(i-1) + H_i*v_(i+1) + F_i*e_i,  v_i = y_i-v_(i+1).
% H_i is strictly delayed and is realized as
%   H_i[n]=-d_i H_i[n-1]+(a_i+1)u[n-1]-u[n-2], d_i=a_i+g_i-1.
% The two stages are evaluated in causal order: stage 1 quantizes first,
% its present error drives stage 2, and stage 1's feedback uses registered
% prior v2.  At g=2,a=-1 this is an integer, Fs/4 double-zero realization.

  p=inputParser; addParameter(p,'g',[2 2]); addParameter(p,'a',[-1 -1]);
  addParameter(p,'fs_code',32767); addParameter(p,'acc_w',28); addParameter(p,'saturate',true);
  parse(p,varargin{:}); c=p.Results;
  if any(abs(c.g-round(c.g))>0) || any(abs(c.a-round(c.a))>0)
    error('This fixed-point transition currently accepts integer g/a only.');
  end
  g=int64(c.g(:).'); a=int64(c.a(:).'); d=a+g-int64(1);
  fs=int64(c.fs_code); x=int64(x);
  if nargin < 2 || isempty(st), st=reset_state(); end

  % Stage 1: H1*e1 cancellation state and H1*v2 cross-stage feedback.
  re1 = sat_or_wrap(-d(1)*st.re1 + (a(1)+1)*st.e1_d1 - st.e1_d2,c);
  kv1 = sat_or_wrap(-d(1)*st.kv1 + (a(1)+1)*st.v2_d1 - st.v2_d2,c);
  u1 = sat_or_wrap(x - re1 + kv1,c);
  y1 = tern(u1>=0,fs,-fs); e1=sat_or_wrap(y1-u1,c);

  % Stage 2 has v3=0, so only its own H2*e2 state is required.
  re2 = sat_or_wrap(-d(2)*st.re2 + (a(2)+1)*st.e2_d1 - st.e2_d2,c);
  u2 = sat_or_wrap(e1-re2,c);
  y2 = tern(u2>=0,fs,-fs); e2=sat_or_wrap(y2-u2,c);
  v2=y2; v1=sat_or_wrap(y1-y2,c);

  st.re1=re1; st.kv1=kv1; st.re2=re2;
  st.e1_d2=st.e1_d1; st.e1_d1=e1;
  st.e2_d2=st.e2_d1; st.e2_d1=e2;
  st.v2_d2=st.v2_d1; st.v2_d1=v2;
  out=struct('y1',y1>0,'y2',y2>0,'e1',e1,'e2',e2,'v1',v1,'v2',v2,'u1',u1,'u2',u2);
end

function st=reset_state()
  st=struct('re1',int64(0),'kv1',int64(0),'re2',int64(0), ...
    'e1_d1',int64(0),'e1_d2',int64(0),'e2_d1',int64(0),'e2_d2',int64(0), ...
    'v2_d1',int64(0),'v2_d2',int64(0));
end
function y=sat_or_wrap(v,c)
  hi=int64(2)^(c.acc_w-1)-1; lo=-int64(2)^(c.acc_w-1);
  if c.saturate,y=min(max(v,lo),hi);else,y=mod(v+int64(2)^(c.acc_w-1),int64(2)^c.acc_w)-int64(2)^(c.acc_w-1);end
end
function y=tern(c,a,b),if c,y=a;else,y=b;end,end
