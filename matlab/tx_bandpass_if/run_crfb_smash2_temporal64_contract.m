function result = run_crfb_smash2_temporal64_contract(varargin)
% RUN_CRFB_SMASH2_TEMPORAL64_CONTRACT Prove 64-step composition equality.
  p=inputParser; addParameter(p,'words',128); addParameter(p,'seed',20260915);
  parse(p,varargin{:}); c=p.Results; rng(c.seed);
  x=int64(randi([-16384 16383],64*c.words,1));
  serial_y1=false(size(x)); serial_y2=false(size(x)); serial_v1=zeros(size(x),'int64');
  st=[];
  for n=1:numel(x), [o,st]=crfb_smash2_scalar_transition(x(n),st); serial_y1(n)=o.y1; serial_y2(n)=o.y2; serial_v1(n)=o.v1; end
  serial_final=st;
  st=[]; y1=false(size(x)); y2=false(size(x)); v1=zeros(size(x),'int64');
  for w=1:c.words
    base=(w-1)*64;
    for lane=1:64
      [o,st]=crfb_smash2_scalar_transition(x(base+lane),st);
      y1(base+lane)=o.y1; y2(base+lane)=o.y2; v1(base+lane)=o.v1;
    end
  end
  fields=fieldnames(st); state_equal=true;
  for k=1:numel(fields), state_equal=state_equal && isequal(st.(fields{k}),serial_final.(fields{k})); end
  result=struct('words',c.words,'samples',numel(x),'y1_mismatches',nnz(y1~=serial_y1), ...
    'y2_mismatches',nnz(y2~=serial_y2),'v1_mismatches',nnz(v1~=serial_v1),'final_state_equal',state_equal);
  disp(result);
  if result.y1_mismatches || result.y2_mismatches || result.v1_mismatches || ~state_equal
    error('CRFB temporal64 contract failed.');
  end
end
