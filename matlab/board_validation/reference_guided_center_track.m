function S = reference_guided_center_track()
% reference_guided_center_track
% Use the known RTL reference to track the best center sample per bit in a
% stable DSM000 segment, allowing slow phase drift.

raw = read_numeric_lines(fullfile('data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'));
ref = read_01_lines(fullfile('fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt'));

cap_bit_start = 14721;
ref_start = 55;
n_bits = 25088;
spb = 100;
phase = 64;
half_win = 5;
max_off = 24;
step_choices = -1:1;
step_penalties = [0, 0.1, 0.3, 0.5, 1.0];

ref_seg = cyclic_take(ref, ref_start, n_bits);
ref_sign = 2 * double(ref_seg(:)) - 1;
base_centers = (phase + 1) + (cap_bit_start - 1 + (0:n_bits-1)) * spb;

offsets = -max_off:max_off;
n_states = numel(offsets);
obs = -inf(n_bits, n_states);
for k = 1:n_bits
    for s = 1:n_states
        c = base_centers(k) + offsets(s);
        i0 = max(1, c - half_win);
        i1 = min(numel(raw), c + half_win);
        m = mean(raw(i0:i1));
        obs(k, s) = ref_sign(k) * m;
    end
end

best_match = -inf;
best_score = -inf;
best_offsets = zeros(n_bits, 1);
best_bits = false(n_bits, 1);
best_means = zeros(n_bits, 1);
best_lambda = NaN;
scan_lambda = zeros(numel(step_penalties), 1);
scan_match = zeros(numel(step_penalties), 1);
scan_score = zeros(numel(step_penalties), 1);

for lp = 1:numel(step_penalties)
    lambda = step_penalties(lp);
    dp = -inf(n_bits, n_states);
    pr = zeros(n_bits, n_states, 'int16');
    dp(1, :) = obs(1, :);

    for k = 2:n_bits
        for s = 1:n_states
            best = -inf;
            best_prev = int16(0);
            for ds = step_choices
                prev_off = offsets(s) - ds;
                prev_idx = prev_off - offsets(1) + 1;
                if prev_idx < 1 || prev_idx > n_states
                    continue;
                end
                cand = dp(k-1, prev_idx) + obs(k, s) - lambda * abs(ds);
                if cand > best
                    best = cand;
                    best_prev = int16(prev_idx);
                end
            end
            dp(k, s) = best;
            pr(k, s) = best_prev;
        end
    end

    [score_lp, s] = max(dp(end, :));
    offsets_lp = zeros(n_bits, 1);
    for k = n_bits:-1:1
        offsets_lp(k) = offsets(s);
        if k > 1
            s = pr(k, s);
        end
    end

    centers_lp = base_centers(:) + offsets_lp;
    means_lp = zeros(n_bits, 1);
    bits_lp = false(n_bits, 1);
    for k = 1:n_bits
        c = centers_lp(k);
        i0 = max(1, c - half_win);
        i1 = min(numel(raw), c + half_win);
        means_lp(k) = mean(raw(i0:i1));
        bits_lp(k) = means_lp(k) >= 0;
    end

    match_lp = mean(bits_lp == ref_seg(:));
    scan_lambda(lp) = lambda;
    scan_match(lp) = match_lp;
    scan_score(lp) = score_lp;
    if match_lp > best_match
        best_match = match_lp;
        best_score = score_lp;
        best_offsets = offsets_lp;
        best_bits = bits_lp;
        best_means = means_lp;
        best_lambda = lambda;
    end
end

bits = best_bits;
means = best_means;
match = best_match;
centers = base_centers(:) + best_offsets;
off_stats = table(min(best_offsets), median(best_offsets), max(best_offsets), ...
    'VariableNames', {'min_off', 'median_off', 'max_off'});
step_diff = diff(best_offsets);
step_vals = (-1:1).';
step_cnt = [sum(step_diff == -1); sum(step_diff == 0); sum(step_diff == 1)];
step_tab = table(step_vals, step_cnt, 'VariableNames', {'step', 'count'});
scan_tab = table(scan_lambda, scan_match, scan_score, ...
    'VariableNames', {'lambda', 'match', 'score'});

fid = fopen('reference_guided_center_track_bits.txt', 'w');
assert(fid >= 0);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '%d\n', bits);

T = table((1:n_bits).', centers, best_offsets, means, double(bits), double(ref_seg(:)), ...
    'VariableNames', {'k', 'center', 'offset', 'mean_v', 'bit', 'ref_bit'});
writetable(T, 'reference_guided_center_track.csv');
disp(off_stats);
disp(step_tab);
disp(scan_tab);

S = struct();
S.match = match;
S.best_score = best_score;
S.min_offset = min(best_offsets);
S.max_offset = max(best_offsets);
S.mean_abs_step = mean(abs(step_diff));
fprintf('%s\n', repmat('=', 1, 78));
fprintf('Reference-guided center track\n');
fprintf('  match vs ref       : %.6f\n', match);
fprintf('  best score         : %.6f\n', best_score);
fprintf('  best lambda        : %.3f\n', best_lambda);
fprintf('  offset range       : [%d, %d]\n', min(best_offsets), max(best_offsets));
fprintf('  mean abs step      : %.6f\n', mean(abs(step_diff)));
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
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
