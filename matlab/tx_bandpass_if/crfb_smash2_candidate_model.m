function out = crfb_smash2_candidate_model(x, varargin)
% CRFB_SMASH2_CANDIDATE_MODEL Fixed-point research oracle for two CRFB stages.
% Stage i uses NTF_i=(1+(g_i-2)z^-1+z^-2)/(1+(a_i+g_i-1)z^-1).
% Update order is explicit: stage 1 uses the registered previous v2; stage 2
% consumes the new stage-1 quantization error. v1 is the three-level PA code.

  p=inputParser; addParameter(p,'g',[2 2]); addParameter(p,'a',[0 0]);
  addParameter(p,'acc_w',28); parse(p,varargin{:});
  g=int64(p.Results.g); a=int64(p.Results.a); w=p.Results.acc_w;
  x=int64(x(:)); n=numel(x); fs=int64(32767);
  h1=int64(0); h2=int64(0); e11=int64(0); e12=int64(0); e21=int64(0); e22=int64(0); v2=int64(0);
  out.y1=zeros(n,1,'int64'); out.y2=out.y1; out.v1=out.y1;
  for k=1:n
    u1=wrap(x(k)+h1-v2,w); y1=tern(u1>=0,fs,-fs); e1=wrap(y1-u1,w);
    u2=wrap(e1+h2,w); y2=tern(u2>=0,fs,-fs); e2=wrap(y2-u2,w);
    out.y1(k)=tern(y1>0,int64(1),int64(0)); out.y2(k)=tern(y2>0,int64(1),int64(0));
    out.v1(k)=tern(y1>0,int64(1),int64(-1))+tern(y2>0,int64(1),int64(-1));
    h1=wrap((-a(1)-1)*e11+e12-(a(1)+g(1)-1)*h1,w);
    h2=wrap((-a(2)-1)*e21+e22-(a(2)+g(2)-1)*h2,w);
    e12=e11; e11=e1; e22=e21; e21=e2; v2=tern(y2>0,fs,-fs);
  end
end
function y=wrap(v,w), y=mod(v+int64(2)^(w-1),int64(2)^w)-int64(2)^(w-1); end
function y=tern(c,a,b),if c,y=a;else,y=b;end,end
