function S = guided_capture_rtl_align(capture_name, chunk_bits)
% guided_capture_rtl_align
% Reference-guided chunk alignment between scope captures and RTL rf_bits.
%
% This does not rewrite any source waveform files. It refines the coarse
% fixed-phase recovery by allowing small per-chunk sample and reference
% offsets so bit slips can be localized instead of poisoning the entire
% global alignment.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
if nargin < 1 || isempty(capture_name)
    capture_name = 'DSM000';
end
if nargin < 2 || isempty(chunk_bits)
    chunk_bits = 256;
end

cap = capture_spec(repo, capture_name);
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref_bits = read_01_lines(ref_file);
ref_pm = 2*double(ref_bits) - 1;

coarse_cell = recover_scope_rf_bits(capture_name);
coarse = coarse_cell{1};
raw = read_numeric_lines(cap.wfm_file);

cfg = default_cfg(cap.spb_nom, chunk_bits);
scan = scan_blocks(coarse.bits, ref_bits, chunk_bits);
anchor = choose_anchor(scan, numel(ref_bits));

fprintf('%s\n', repmat('=', 1, 78));
fprintf('Guided alignment for %s\n', capture_name);
fprintf('  chunk_bits         : %d\n', chunk_bits);
fprintf('  coarse match       : %.6f\n', coarse.match_rate);
fprintf('  coarse start idx   : %d\n', coarse.start_idx);
fprintf('  coarse invert      : %d\n', coarse.invert);
fprintf('  anchor block       : %d\n', anchor.block_idx);
fprintf('  anchor cap offset  : %d\n', anchor.cap_offset);
fprintf('  anchor start idx   : %d\n', anchor.start_idx);
fprintf('  anchor match       : %.6f\n', anchor.match_rate);
fprintf('  anchor run len     : %d blocks\n', anchor.run_len);

[rows, guided_bits] = walk_guided(raw, ref_pm, coarse, anchor, cfg);
T = struct2table(rows);

eq = guided_bits(1:height(T)*chunk_bits) == collect_ref_bits(T, ref_bits, chunk_bits);
guided_match = mean(eq);
best512 = best_window_from_eq(eq, 512);
best2048 = best_window_from_eq(eq, 2048);
longest_run = longest_true_run(eq);
step_err = wrap_diff(diff(T.ref_start_idx) - chunk_bits, numel(ref_bits));

fprintf('  guided match       : %.6f\n', guided_match);
fprintf('  guided best512     : %.6f\n', best512);
fprintf('  guided best2048    : %.6f\n', best2048);
fprintf('  guided longest run : %d bits\n', longest_run);
fprintf('  median ref step err: %.1f bits\n', median(abs(step_err)));
fprintf('  max ref step err   : %d bits\n', max(abs(step_err)));

csv_tag = regexprep(lower(capture_name), '[^a-z0-9]+', '_');
out_csv = fullfile(repo, sprintf('guided_capture_rtl_align_%s_%db.csv', csv_tag, chunk_bits));
writetable(T, out_csv);
fprintf('  chunk report       : %s\n', out_csv);

S = struct();
S.capture_name = capture_name;
S.chunk_bits = chunk_bits;
S.coarse = coarse;
S.anchor = anchor;
S.table = T;
S.guided_bits = guided_bits;
S.guided_match = guided_match;
S.best512 = best512;
S.best2048 = best2048;
S.longest_run = longest_run;
S.step_err = step_err;
end

function cap = capture_spec(repo, capture_name)
caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'spb_nom', 100), ...
    struct( ...
        'name', 'RefCurve_scope_aux', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'spb_nom', 200) ...
];

keep = false(size(caps));
for k = 1:numel(caps)
    keep(k) = strcmpi(caps(k).name, capture_name);
end
caps = caps(keep);
assert(~isempty(caps), 'Unknown capture_name: %s', capture_name);
cap = caps(1);
end

