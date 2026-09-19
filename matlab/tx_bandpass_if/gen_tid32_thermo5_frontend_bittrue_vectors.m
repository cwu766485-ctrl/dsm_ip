function gen_tid32_thermo5_frontend_bittrue_vectors(output_dir, words, seed, step)
%GEN_TID32_THERMO5_FRONTEND_BITTRUE_VECTORS Packed reference for frame-gain,
% two x2 interpolators, identity Q2.14 memory-DPD, and five-level TID.
if nargin < 1, output_dir = pwd; end
if nargin < 2, words = 64; end
if nargin < 3, seed = 20260918; end
if nargin < 4, step = 7168; end
assert(words >= 12, 'At least 12 words are required for frame-gain coverage.');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
rng(seed); lanes = 8; w = 16;
ii = int64(randi([-12000, 12000], lanes, words));
qq = int64(randi([-12000, 12000], lanes, words));
ii(:,1) = int64([-32768;-24000;-1;0;1;12000;24000;32767]);
qq(:,1) = int64([32767;24000;1;0;-1;-12000;-24000;-32768]);
frame_start = false(words,1); frame_start([1, 17, 39]) = true;
frame_gain = repmat(int64(16384),words,1);
frame_gain(1) = int64(16384); frame_gain(17) = int64(14336); frame_gain(39) = int64(12288);
h1i = zeros(3,1,'int64'); h1q = h1i; hdi = h1i; hdq = h1i; h2i = h1i; h2q = h1i;
state = []; pa = false(64,words,4); active_gain = int64(16384);
for word = 1:words
    if frame_start(word), active_gain = frame_gain(word); end
    [gi,gq] = local_apply_gain(ii(:,word),qq(:,word),active_gain);
    [x1i,x1q,h1i,h1q] = local_x2(gi,gq,h1i,h1q);
    [di,dq,hdi,hdq] = local_identity_dpd(x1i,x1q,hdi,hdq);
    [x2i,x2q,h2i,h2q] = local_x2(di,dq,h2i,h2q);
    [raw_word,state] = tid_thermo5_pipelined_step(x2i,x2q,state,w,step);
    for branch = 1:4
        pa(:,word,branch) = raw_word(:,branch);
    end
end
[flush,state] = tid_thermo5_pipelined_step( ...
    zeros(32,1,'int64'),zeros(32,1,'int64'),state,w,step); %#ok<ASGLU>
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_i.mem'),ii(:));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_q.mem'),qq(:));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_frame_start.mem'),int64(frame_start));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_frame_gain.mem'),frame_gain);
for branch = 1:4
    local_write_words(fullfile(output_dir,sprintf('tid32_thermo5_frontend_pa%d.mem',branch-1)), ...
        [pa(:,2:end,branch),flush(:,branch)]);
end
end

function [yo_i,yo_q] = local_apply_gain(xi,xq,gain)
yo_i=zeros(size(xi),'int64'); yo_q=yo_i;
for k=1:numel(xi)
    yo_i(k)=local_round_sat(xi(k)*gain,14); yo_q(k)=local_round_sat(xq(k)*gain,14);
end
end

function [yo_i,yo_q,next_i,next_q] = local_x2(xi,xq,history_i,history_q)
lanes=numel(xi); yo_i=zeros(2*lanes,1,'int64'); yo_q=yo_i; coeff=int64([5120,15360,-5120,1024]);
for lane=1:lanes
    yo_i(2*lane-1)=xi(lane); yo_q(2*lane-1)=xq(lane); ai=int64(0); aq=int64(0);
    for tap=0:3
        if tap<lane, si=xi(lane-tap); sq=xq(lane-tap); else, si=history_i(tap-lane+1); sq=history_q(tap-lane+1); end
        ai=ai+si*coeff(tap+1); aq=aq+sq*coeff(tap+1);
    end
    yo_i(2*lane)=local_round_sat(ai,14); yo_q(2*lane)=local_round_sat(aq,14);
end
next_i=flipud(xi(end-2:end)); next_q=flipud(xq(end-2:end));
end

function [yo_i,yo_q,next_i,next_q] = local_identity_dpd(xi,xq,history_i,history_q)
% Keep the same packed history contract as the vector memory DPD while its
% production coefficient set is identity (one active tap, c1=1, c3=c5=0).
yo_i=xi; yo_q=xq; next_i=flipud(xi(end-2:end)); next_q=flipud(xq(end-2:end));
end

function y=local_round_sat(x,frac), if x>=0, y=bitsra(x+bitshift(int64(1),frac-1),frac); else, y=-bitsra(-x+bitshift(int64(1),frac-1),frac); end, y=local_sat16(y); end
function y=local_sat16(x), y=min(max(x,int64(-32768)),int64(32767)); end
function local_write_samples(filename,samples), fid=fopen(filename,'w'); assert(fid>=0,'Cannot create vector.'); for k=1:numel(samples), fprintf(fid,'%04X\n',uint16(mod(samples(k),int64(65536)))); end, fclose(fid); end
function local_write_words(filename,words), fid=fopen(filename,'w'); assert(fid>=0,'Cannot create vector.'); for word=1:size(words,2), value=uint64(0); for bit=1:size(words,1), if words(bit,word), value=bitor(value,bitshift(uint64(1),bit-1)); end, end, fprintf(fid,'%016X\n',value); end, fclose(fid); end
