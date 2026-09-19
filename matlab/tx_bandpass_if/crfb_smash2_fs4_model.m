function out = crfb_smash2_fs4_model(x, varargin)
% CRFB_SMASH2_FS4_MODEL Vector wrapper for the checked scalar CRFB transition.
  x=int64(x(:)); out=struct('y1',false(size(x)),'y2',false(size(x)), ...
    'v1',zeros(size(x),'int64'),'e1',zeros(size(x),'int64'),'e2',zeros(size(x),'int64'));
  st=[];
  for n=1:numel(x)
    [o,st]=crfb_smash2_scalar_transition(x(n),st,varargin{:});
    out.y1(n)=o.y1; out.y2(n)=o.y2; out.v1(n)=o.v1; out.e1(n)=o.e1; out.e2(n)=o.e2;
  end
  out.final_state=st;
end
