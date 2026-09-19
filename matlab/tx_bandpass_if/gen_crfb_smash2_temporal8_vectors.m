function gen_crfb_smash2_temporal8_vectors(varargin)
% Generate scalar-oracle vectors for the exact temporal8 CRFB RTL prototype.
  p=inputParser; addParameter(p,'words',256); addParameter(p,'seed',20260915);
  addParameter(p,'output','crfb_temporal8_equivalence.csv'); parse(p,varargin{:}); c=p.Results;
  rng(c.seed); x=int64(randi([-16384 16383],8*c.words,1)); st=[];
  fid=fopen(c.output,'w'); if fid<0,error('Cannot open output: %s',c.output);end
  cleanup=onCleanup(@() fclose(fid));
  fprintf(fid,'word,x0,x1,x2,x3,x4,x5,x6,x7,y1,y2,re1,kv1,re2,e1d1,e1d2,e2d1,e2d2,v2d1,v2d2\n');
  for w=1:c.words
    base=(w-1)*8; y1=uint8(0); y2=uint8(0);
    for lane=1:8
      [o,st]=crfb_smash2_scalar_transition(x(base+lane),st);
      if o.y1,y1=bitor(y1,bitshift(uint8(1),lane-1));end
      if o.y2,y2=bitor(y2,bitshift(uint8(1),lane-1));end
    end
    fprintf(fid,'%d',w-1);
    fprintf(fid,',%d',x(base+(1:8)));
    fprintf(fid,',%d,%d',y1,y2);
    fprintf(fid,',%d',int64([st.re1 st.kv1 st.re2 st.e1_d1 st.e1_d2 st.e2_d1 st.e2_d2 st.v2_d1 st.v2_d2]));
    fprintf(fid,'\n');
  end
end
