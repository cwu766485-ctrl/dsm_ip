function gen_tid32_thermo5_frontend_bittrue_vectors(output_dir, words, seed, step, interp_taps, frame_start_words, profile, frame_gains, engine)
%GEN_TID32_THERMO5_FRONTEND_BITTRUE_VECTORS Packed reference for frame-gain,
% two x2 interpolators, identity memory-DPD path, and five-level TID.
if nargin < 1, output_dir = pwd; end
if nargin < 2, words = 64; end
if nargin < 3, seed = 20260918; end
if nargin < 4, step = 7168; end
if nargin < 5, interp_taps = 4; end
if nargin < 6, frame_start_words = [1, 17, 39]; end
if nargin < 7, profile = 'random'; end
if nargin < 8, frame_gains = [16384,14336,12288]; end
if nargin < 9, engine = 'fast'; end
assert(words >= 12, 'At least 12 words are required for frame-gain coverage.');
assert(ismember(interp_taps,[2 3 4]), 'interp_taps must be 2, 3, or 4.');
assert(all(frame_start_words >= 1 & frame_start_words <= words), ...
    'Frame starts must lie within generated words.');
assert(~isempty(frame_gains) && all(frame_gains >= -32768 & frame_gains <= 32767) ...
    && all(frame_gains == fix(frame_gains)), 'Frame gains must be signed 16-bit integers.');
assert(ismember(engine,{'fast','legacy'}), 'engine must be fast or legacy.');
if ~exist(output_dir, 'dir'), mkdir(output_dir); end
rng(seed); lanes = 8; w = 16;
ii = int64(randi([-12000, 12000], lanes, words));
qq = int64(randi([-12000, 12000], lanes, words));
extreme_i = int64([-32768;-24000;-1;0;1;12000;24000;32767]);
extreme_q = int64([32767;24000;1;0;-1;-12000;-24000;-32768]);
if strcmp(profile,'extreme')
    for word = 1:words
        ii(:,word) = circshift(extreme_i,mod(word-1,lanes));
        qq(:,word) = circshift(extreme_q,mod(3*(word-1),lanes));
    end
elseif strcmp(profile,'range_stress')
    % Hold each signed endpoint for four vector words so both interpolator
    % phases reach the endpoint on every lane, including offset TID branches.
    for word = 1:words
        if mod(floor((word-1)/4),2)==0
            ii(:,word)=int64(-32768); qq(:,word)=int64(32767);
        else
            ii(:,word)=int64(32767); qq(:,word)=int64(-32768);
        end
    end
elseif ~strcmp(profile,'random')
    error('Unsupported vector profile: %s',profile);
end
ii(:,1) = extreme_i;
qq(:,1) = extreme_q;
frame_start = false(words,1); frame_start(frame_start_words) = true;
frame_gain = repmat(int64(16384),words,1);
gain_choices = int64(frame_gains);
for n = 1:numel(frame_start_words)
    frame_gain(frame_start_words(n)) = gain_choices(mod(n-1,numel(gain_choices))+1);
end
if strcmp(profile,'range_stress'), frame_gain(:)=int64(16384); end
h1i = zeros(interp_taps-1,1,'int64'); h1q = h1i; h2i = h1i; h2q = h1i;
state = []; pa = false(64,words,4); active_gain = int64(16384);
for word = 1:words
    if frame_start(word), active_gain = frame_gain(word); end
    [gi,gq] = local_apply_gain(ii(:,word),qq(:,word),active_gain);
    [x1i,x1q,h1i,h1q] = local_x2(gi,gq,h1i,h1q,interp_taps);
    [x2i,x2q,h2i,h2q] = local_x2(x1i,x1q,h2i,h2q,interp_taps);
    if strcmp(engine,'legacy')
        [raw_word,state] = tid_thermo5_pipelined_step(x2i,x2q,state,w,step);
    else
        [raw_word,state] = local_tid_fast(x2i,x2q,state,w,step);
    end
    for branch = 1:4
        pa(:,word,branch) = raw_word(:,branch);
    end
end
if strcmp(engine,'legacy')
    [flush,state] = tid_thermo5_pipelined_step( ...
        zeros(32,1,'int64'),zeros(32,1,'int64'),state,w,step); %#ok<ASGLU>
else
    [flush,state] = local_tid_fast(zeros(32,1,'int64'),zeros(32,1,'int64'),state,w,step); %#ok<ASGLU>
end
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_i.mem'),ii(:));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_q.mem'),qq(:));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_frame_start.mem'),int64(frame_start));
local_write_samples(fullfile(output_dir,'tid32_thermo5_frontend_frame_gain.mem'),frame_gain);
for branch = 1:4
    local_write_words(fullfile(output_dir,sprintf('tid32_thermo5_frontend_pa%d.mem',branch-1)), ...
        [pa(:,2:end,branch),flush(:,branch)]);
end

