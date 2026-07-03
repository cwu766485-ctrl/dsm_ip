function analyze_pattern_analog_means()
% analyze_pattern_analog_means
% Compare averaged analog snippets and platform means for common recovered
% bit patterns in the two scope waveform exports.

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

platform_rows = {};
global_rows = {};
fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1200 800]);
tiledlayout(numel(patterns), numel(caps), 'TileSpacing', 'compact', 'Padding', 'compact');

for c = 1:numel(caps)
    raw = read_numeric_lines(caps(c).wfm_file);
    bits = read_01_lines(caps(c).bits_file);
    centers = (caps(c).phase + 1) + (0:numel(bits)-1) * caps(c).spb;

    [one_mean, zero_mean, one_std, zero_std] = global_platform_stats(raw, bits, centers, caps(c).spb);
    global_rows(end+1, :) = {caps(c).name, one_mean, zero_mean, one_std, zero_std, one_mean - zero_mean}; %#ok<AGROW>

    for p = 1:numel(patterns)
        pat = patterns{p};
        idx = find_pattern(bits, pat);
        [avg_wave, t_ns, bit_means, counts] = average_snippets(raw, centers, caps(c).spb, caps(c).dt, idx, strlength(pat));

        nexttile;
        if ~isempty(avg_wave)
            plot(t_ns, avg_wave, 'LineWidth', 1.1, 'Color', [0.05 0.35 0.80]);
            hold on;
            yl = ylim;
            for b = 0:strlength(pat)
                xline(b * caps(c).spb * caps(c).dt * 1e9, ':', 'Color', [0.6 0.6 0.6]);
            end
            ylim(yl);
            grid on;
            xlabel('Time (ns)');
            ylabel('Voltage (V)');
            title(sprintf('%s | %s | n = %d', caps(c).name, pat, counts), 'Interpreter', 'none');
        else
            text(0.5, 0.5, sprintf('%s | %s | n = 0', caps(c).name, pat), ...
                'HorizontalAlignment', 'center');
            axis off;
        end

        if counts > 0
            bit_chars = char(pat);
            for k = 1:numel(bit_means)
                platform_rows(end+1, :) = {caps(c).name, pat, k, bit_chars(k), bit_means(k), counts}; %#ok<AGROW>
            end
        end
    end
end

sgtitle('Averaged Analog Snippets for Common Recovered Bit Patterns');
exportgraphics(fig, fullfile(repo, 'pattern_analog_means.png'), 'Resolution', 160);
close(fig);

Tg = cell2table(global_rows, 'VariableNames', ...
    {'capture', 'one_mean_v', 'zero_mean_v', 'one_std_v', 'zero_std_v', 'swing_v'});
writetable(Tg, fullfile(repo, 'global_platform_means.csv'));

Tp = cell2table(platform_rows, 'VariableNames', ...
    {'capture', 'pattern', 'bit_pos', 'bit_value', 'platform_mean_v', 'occurrences'});
writetable(Tp, fullfile(repo, 'pattern_platform_means.csv'));

disp(Tg);
disp(Tp(1:min(height(Tp), 20), :));
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

function [avg_wave, t_ns, bit_means, counts] = average_snippets(raw, centers, spb, dt, idx, n_bits)
counts = 0;
bit_means = [];
avg_wave = [];
t_ns = [];
if isempty(idx)
    return;
end

pre_samp = floor(spb / 2);
post_samp = ceil(spb / 2) - 1;
seg_len = n_bits * spb;
acc = zeros(seg_len, 1);
bit_acc = zeros(n_bits, 1);
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

    for k = 1:n_bits
        b_start = seg_start + (k-1) * spb;
        p0 = round(b_start + 0.2 * spb);
        p1 = round(b_start + 0.8 * spb) - 1;
        p0 = max(p0, seg_start);
        p1 = min(p1, seg_end);
        bit_acc(k) = bit_acc(k) + mean(raw(p0:p1));
    end
end

if valid == 0
    return;
end

avg_wave = acc / valid;
bit_means = bit_acc / valid;
t_ns = (0:seg_len-1).' * dt * 1e9;
counts = valid;
end

function [one_mean, zero_mean, one_std, zero_std] = global_platform_stats(raw, bits, centers, spb)
vals1 = zeros(0, 1);
vals0 = zeros(0, 1);
for k = 1:numel(bits)
    c = centers(k);
    b_start = round(c - spb / 2);
    p0 = round(b_start + 0.2 * spb);
    p1 = round(b_start + 0.8 * spb) - 1;
    p0 = max(p0, 1);
    p1 = min(p1, numel(raw));
    if p1 < p0
        continue;
    end
    m = mean(raw(p0:p1));
    if bits(k)
        vals1(end+1, 1) = m; %#ok<AGROW>
    else
        vals0(end+1, 1) = m; %#ok<AGROW>
    end
end
one_mean = mean(vals1);
zero_mean = mean(vals0);
one_std = std(vals1);
zero_std = std(vals0);
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
