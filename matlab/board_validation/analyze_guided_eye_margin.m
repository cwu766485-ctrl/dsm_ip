function S = analyze_guided_eye_margin(capture_name, guided_csv, stable_chunk_start, stable_chunk_end)
% analyze_guided_eye_margin
% Compare scope center-sample polarities against RTL bits over a guided map.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
if nargin < 1 || isempty(capture_name)
    capture_name = 'DSM000';
end
if nargin < 2 || isempty(guided_csv)
    switch lower(capture_name)
        case 'dsm000'
            guided_csv = fullfile(repo, 'guided_capture_rtl_align_dsm000_128b.csv');
        otherwise
            guided_csv = fullfile(repo, 'guided_capture_rtl_align_refcurve_scope_aux_128b.csv');
    end
end

[cap, raw] = capture_spec(repo, capture_name);
T = readtable(guided_csv);
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref = read_01_lines(ref_file);

if nargin < 3 || isempty(stable_chunk_start) || nargin < 4 || isempty(stable_chunk_end)
    [stable_chunk_start, stable_chunk_end] = longest_stable_run(T, 128, numel(ref));
end

sel = (T.chunk_idx >= stable_chunk_start) & (T.chunk_idx <= stable_chunk_end);
Ts = T(sel, :);
chunk_bits = median(diff(T.bit_offset));
assert(~isnan(chunk_bits) && chunk_bits > 0, 'Cannot infer chunk_bits');
chunk_bits = round(chunk_bits);

all_means = zeros(height(Ts) * chunk_bits, 1);
all_ref = false(height(Ts) * chunk_bits, 1);
all_cap = false(height(Ts) * chunk_bits, 1);
raw_csum = [0; cumsum(raw(:))];

wr = 1;
for k = 1:height(Ts)
    centers = round(Ts.sample_center0(k) + (0:chunk_bits-1) * cap.spb);
    means = centered_means(raw_csum, centers, cap.half_win);
    ref_bits = cyclic_take(ref, Ts.ref_start_idx(k), chunk_bits);
    if Ts.invert(k)
        ref_bits = ~ref_bits;
    end

    idx = wr:(wr + chunk_bits - 1);
    all_means(idx) = means;
    all_ref(idx) = ref_bits;
    all_cap(idx) = means >= 0;
    wr = wr + chunk_bits;
end

mismatch = all_cap ~= all_ref;
agree = ~mismatch;
S = struct();
S.capture_name = capture_name;
S.guided_csv = guided_csv;
S.stable_chunk_start = stable_chunk_start;
S.stable_chunk_end = stable_chunk_end;
S.n_bits = numel(all_ref);
S.match_rate = mean(agree);
S.n_mismatch = sum(mismatch);
S.mean_abs_margin_match = mean(abs(all_means(agree)));
S.mean_abs_margin_mismatch = mean(abs(all_means(mismatch)));
S.median_abs_margin_match = median(abs(all_means(agree)));
S.median_abs_margin_mismatch = median(abs(all_means(mismatch)));
S.p10_abs_margin_match = prctile(abs(all_means(agree)), 10);
S.p10_abs_margin_mismatch = prctile(abs(all_means(mismatch)), 10);

fprintf('%s\n', repmat('=', 1, 78));
fprintf('Eye-margin analysis for %s\n', capture_name);
fprintf('  stable chunks      : %d .. %d\n', stable_chunk_start, stable_chunk_end);
fprintf('  analyzed bits      : %d\n', S.n_bits);
fprintf('  center-sign match  : %.6f\n', S.match_rate);
fprintf('  mismatches         : %d\n', S.n_mismatch);
fprintf('  |margin| mean ok   : %.6f V\n', S.mean_abs_margin_match);
fprintf('  |margin| mean bad  : %.6f V\n', S.mean_abs_margin_mismatch);
fprintf('  |margin| median ok : %.6f V\n', S.median_abs_margin_match);
fprintf('  |margin| median bad: %.6f V\n', S.median_abs_margin_mismatch);
fprintf('  |margin| p10 ok    : %.6f V\n', S.p10_abs_margin_match);
fprintf('  |margin| p10 bad   : %.6f V\n', S.p10_abs_margin_mismatch);
end

function [cap, raw] = capture_spec(repo, capture_name)
switch lower(capture_name)
    case 'dsm000'
        cap = struct( ...
            'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
            'spb', 100, ...
            'half_win', 3);
    otherwise
        cap = struct( ...
            'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
            'spb', 200, ...
            'half_win', 5);
end
raw = read_numeric_lines(cap.wfm_file);
end

function [chunk_start, chunk_end] = longest_stable_run(T, chunk_bits, ref_len)
d = wrap_diff(diff(T.ref_start_idx) - chunk_bits, ref_len);
stable = abs(d) <= 2;
best = 0;
cur = 0;
best_end = 1;
for k = 1:numel(stable)
    if stable(k)
        cur = cur + 1;
        if cur > best
            best = cur;
            best_end = k + 1;
        end
    else
        cur = 0;
    end
end
chunk_start = T.chunk_idx(best_end - best);
chunk_end = T.chunk_idx(best_end);
end

function means = centered_means(csum, centers, half_win)
i0 = centers(:) - half_win;
i1 = centers(:) + half_win;
means = (csum(i1+1) - csum(i0)) ./ (i1 - i0 + 1);
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function d = wrap_diff(x, mod_n)
d = mod(x + floor(mod_n/2), mod_n) - floor(mod_n/2);
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