function [pa_words,state] = local_tid_fast(i_poly,q_poly,state,w,step)
% Generator-local vectorized form of tid_thermo5_pipelined_step. Keep the
% public reference path selectable as an independent byte-for-byte oracle.
lanes=numel(i_poly); offsets=int64([3 1 -1 -3])*int64(step);
limit_hi=int64(2)^(w-1)-1; limit_lo=-int64(2)^(w-1);
pa_words=false(2*lanes,4);
if isempty(state), state.branch=cell(4,1); end
for b=1:4
    ib=min(max(int64(i_poly(:))+offsets(b),limit_lo),limit_hi);
    qb=min(max(int64(q_poly(:))+offsets(b),limit_lo),limit_hi);
    s=state.branch{b};
    if isempty(s)
        s.a_i=zeros(lanes,lanes,'int64'); s.a_q=s.a_i;
        s.v_i=zeros(lanes,1,'int64'); s.v_q=s.v_i;
    end
    msb_i=s.v_i<0; msb_q=s.v_q<0;
    yi=[msb_i(1); xor(msb_i(2:end),msb_i(1:end-1))];
    yq=[msb_q(1); xor(msb_q(2:end),msb_q(1:end-1))];
    even=mod((0:lanes-1)',2)==0;
    pa_words(1:2:end,b)=xor(yi,~even);
    pa_words(2:2:end,b)=xor(yq,even);

    na_i=zeros(lanes,lanes,'int64'); na_q=na_i;
    na_i(:,1)=local_wrap_signed(local_signed_to_efm_input(ib,w),w+1);
    na_q(:,1)=local_wrap_signed(local_signed_to_efm_input(qb,w),w+1);
    na_i(:,2:end)=s.a_i(:,1:end-1); na_q(:,2:end)=s.a_q(:,1:end-1);
    d=2:lanes; di=sub2ind([lanes lanes],d,d);
    na_i(di)=local_wrap_signed(s.a_i(sub2ind([lanes lanes],d-1,d-1))+s.a_i(sub2ind([lanes lanes],d,d-1)),w+1);
    na_q(di)=local_wrap_signed(s.a_q(sub2ind([lanes lanes],d-1,d-1))+s.a_q(sub2ind([lanes lanes],d,d-1)),w+1);
    feedback_i=mod(s.v_i(lanes),int64(2)^w); feedback_q=mod(s.v_q(lanes),int64(2)^w);
    s.v_i=local_wrap_signed(s.a_i(:,lanes)+feedback_i,w+1);
    s.v_q=local_wrap_signed(s.a_q(:,lanes)+feedback_q,w+1);
    s.a_i=na_i; s.a_q=na_q; state.branch{b}=s;
end
end

function value=local_wrap_signed(value,bits)
modulus=int64(2)^bits; half=int64(2)^(bits-1);
value=mod(value+half,modulus)-half;
end
function value=local_signed_to_efm_input(value,bits)
value=mod(int64(value)+int64(2)^(bits-1),int64(2)^bits);
end
end

function [yo_i,yo_q] = local_apply_gain(xi,xq,gain)
yo_i=zeros(size(xi),'int64'); yo_q=yo_i;
for k=1:numel(xi)
    yo_i(k)=local_round_sat(xi(k)*gain,14); yo_q(k)=local_round_sat(xq(k)*gain,14);
end
end

function [yo_i,yo_q,next_i,next_q] = local_x2(xi,xq,history_i,history_q,interp_taps)
lanes=numel(xi); yo_i=zeros(2*lanes,1,'int64'); yo_q=yo_i;
switch interp_taps
    case 2, coeff=int64([8192,8192]);
    case 3, coeff=int64([6144,12288,-2048]);
    case 4, coeff=int64([5120,15360,-5120,1024]);
    otherwise, error('Unsupported interpolation tap count.');
end
for lane=1:lanes
    yo_i(2*lane-1)=xi(lane); yo_q(2*lane-1)=xq(lane); ai=int64(0); aq=int64(0);
    for tap=0:interp_taps-1
        if tap<lane, si=xi(lane-tap); sq=xq(lane-tap); else, si=history_i(tap-lane+1); sq=history_q(tap-lane+1); end
        ai=ai+si*coeff(tap+1); aq=aq+sq*coeff(tap+1);
    end
    yo_i(2*lane)=local_round_sat(ai,14); yo_q(2*lane)=local_round_sat(aq,14);
end
next_i=flipud(xi(end-interp_taps+2:end)); next_q=flipud(xq(end-interp_taps+2:end));
end

function y=local_round_sat(x,frac), if x>=0, y=bitsra(x+bitshift(int64(1),frac-1),frac); else, y=-bitsra(-x+bitshift(int64(1),frac-1),frac); end, y=local_sat16(y); end
function y=local_sat16(x), y=min(max(x,int64(-32768)),int64(32767)); end
function local_write_samples(filename,samples), fid=fopen(filename,'w'); assert(fid>=0,'Cannot create vector.'); for k=1:numel(samples), fprintf(fid,'%04X\n',uint16(mod(samples(k),int64(65536)))); end, fclose(fid); end
function local_write_words(filename,words), fid=fopen(filename,'w'); assert(fid>=0,'Cannot create vector.'); for word=1:size(words,2), value=uint64(0); for bit=1:size(words,1), if words(bit,word), value=bitor(value,bitshift(uint64(1),bit-1)); end, end, fprintf(fid,'%016X\n',value); end, fclose(fid); end
