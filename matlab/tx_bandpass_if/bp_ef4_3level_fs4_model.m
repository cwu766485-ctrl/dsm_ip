function [level, core] = bp_ef4_3level_fs4_model(x, varargin)
% BP_EF4_3LEVEL_FS4_MODEL Three-level version of the verified BP-EF4 NTF.
% NTF=(1+z^-2)^2; LEVEL {-1,0,+1} maps to two one-bit PA branches.
  p=inputParser;
  addParameter(p,'acc_w',28); addParameter(p,'saturate',true);
  addParameter(p,'threshold_num',1); addParameter(p,'threshold_den',2);
  parse(p,varargin{:}); c=p.Results;
  x=int64(x(:)); fs=int64(32767);
  th=idivide(fs*int64(c.threshold_num),int64(c.threshold_den),'fix');
  e1=int64(0); e2=int64(0); e3=int64(0); e4=int64(0);
  level=zeros(numel(x),1,'int64'); core=level;
  for n=1:numel(x)
    v=sat_or_wrap(x(n)-2*e2-e4,c.acc_w,logical(c.saturate));
    if v>th, q=fs; level(n)=1;
    elseif v < -th, q=-fs; level(n)=-1;
    else, q=int64(0); level(n)=0; end
    e0=sat_or_wrap(v-q,c.acc_w,false);
    e4=e3; e3=e2; e2=e1; e1=e0; core(n)=v;
  end
end
function y=sat_or_wrap(v,w,s)
  hi=int64(2)^(w-1)-1; lo=-int64(2)^(w-1);
  if s,y=min(max(v,lo),hi);else,y=mod(v+int64(2)^(w-1),int64(2)^w)-int64(2)^(w-1);end
end
