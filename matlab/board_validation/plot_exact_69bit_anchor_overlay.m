function plot_exact_69bit_anchor_overlay()
% plot_exact_69bit_anchor_overlay
% Plot the raw DSM000 analog waveform around the strongest exact-match
% 69-bit anchor and overlay the ideal square wave of the same bit string.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
raw = read_numeric_lines(fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv'));
seq = '000110111011100100011011000110010011001100110011000110010011001110011';
cap_start = 21600;
spb = 100;
phase = 64;
dt = 100e-12;

center0 = (phase + 1) + (cap_start - 1) * spb;
seg_start = round(center0 - spb / 2);
seg_len = numel(seq) * spb;
seg_end = seg_start + seg_len - 1;

raw_seg = raw(seg_start:seg_end);
hi = mean(raw(raw >= quantile_local(raw, 0.9)));
lo = mean(raw(raw <= quantile_local(raw, 0.1)));
pm = 2 * (seq(:) == '1') - 1;
ideal = repelem(double(pm), spb, 1);
ideal = (hi - lo) / 2 * ideal + (hi + lo) / 2;
t_ns = (0:seg_len-1).' * dt * 1e9;

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [100 100 1250 500]);
plot(t_ns, raw_seg, 'LineWidth', 1.0, 'Color', [0.05 0.35 0.80]);
hold on;
plot(t_ns, ideal, '--', 'LineWidth', 1.0, 'Color', [0.85 0.20 0.10]);
for b = 0:numel(seq)
    xline(b * spb * dt * 1e9, ':', 'Color', [0.75 0.75 0.75]);
end
grid on;
xlabel('Time (ns)');
ylabel('Voltage (V)');
title(sprintf('DSM000 exact 69-bit anchor overlay | cap start = %d', cap_start), 'Interpreter', 'none');
legend({'scope raw', 'RTL/recovered ideal'}, 'Location', 'best');

annotation_text = sprintf(['69-bit exact anchor found in DSM000 recovered bits and RTL rf_bits only.\n', ...
    'Sequence length = 69 bits, window length = %.1f ns'], numel(seq) * spb * dt * 1e9);
text(0.01 * max(t_ns), max(raw_seg) - 0.1, annotation_text, ...
    'VerticalAlignment', 'top', 'BackgroundColor', 'w');

exportgraphics(fig, fullfile(repo, 'dsm000_exact_69bit_anchor_overlay.png'), 'Resolution', 180);
close(fig);
end

function q = quantile_local(x, alpha)
x = sort(x(:));
n = numel(x);
idx = max(1, min(n, round(alpha * (n - 1) + 1)));
q = x(idx);
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
