function gen_tid32_thermo3_frontend_bittrue_vectors(output_dir, words, seed, threshold)
%GEN_TID32_THERMO3_FRONTEND_BITTRUE_VECTORS Reference for x2/DPD/x2/TID.
if nargin < 1, output_dir = pwd; end
if nargin < 2, words = 64; end
if nargin < 3, seed = 20260916; end
if nargin < 4, threshold = 8192; end
assert(words >= 2, 'At least two words are required.');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
rng(seed); in_lanes = 8; w = 16;
ii = int64(randi([-12000, 12000], in_lanes, words));
qq = int64(randi([-12000, 12000], in_lanes, words));
ii(:,1) = int64([-32768;-24000;-1;0;1;12000;24000;32767]);
qq(:,1) = int64([32767;24000;1;0;-1;-12000;-24000;-32768]);
c.c1_re = int64([15000,1200,-640,256]); c.c1_im = int64([-120,320,-192,96]);
c.c3_re = int64([4200,-800,384,-128]); c.c3_im = int64([-900,256,-160,64]);
c.c5_re = int64([1800,-320,128,-48]); c.c5_im = int64([-400,160,-64,24]);
h1i = zeros(3,1,'int64'); h1q = h1i;
hdi = zeros(3,1,'int64'); hdq = hdi;
h2i = zeros(3,1,'int64'); h2q = h2i;
state = []; p = false(64,words); m = p;
for word = 1:words
    [x1i,x1q,h1i,h1q] = local_x2(ii(:,word),qq(:,word),h1i,h1q);
    [di,dq,hdi,hdq] = local_memory_dpd(x1i,x1q,hdi,hdq,c);
    [x2i,x2q,h2i,h2q] = local_x2(di,dq,h2i,h2q);
    [p(:,word),m(:,word),state] = tid_thermo3_pipelined_step(x2i,x2q,state,w,threshold);
end
[pf,mf] = tid_thermo3_pipelined_step(zeros(32,1,'int64'),zeros(32,1,'int64'),state,w,threshold);
local_write_samples(fullfile(output_dir,'tid32_frontend_i.mem'),ii(:));
local_write_samples(fullfile(output_dir,'tid32_frontend_q.mem'),qq(:));
local_write_words(fullfile(output_dir,'tid32_frontend_pa_p.mem'),[p(:,2:end),pf]);
local_write_words(fullfile(output_dir,'tid32_frontend_pa_m.mem'),[m(:,2:end),mf]);
end

function [yo_i,yo_q,next_i,next_q] = local_x2(xi,xq,history_i,history_q)
lanes = numel(xi); yo_i = zeros(2*lanes,1,'int64'); yo_q = yo_i;
for lane = 1:lanes
    yo_i(2*lane-1) = xi(lane); yo_q(2*lane-1) = xq(lane);
    ai = int64(0); aq = int64(0); coeff = int64([5120,15360,-5120,1024]);
    for tap = 0:3
        if tap < lane
            si=xi(lane-tap); sq=xq(lane-tap);
        else
            si=history_i(tap-lane+1); sq=history_q(tap-lane+1);
        end
        ai = ai + si*coeff(tap+1); aq = aq + sq*coeff(tap+1);
    end
    yo_i(2*lane) = local_round_sat(ai,14); yo_q(2*lane) = local_round_sat(aq,14);
end
next_i = flipud(xi(end-2:end)); next_q = flipud(xq(end-2:end));
end

function [yo_i,yo_q,next_i,next_q] = local_memory_dpd(xi,xq,history_i,history_q,c)
yo_i=zeros(size(xi),'int64'); yo_q=yo_i; hi=history_i; hq=history_q;
for n=1:numel(xi)
    win_i=[xi(n);hi]; win_q=[xq(n);hq]; ai=int64(0); aq=int64(0);
    for tap=1:4
        r2=bitsra(win_i(tap)*win_i(tap)+win_q(tap)*win_q(tap),15);
        r4=bitsra(r2*r2,15);
        gr=c.c1_re(tap)+bitsra(c.c3_re(tap)*r2,15)+bitsra(c.c5_re(tap)*r4,15);
        gi=c.c1_im(tap)+bitsra(c.c3_im(tap)*r2,15)+bitsra(c.c5_im(tap)*r4,15);
        ai=ai+bitsra(win_i(tap)*gr-win_q(tap)*gi,14);
        aq=aq+bitsra(win_i(tap)*gi+win_q(tap)*gr,14);
    end
    yo_i(n)=local_sat16(ai); yo_q(n)=local_sat16(aq);
    hi=[xi(n);hi(1:2)]; hq=[xq(n);hq(1:2)];
end
next_i=hi; next_q=hq;
end

function y = local_round_sat(x, frac)
if x >= 0, y=bitsra(x+bitshift(int64(1),frac-1),frac); else, y=-bitsra(-x+bitshift(int64(1),frac-1),frac); end
y=local_sat16(y);
end
function y=local_sat16(x), y=min(max(x,int64(-32768)),int64(32767)); end
function local_write_samples(filename,samples)
fid=fopen(filename,'w'); assert(fid>=0,'Cannot create input vector.');
for k=1:numel(samples), fprintf(fid,'%04X\n',uint16(mod(samples(k),int64(65536)))); end
fclose(fid);
end
function local_write_words(filename,words)
fid=fopen(filename,'w'); assert(fid>=0,'Cannot create expected vector.');
for word=1:size(words,2)
    value=uint64(0);
    for bit=1:size(words,1), if words(bit,word), value=bitor(value,bitshift(uint64(1),bit-1)); end, end
    fprintf(fid,'%016X\n',value);
end
fclose(fid);
end
