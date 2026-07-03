function plot_dsm000_scope_vs_rtl_single()
% plot_dsm000_scope_vs_rtl_single
% Export a clean single-panel DSM000 scope-vs-RTL spectrum figure.

repo = fullfile(fileparts(mfilename('fullpath')), '..', '..');
ref_file = resolve_reference_bits_file(repo, 'sim_rf_bits_01.txt');
raw_file = fullfile(repo, 'data', 'board_validation', 'cartesian_dsm', 'DSM000.Wfm.csv');

dt = 100e-12;
spb = 100;
ref_start = 50871;
invert = false;

ref_bits = read_01_lines(ref_file);
raw = read_numeric_lines(raw_file);
n_bits = floor(numel(raw) / spb);
raw = raw(1:n_bits * spb);
ref_seg = cyclic_take(ref_bits, ref_start, n_bits);
if invert
    ref_seg = ~ref_seg;
end
y_ref = bits_to_analog(ref_seg, raw, spb);

[f_mhz, p_raw] = simple_psd(raw, dt);
[~, p_ref] = simple_psd(y_ref, dt);
keep = f_mhz <= min(500, f_mhz(end));
f_plot = f_mhz(keep);
raw_db = norm_db(p_raw(keep));
ref_db = norm_db(p_ref(keep));
raw_db_s = smooth_spectrum_db(raw_db, f_plot, 4.0);
ref_db_s = smooth_spectrum_db(ref_db, f_plot, 4.0);
raw_corr = simple_corr(raw_db, ref_db);

fig = figure('Visible', 'off', 'Color', 'w', 'Position', [120 120 980 560]);
plot(f_plot, raw_db, 'LineWidth', 0.25, 'Color', [0.82 0.88 0.97]);
hold on;
plot(f_plot, ref_db, '--', 'LineWidth', 0.25, 'Color', [0.82 0.94 0.82]);
plot(f_plot, raw_db_s, 'LineWidth', 2.2, 'Color', [0.05 0.35 0.80]);
plot(f_plot, ref_db_s, '--', 'LineWidth', 2.2, 'Color', [0.10 0.60 0.20]);
grid on;
xlabel('Frequency (MHz)');
ylabel('PSD (dB, normalized)');
title(sprintf('DSM000: scope vs RTL spectrum | raw corr = %.4f', raw_corr), 'Interpreter', 'none');
legend({'scope raw', 'RTL raw', 'scope envelope', 'RTL envelope'}, 'Location', 'best');
xlim([0 500]);
exportgraphics(fig, fullfile(repo, 'dsm000_scope_vs_rtl_single.png'), 'Resolution', 180);
close(fig);
end

function y = bits_to_analog(bits, raw, spb)
raw_hi = mean(raw(raw >= quantile_local(raw, 0.9)));
raw_lo = mean(raw(raw <= quantile_local(raw, 0.1)));
pm = 2 * double(bits(:)) - 1;
y = repelem(pm, spb, 1);
y = (raw_hi - raw_lo) / 2 * y + (raw_hi + raw_lo) / 2;
target_len = floor(numel(raw) / spb) * spb;
y = y(1:min(target_len, numel(y)));
if numel(y) < target_len
    y(end+1:target_len, 1) = y(end);
end
end

function [f_mhz, p] = simple_psd(x, dt)
x = x(:);
x = x - mean(x);
n = numel(x);
w = hann_local(n);
xw = x .* w;
X = fft(xw);
P2 = abs(X).^2 / max(1, sum(w.^2));
n1 = floor(n / 2) + 1;
p = P2(1:n1);
f = (0:n1-1).' / (n * dt);
f_mhz = f / 1e6;
end

function y = norm_db(x)
y = 10 * log10(max(x, 1e-30));
y = y - max(y);
end

function y = smooth_spectrum_db(x, f_mhz, win_mhz)
x = x(:);
f_mhz = f_mhz(:);
if numel(x) <= 2
    y = x;
    return;
end
df = median(diff(f_mhz));
half_span = max(1, round(0.5 * win_mhz / max(df, eps)));
kernel = ones(2 * half_span + 1, 1);
kernel = kernel / sum(kernel);
y = conv(x, kernel, 'same');
end

function q = quantile_local(x, alpha)
x = sort(x(:));
n = numel(x);
idx = max(1, min(n, round(alpha * (n - 1) + 1)));
q = x(idx);
end

function w = hann_local(n)
if n == 1
    w = 1;
else
    k = (0:n-1).';
    w = 0.5 - 0.5 * cos(2 * pi * k / (n - 1));
end
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function r = simple_corr(x, y)
x = x(:) - mean(x);
y = y(:) - mean(y);
den = sqrt(sum(x.^2) * sum(y.^2));
if den == 0
    r = NaN;
else
    r = sum(x .* y) / den;
end
end

function raw = read_numeric_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
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
c = onCleanup(@() fclose(fid)); %#ok<NASGU>
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
