function [levels, residues] = mash111_scalar(iq)
% Research-only scalar fixed-point MASH 1-1-1. Input is N-by-2 signed Q15.
% Outputs are exact odd levels reconstructed by 1:2:4 bipolar planes.
assert(size(iq,2)==2 && all(iq(:)>=-32768 & iq(:)<=32767));
n=size(iq,1); levels=zeros(n,2); residues=zeros(n,2,3);
r=zeros(3,2); qprev=-ones(3,2); qprev2=qprev; r3history=zeros(3,2);
for k=1:n
  for c=1:2
    x=double(iq(k,c)); q=zeros(3,1);
    for stage=1:3
      if stage==1, drive=x+32768; else, drive=r(stage-1,c); end
      total=r(stage,c)+drive; bit=floor(total/65536);
      assert(bit==0 || bit==1); r(stage,c)=mod(total,65536);
      q(stage)=2*bit-1; residues(k,c,stage)=r(stage,c);
    end
    y=q(1)+q(2)-qprev(2,c)+q(3)-2*qprev(3,c)+qprev2(3,c);
    d3=r(3,c)-3*r3history(1,c)+3*r3history(2,c)-r3history(3,c);
    assert(32768*y==x-d3 && abs(y)<=7 && mod(y,2)==1);
    levels(k,c)=y; r3history(:,c)=[r(3,c);r3history(1:2,c)];
    qprev2(:,c)=qprev(:,c); qprev(:,c)=q;
  end
end
end