function cfg = default_cfg(spb, chunk_bits)
cfg.spb = spb;
cfg.chunk_bits = chunk_bits;
cfg.delta_samp = -round(spb/8):round(spb/8);
cfg.delta_ref = -32:32;
cfg.half_win = max(3, round(spb/20));
end

function scan = scan_blocks(bits, ref_bits, block_len)
n_blocks = floor(numel(bits) / block_len);
rows = repmat(struct( ...
    'block_idx', 0, ...
    'cap_offset', 0, ...
    'match_rate', 0, ...
    'invert', false, ...
    'start_idx', 0), n_blocks, 1);

for b = 1:n_blocks
    off = (b-1) * block_len;
    seg = bits(off+1:off+block_len);
    [start_idx, match_rate, invert] = best_cyclic_match(seg, ref_bits);
    rows(b) = struct( ...
        'block_idx', b-1, ...
        'cap_offset', off, ...
        'match_rate', match_rate, ...
        'invert', invert, ...
        'start_idx', start_idx);
end

scan = rows;
end

function anchor = choose_anchor(scan, ref_len)
block_len = scan(2).cap_offset - scan(1).cap_offset;
n = numel(scan);
best.run_len = 1;
best.block_idx = 1;
best.cap_offset = scan(1).cap_offset;
best.start_idx = scan(1).start_idx;
best.match_rate = scan(1).match_rate;

cur_start = 1;
for k = 2:n
    same_inv = scan(k).invert == scan(k-1).invert;
    d = wrap_diff(scan(k).start_idx - scan(k-1).start_idx - block_len, ref_len);
    cont = same_inv && abs(d) <= 2 && ...
        scan(k).match_rate >= 0.75 && scan(k-1).match_rate >= 0.75;
    if ~cont
        best = maybe_update_best(best, scan, cur_start, k-1);
        cur_start = k;
    end
end
best = maybe_update_best(best, scan, cur_start, n);

if best.run_len < 3
    [~, idx] = max([scan.match_rate]);
    pick = scan(idx);
    best.block_idx = pick.block_idx;
    best.cap_offset = pick.cap_offset;
    best.start_idx = pick.start_idx;
    best.match_rate = pick.match_rate;
    best.run_len = 1;
end

anchor = best;
end

function best = maybe_update_best(best, scan, i0, i1)
run_len = i1 - i0 + 1;
if run_len <= 0
    return;
end
match_mean = mean([scan(i0:i1).match_rate]);
best_score = best.run_len * 1000 + best.match_rate;
cand_score = run_len * 1000 + match_mean;
if cand_score > best_score
    mid = floor((i0 + i1) / 2);
    pick = scan(mid);
    best.block_idx = pick.block_idx;
    best.cap_offset = pick.cap_offset;
    best.start_idx = pick.start_idx;
    best.match_rate = match_mean;
    best.run_len = run_len;
end
end

function [rows, guided_bits] = walk_guided(raw, ref_pm, coarse, anchor, cfg)
chunk_bits = cfg.chunk_bits;
n_bits = numel(coarse.bits);
n_chunks = floor(n_bits / chunk_bits);
ref_len = numel(ref_pm);

rows = repmat(struct( ...
    'chunk_idx', 0, ...
    'bit_offset', 0, ...
    'ref_start_idx', 0, ...
    'match_rate', 0, ...
    'analog_score', 0, ...
    'sample_center0', 0, ...
    'sample_delta', 0, ...
    'ref_delta', 0, ...
    'invert', coarse.invert), n_chunks, 1);
guided_bits = false(n_chunks * chunk_bits, 1);

anchor_chunk = anchor.block_idx + 1;
sample0 = round(coarse.phase + 1 + anchor.cap_offset * coarse.spb);
ref0 = anchor.start_idx;

[rows(anchor_chunk), bits_anchor] = refine_chunk(raw, ref_pm, sample0, ref0, coarse.invert, cfg, anchor.block_idx);
put_chunk_bits(anchor_chunk, bits_anchor);

