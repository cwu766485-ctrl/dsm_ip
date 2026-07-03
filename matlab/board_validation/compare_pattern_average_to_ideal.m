function compare_pattern_average_to_ideal()
% compare_pattern_average_to_ideal
% Compare averaged analog snippets from the captures against ideal square
% waves built from the same bit patterns.

patterns = {
    '1001100111'
    '011100100'
};

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');

caps = [ ...
    struct( ...
        'name', 'DSM000', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'), ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000_recovered_bits_01.txt'), ...
        'spb', 100, ...
        'phase', 64, ...
        'dt', 100e-12), ...
    struct( ...
        'name', 'RefCurve', ...
        'wfm_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux.Wfm.csv'), ...
        'bits_file', fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'RefCurve_scope_aux_recovered_bits_01.txt'), ...
        'spb', 200, ...
        'phase', 175, ...
        'dt', 50e-12) ...
];

rows = {};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 800]);
tiledlayout(numel(patterns), numel(caps), 'TileSpacing', 'compact', 'Padding', 'compact');

for c = 1:numel(caps)
    raw = read_numeric_lines(caps(c).wfm_file);
    bits = read_01_lines(caps(c).bits_file);
    centers = (caps(c).phase + 1) + (0:numel(bits)-1) * caps(c).spb;

    for p = 1:numel(patterns)
        pat = patterns{p};
        idx = find_pattern(bits, pat);
        [avg_wave, t_ns, n_occ] = average_snippets(raw, centers, caps(c).spb, caps(c).dt, idx, strlength(pat));

        nexttile;
        if isempty(avg_wave)
            text(0.5, 0.5, sprintf('%s | %s | n = 0', caps(c).name, pat), ...
                'HorizontalAlignment', 'center');
            axis off;
            continue;
        end

        ideal_pm = 2 * (pat(:) == '1') - 1;
        ideal = repelem(double(ideal_pm), caps(c).spb);
        X = [ideal, ones(size(ideal))];
        ab = X \ avg_wave;
        fit_wave = X * ab;

        full_corr = simple_corr(avg_wave, fit_wave);
        full_rmse = sqrt(mean((avg_wave - fit_wave).^2));

        plat_mask = false(size(ideal));
        for k = 1:strlength(pat)
            i0 = (k-1) * caps(c).spb + floor(0.2 * caps(c).spb) + 1;
            i1 = (k-1) * caps(c).spb + floor(0.8 * caps(c).spb);
            plat_mask(i0:i1) = true;
        end
        plat_corr = simple_corr(avg_wave(plat_mask), fit_wave(plat_mask));
        plat_rmse = sqrt(mean((avg_wave(plat_mask) - fit_wave(plat_mask)).^2));

        plot(t_ns, avg_wave, 'LineWidth', 1.1, 'Color', [0.05 0.35 0.80]);
        hold on;
        plot(t_ns, fit_wave, '--', 'LineWidth', 1.0, 'Color', [0.85 0.20 0.10]);
        for b = 0:strlength(pat)
            xline(b * caps(c).spb * caps(c).dt * 1e9, ':', 'Color', [0.7 0.7 0.7]);
        end
        grid on;
        xlabel('Time (ns)');
        ylabel('Voltage (V)');
        title(sprintf('%s | %s | n=%d | plat corr=%.4f', ...
            caps(c).name, pat, n_occ, plat_corr), 'Interpreter', 'none');
        legend({'avg analog', 'fitted ideal'}, 'Location', 'best');

        rows(end+1, :) = { ...
            caps(c).name, pat, n_occ, ab(1), ab(2), ...
            full_corr, full_rmse, plat_corr, plat_rmse}; %#ok<AGROW>
    end
end

sgtitle('Averaged Analog Pattern vs Fitted Ideal Square Wave');
exportgraphics(fig, fullfile(repo, 'pattern_average_vs_ideal.png'), 'Resolution', 160);
close(fig);

T = cell2table(rows, 'VariableNames', { ...
    'capture', 'pattern', 'occurrences', 'scale_a', 'offset_b', ...
    'full_corr', 'full_rmse_v', 'platform_corr', 'platform_rmse_v'});
writetable(T, fullfile(repo, 'pattern_average_vs_ideal.csv'));
disp(T);
end

function idx = find_pattern(bits, pat)
s = char(bits(:).' + '0');
pat = char(pat);
idx = [];
start = 1;
while true
    k = strfind(s(start:end), pat); %#ok<STREMP>
    if isempty(k)
        break;
    end
    hit = start + k(1) - 1;
    idx(end+1, 1) = hit; %#ok<AGROW>
    start = hit + 1;
end
end

function [avg_wave, t_ns, counts] = average_snippets(raw, centers, spb, dt, idx, n_bits)
counts = 0;
avg_wave = [];
t_ns = [];
if isempty(idx)
    return;
end

pre_samp = floor(spb / 2);
seg_len = n_bits * spb;
acc = zeros(seg_len, 1);
valid = 0;

for n = 1:numel(idx)
    bit0 = idx(n);
    c0 = centers(bit0);
    seg_start = round(c0 - pre_samp);
    seg_end = seg_start + seg_len - 1;
    if seg_start < 1 || seg_end > numel(raw)
        continue;
    end
    seg = raw(seg_start:seg_end);
    acc = acc + seg;
    valid = valid + 1;
end

if valid == 0
    return;
end

avg_wave = acc / valid;
t_ns = (0:seg_len-1).' * dt * 1e9;
counts = valid;
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
    x = str2double(s);
    if ~isnan(x)
        bits(end+1, 1) = x ~= 0; %#ok<AGROW>
    end
end
end

function r = simple_corr(x, y)
x = x(:);
y = y(:);
x = x - mean(x);
y = y - mean(y);
den = sqrt(sum(x.^2) * sum(y.^2));
if den == 0
    r = NaN;
else
    r = sum(x .* y) / den;
end
end
