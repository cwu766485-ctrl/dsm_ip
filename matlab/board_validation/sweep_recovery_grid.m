function S = sweep_recovery_grid(capture_name, spb_grid, phase_step)
% sweep_recovery_grid
% Sweep samples-per-bit and phase for a scope capture against RTL rf_bits.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
if nargin < 1 || isempty(capture_name)
    capture_name = 'RefCurve_scope_aux';
end
if nargin < 2 || isempty(spb_grid)
    switch lower(capture_name)
        case 'dsm000'
            spb_grid = 99.5:0.05:100.5;
        otherwise
            spb_grid = 199.5:0.05:200.5;
    end
end
if nargin < 3 || isempty(phase_step)
    phase_step = 1;
end

cap = capture_spec(repo, capture_name);
raw = read_numeric_lines(cap.wfm_file);
csum = [0; cumsum(raw(:))];
ref_file = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
    'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', 'sim_rf_bits_01.txt');
ref = read_01_lines(ref_file);
ref_pm = 2*double(ref(:)) - 1;

rows = repmat(struct( ...
    'spb', 0, ...
    'phase', 0, ...
    'match_rate', 0, ...
    'invert', false, ...
    'start_idx', 0, ...
    'n_bits', 0), 0, 1);
best = rows;

for spb = spb_grid
    phase_grid = 0:phase_step:max(0, floor(spb)-1);
    for phase = phase_grid
        centers = round((phase + 1):spb:numel(raw));
        n = numel(centers);
        if n < 512
            continue;
        end
        if centers(1) - cap.half_win < 1 || centers(end) + cap.half_win > numel(raw)
            continue;
        end

        means = centered_means(csum, centers, cap.half_win);
        cap_pm = 2*double(means >= 0) - 1;
        [start_idx, match_rate, invert] = best_cyclic_match(cap_pm, ref_pm);

        row = struct( ...
            'spb', spb, ...
            'phase', phase, ...
            'match_rate', match_rate, ...
            'invert', invert, ...
            'start_idx', start_idx, ...
            'n_bits', n);
        rows(end+1, 1) = row; %#ok<AGROW>

        if isempty(best) || row.match_rate > best.match_rate
            best = row;
        end
    end
end

T = struct2table(rows);
T = sortrows(T, {'match_rate', 'spb', 'phase'}, {'descend', 'ascend', 'ascend'});
tag = regexprep(lower(capture_name), '[^a-z0-9]+', '_');
out_csv = fullfile(repo, sprintf('sweep_recovery_grid_%s.csv', tag));
writetable(T, out_csv);

fprintf('%s\n', repmat('=', 1, 78));
fprintf('Sweep recovery for %s\n', capture_name);
fprintf('  best match : %.6f\n', best.match_rate);
fprintf('  best spb   : %.3f\n', best.spb);
fprintf('  best phase : %.3f\n', best.phase);
fprintf('  invert     : %d\n', best.invert);
fprintf('  start idx  : %d\n', best.start_idx);
fprintf('  n_bits     : %d\n', best.n_bits);
fprintf('  output csv : %s\n', out_csv);

S = struct();
S.capture_name = capture_name;
S.best = best;
S.table = T;
S.output_csv = out_csv;
end

function cap = capture_spec(repo, capture_name)
caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'half_win', 3), ...
    struct( ...
        'name', 'RefCurve_scope_aux', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'half_win', 5) ...
];

keep = false(size(caps));
for k = 1:numel(caps)
    keep(k) = strcmpi(caps(k).name, capture_name);
end
caps = caps(keep);
assert(~isempty(caps), 'Unknown capture_name: %s', capture_name);
cap = caps(1);
end

function means = centered_means(csum, centers, half_win)
i0 = centers(:) - half_win;
i1 = centers(:) + half_win;
means = (csum(i1+1) - csum(i0)) ./ (i1 - i0 + 1);
end

function [start_idx, match_rate, invert] = best_cyclic_match(cap_pm, ref_pm)
n = numel(cap_pm);
ref_ext = [ref_pm; ref_pm(1:n-1)];
score_n = conv(ref_ext, flipud(cap_pm), 'valid');
score_n = score_n(1:numel(ref_pm));
score_i = conv(ref_ext, flipud(-cap_pm), 'valid');
score_i = score_i(1:numel(ref_pm));

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
match_rate = (peak / n + 1) / 2;
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