for k = anchor_chunk+1:n_chunks
    prev = rows(k-1);
    sample_pred = prev.sample_center0 + chunk_bits * coarse.spb;
    ref_pred = wrap_idx(prev.ref_start_idx + chunk_bits, ref_len);
    [rows(k), bits_k] = refine_chunk(raw, ref_pm, sample_pred, ref_pred, coarse.invert, cfg, k-1);
    put_chunk_bits(k, bits_k);
end

for k = anchor_chunk-1:-1:1
    nxt = rows(k+1);
    sample_pred = nxt.sample_center0 - chunk_bits * coarse.spb;
    ref_pred = wrap_idx(nxt.ref_start_idx - chunk_bits, ref_len);
    [rows(k), bits_k] = refine_chunk(raw, ref_pm, sample_pred, ref_pred, coarse.invert, cfg, k-1);
    put_chunk_bits(k, bits_k);
end

    function put_chunk_bits(chunk_idx, bits)
        off = (chunk_idx-1) * chunk_bits;
        guided_bits(off+1:off+chunk_bits) = bits;
    end
end

function [row, bits] = refine_chunk(raw, ref_pm, sample_pred, ref_pred, invert, cfg, chunk_idx0)
chunk_bits = cfg.chunk_bits;
spb = cfg.spb;
ref_len = numel(ref_pm);
raw_csum = [0; cumsum(raw(:))];
sample0_min = 1 + cfg.half_win;
sample0_max = numel(raw) - cfg.half_win - (chunk_bits-1) * spb;
best = struct('score', -inf, 'match_rate', -inf, 'sample0', sample_pred, ...
    'ref_start', ref_pred, 'sample_delta', 0, 'ref_delta', 0, ...
    'analog_score', -inf, 'bits', false(chunk_bits, 1), 'valid', false);

for ds = cfg.delta_samp
    sample0 = round(sample_pred + ds);
    centers = round(sample0 + (0:chunk_bits-1) * spb);
    if centers(1) - cfg.half_win < 1 || centers(end) + cfg.half_win > numel(raw)
        continue;
    end

    means = centered_means(raw_csum, centers, cfg.half_win);
    bits_local = means >= 0;
    bits_pm = 2*double(bits_local) - 1;

    for dr = cfg.delta_ref
        ref_start = wrap_idx(ref_pred + dr, ref_len);
        ref_seg_pm = cyclic_take_pm(ref_pm, ref_start, chunk_bits);
        if invert
            pred_pm = -ref_seg_pm;
        else
            pred_pm = ref_seg_pm;
        end

        analog_score = sum(pred_pm .* means);
        match_rate = mean(bits_pm == pred_pm);
        if analog_score > best.score + 1e-12 || ...
                (abs(analog_score - best.score) <= 1e-12 && match_rate > best.match_rate)
            best.score = analog_score;
            best.match_rate = match_rate;
            best.sample0 = sample0;
            best.ref_start = ref_start;
            best.sample_delta = ds;
            best.ref_delta = dr;
            best.analog_score = analog_score;
            best.bits = bits_local;
            best.valid = true;
        end
    end
end

if ~best.valid
    sample0 = min(max(round(sample_pred), sample0_min), sample0_max);
    centers = round(sample0 + (0:chunk_bits-1) * spb);
    means = centered_means(raw_csum, centers, cfg.half_win);
    bits_local = means >= 0;
    bits_pm = 2*double(bits_local) - 1;
    for dr = cfg.delta_ref
        ref_start = wrap_idx(ref_pred + dr, ref_len);
        ref_seg_pm = cyclic_take_pm(ref_pm, ref_start, chunk_bits);
        if invert
            pred_pm = -ref_seg_pm;
        else
            pred_pm = ref_seg_pm;
        end
        analog_score = sum(pred_pm .* means);
        match_rate = mean(bits_pm == pred_pm);
        if analog_score > best.score + 1e-12 || ...
                (abs(analog_score - best.score) <= 1e-12 && match_rate > best.match_rate)
            best.score = analog_score;
            best.match_rate = match_rate;
            best.sample0 = sample0;
            best.ref_start = ref_start;
            best.sample_delta = sample0 - round(sample_pred);
            best.ref_delta = dr;
            best.analog_score = analog_score;
            best.bits = bits_local;
            best.valid = true;
        end
    end
end

row = struct( ...
    'chunk_idx', chunk_idx0, ...
    'bit_offset', chunk_idx0 * chunk_bits, ...
    'ref_start_idx', best.ref_start, ...
    'match_rate', best.match_rate, ...
    'analog_score', best.analog_score, ...
    'sample_center0', best.sample0, ...
    'sample_delta', best.sample_delta, ...
    'ref_delta', best.ref_delta, ...
    'invert', invert);
bits = best.bits;
end

function means = centered_means(raw_csum, centers, half_win)
i0 = centers(:) - half_win;
i1 = centers(:) + half_win;
means = (raw_csum(i1+1) - raw_csum(i0)) ./ (i1 - i0 + 1);
end

function vals = cyclic_take_pm(ref_pm, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(ref_pm)) + 1;
vals = ref_pm(idx(:));
end

function bits = collect_ref_bits(T, ref_bits, chunk_bits)
bits = false(height(T) * chunk_bits, 1);
for k = 1:height(T)
    ref_seg = cyclic_take(ref_bits, T.ref_start_idx(k), chunk_bits);
    if T.invert(k)
        ref_seg = ~ref_seg;
    end
    off = (k-1) * chunk_bits;
    bits(off+1:off+chunk_bits) = ref_seg;
end
end

function r = best_window_from_eq(eq, win)
if numel(eq) < win
    r = NaN;
    return;
end
hits = conv(double(eq(:)), ones(win, 1), 'valid');
r = max(hits) / win;
end

function n = longest_true_run(eq)
best = 0;
cur = 0;
for k = 1:numel(eq)
    if eq(k)
        cur = cur + 1;
        best = max(best, cur);
    else
        cur = 0;
    end
end
n = best;
end

function [start_idx, match_rate, invert] = best_cyclic_match(cap_bits, ref_bits)
ref_pm = 2*double(ref_bits(:)) - 1;
cap_pm = 2*double(cap_bits(:)) - 1;

score_n = cyclic_corr(ref_pm, cap_pm);
score_i = cyclic_corr(ref_pm, -cap_pm);

[peak_n, idx_n] = max(score_n);
[peak_i, idx_i] = max(score_i);

if peak_i > peak_n
    invert = true;
    peak = peak_i;
    start_idx = idx_i;
else
    invert = false;
    peak = peak_n;
    start_idx = idx_n;
end

match_rate = (peak / numel(cap_pm) + 1) / 2;
end

function score = cyclic_corr(ref_pm, cap_pm)
n_ref = numel(ref_pm);
n_cap = numel(cap_pm);
ref_ext = [ref_pm; ref_pm(1:n_cap-1)];
score = conv(ref_ext, flipud(cap_pm), 'valid');
score = score(1:n_ref);
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function d = wrap_diff(x, mod_n)
d = mod(x + floor(mod_n/2), mod_n) - floor(mod_n/2);
end

function idx = wrap_idx(idx, mod_n)
idx = mod(idx - 1, mod_n) + 1;
end

function bits = read_01_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

bits = false(0, 1);
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    s = strtrim(t);
    if isempty(s)
        continue;
    end
    parts = split(s);
    x = str2double(parts{1});
    if ~isnan(x)
        bits(end+1, 1) = x ~= 0; %#ok<AGROW>
    end
end
end

function raw = read_numeric_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

raw = zeros(0, 1);
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    x = str2double(strtrim(t));
    if ~isnan(x)
        raw(end+1, 1) = x; %#ok<AGROW>
    end
end
end
