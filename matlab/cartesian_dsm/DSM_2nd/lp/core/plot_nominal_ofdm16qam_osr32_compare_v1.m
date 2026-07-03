function out = plot_nominal_ofdm16qam_osr32_compare_v1(coe_i, coe_q, meta_file, xsim_dir, out_prefix)
% plot_nominal_ofdm16qam_osr32_compare_v1
% Paper-style nominal-point comparison on the current OFDM 16QAM OSR=32
% input. The figure compares:
%   DSM, EFDSM, DSM2, EFDSM2, MASH11
% MATLAB-model bars are shown for all designs; RTL markers are overlaid
% only for architectures with available native RTL dumps in the repo.

repo = lp_find_repo_root(fileparts(mfilename('fullpath')));
if nargin < 1 || isempty(coe_i)
    coe_i = fullfile(repo, 'fpga', 'data', 'coe', ...
        'I_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 2 || isempty(coe_q)
    coe_q = fullfile(repo, 'fpga', 'data', 'coe', ...
        'Q_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 3 || isempty(meta_file)
    meta_file = fullfile(repo, 'archive', 'local_runs', 'matlab_lp', 'meta', ...
        'stage1_meta_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.mat');
end
if nargin < 4 || isempty(xsim_dir)
    xsim_dir = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
        'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim');
end
if nargin < 5 || isempty(out_prefix)
    out_prefix = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', 'sim_logs', ...
        'paper_nominal_ofdm16qam_osr32_compare');
end

must_exist_file(coe_i);
must_exist_file(coe_q);
must_exist_file(meta_file);
must_exist_dir(xsim_dir);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);
S = load(meta_file);
if ~isfield(S, 'meta')
    error('meta_file must contain struct meta.');
end
meta = S.meta;

T_mat = eval_matlab_metrics(I_rom, Q_rom, meta);
T_rtl = eval_rtl_metrics(xsim_dir, I_rom, Q_rom, meta);
T_plot = build_plot_table(T_mat, T_rtl);

out_dir = fileparts(out_prefix);
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end
csv_path = [out_prefix, '.csv'];
md_path = [out_prefix, '.md'];
png_path = [out_prefix, '.png'];
pdf_path = [out_prefix, '.pdf'];

writetable(T_plot, csv_path);
write_markdown_table(T_plot, md_path);
draw_figure(T_plot, meta, png_path, pdf_path);

out = struct();
out.table = T_plot;
out.csv = csv_path;
out.md = md_path;
out.png = png_path;
out.pdf = pdf_path;

disp(T_plot);
fprintf('Saved CSV: %s\n', csv_path);
fprintf('Saved MD : %s\n', md_path);
fprintf('Saved PNG: %s\n', png_path);
fprintf('Saved PDF: %s\n', pdf_path);
end

function T = eval_matlab_metrics(I_rom, Q_rom, meta)
scale_q15 = double(2^15 - 1);
x_ref = double(I_rom(:)) / scale_q15 + 1j * double(Q_rom(:)) / scale_q15;
BWch = (max(abs(meta.active_bins)) + 1) * meta.Delta_f * 2;
adjOffset = BWch;
Ii = int64(I_rom(:));
Qi = int64(Q_rom(:));

designs = {'DSM', 'EFDSM', 'DSM2', 'EFDSM2', 'MASH11'};
rows = repmat(struct( ...
    'Design', "", ...
    'Source', "MATLAB", ...
    'MetricDomain', "", ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'ACLR_avg_dBc', NaN, ...
    'PAPR_BBrec_dB', NaN), 1, numel(designs));

for k = 1:numel(designs)
    design = designs{k};
    switch design
        case 'DSM'
            [yi, ~] = lp1_fixed_model(Ii, 32, false);
            [yq, ~] = lp1_fixed_model(Qi, 32, false);
            y_bb = double(yi(:)) + 1j * double(yq(:));
            metric_domain = "bb_sign1bit";
        case 'EFDSM'
            [yi, ~, ~] = ef1_fixed_model_with_error(Ii, 28, true);
            [yq, ~, ~] = ef1_fixed_model_with_error(Qi, 28, true);
            y_bb = double(yi(:)) + 1j * double(yq(:));
            metric_domain = "bb_sign1bit";
        case 'DSM2'
            [yi, ~] = dsm2_singleloop_fixed_model(Ii, 40, true);
            [yq, ~] = dsm2_singleloop_fixed_model(Qi, 40, true);
            y_bb = double(yi(:)) + 1j * double(yq(:));
            metric_domain = "bb_sign1bit";
        case 'EFDSM2'
            [yi, ~] = ef2_fixed_model(Ii, 28, true, int64(2), int64(-1));
            [yq, ~] = ef2_fixed_model(Qi, 28, true, int64(2), int64(-1));
            y_bb = double(yi(:)) + 1j * double(yq(:));
            metric_domain = "bb_sign1bit";
        case 'MASH11'
            [yi, ~] = mash11_fixed_model(Ii, 28, true);
            [yq, ~] = mash11_fixed_model(Qi, 28, true);
            y_bb = double(yi(:)) + 1j * double(yq(:));
            y_bb = y_bb / 3;
            metric_domain = "bb_multibit_yout";
        otherwise
            error('Unsupported design: %s', design);
    end

    [m, ac] = eval_native_metrics(y_bb, x_ref, meta, BWch, adjOffset);
    rows(k).Design = string(design);
    rows(k).Source = "MATLAB";
    rows(k).MetricDomain = metric_domain;
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
    rows(k).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
    rows(k).PAPR_BBrec_dB = m.PAPR_BBrec_dB;
end

T = struct2table(rows);
end

function T = eval_rtl_metrics(xsim_dir, I_rom, Q_rom, meta)
scale_q15 = double(2^15 - 1);
x_ref = double(I_rom(:)) / scale_q15 + 1j * double(Q_rom(:)) / scale_q15;
BWch = (max(abs(meta.active_bins)) + 1) * meta.Delta_f * 2;
adjOffset = BWch;

designs = { ...
    'DSM',     'bb_sign1bit',      'sim_bits_01.txt'; ...
    'EFDSM',   'bb_sign1bit',      'sim_bits_01_ef1.txt'; ...
    'DSM2',    'bb_sign1bit',      'sim_bits_01_dsm2.txt'; ...
    'EFDSM2',  'bb_sign1bit',      'sim_bits_01_ef2.txt'; ...
    'MASH11',  'bb_multibit_yout', 'sim_yout_signed_mash11_mb.txt' ...
};

rows = repmat(struct( ...
    'Design', "", ...
    'Source', "RTL", ...
    'MetricDomain', "", ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'ACLR_avg_dBc', NaN, ...
    'PAPR_BBrec_dB', NaN), 1, size(designs, 1));

for k = 1:size(designs, 1)
    design = string(designs{k,1});
    metric_domain = string(designs{k,2});
    dump_file = fullfile(xsim_dir, designs{k,3});
    must_exist_file(dump_file);

    [y_bb, ~] = read_native_bb_dump(dump_file, metric_domain);
    [y_bb, x_ref_now] = align_dump_to_input(y_bb, x_ref);
    [m, ac] = eval_native_metrics(y_bb, x_ref_now, meta, BWch, adjOffset);

    rows(k).Design = design;
    rows(k).Source = "RTL";
    rows(k).MetricDomain = metric_domain;
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
    rows(k).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
    rows(k).PAPR_BBrec_dB = m.PAPR_BBrec_dB;
end

T = struct2table(rows);
end

function T = build_plot_table(T_mat, T_rtl)
designs = ["DSM"; "EFDSM"; "DSM2"; "EFDSM2"; "MASH11"];
rows = repmat(struct( ...
    'Design', "", ...
    'MatlabDomain', "", ...
    'RTLDomain', "", ...
    'Matlab_EVM_percent', NaN, ...
    'RTL_EVM_percent', NaN, ...
    'AbsDelta_EVM_percent', NaN, ...
    'Matlab_SNDR_dB', NaN, ...
    'RTL_SNDR_dB', NaN, ...
    'AbsDelta_SNDR_dB', NaN), numel(designs), 1);

for k = 1:numel(designs)
    d = designs(k);
    tm = T_mat(T_mat.Design == d, :);
    tr = T_rtl(T_rtl.Design == d, :);

    rows(k).Design = d;
    if ~isempty(tm)
        rows(k).MatlabDomain = tm.MetricDomain(1);
        rows(k).Matlab_EVM_percent = tm.EVM_percent(1);
        rows(k).Matlab_SNDR_dB = tm.SNDR_dB(1);
    end
    if ~isempty(tr)
        rows(k).RTLDomain = tr.MetricDomain(1);
        rows(k).RTL_EVM_percent = tr.EVM_percent(1);
        rows(k).RTL_SNDR_dB = tr.SNDR_dB(1);
        rows(k).AbsDelta_EVM_percent = abs(rows(k).Matlab_EVM_percent - rows(k).RTL_EVM_percent);
        rows(k).AbsDelta_SNDR_dB = abs(rows(k).Matlab_SNDR_dB - rows(k).RTL_SNDR_dB);
    else
        rows(k).RTLDomain = "N/A";
    end
end

T = struct2table(rows);
end

function draw_figure(T, meta, png_path, pdf_path)
display_names = categorical({'DSM1','EF1','DSM2','EF2','MASH1-1'});
display_names = reordercats(display_names, {'DSM1','EF1','DSM2','EF2','MASH1-1'});
x = 1:height(T);
matlab_color = [0.00 0.32 0.64];
rtl_color = [0.84 0.37 0.00];

f = figure('Color', 'w', 'Position', [120 100 900 760]);
tl = tiledlayout(2, 1, 'TileSpacing', 'compact', 'Padding', 'compact');

ax1 = nexttile;
Y_evm = [T.Matlab_EVM_percent, T.RTL_EVM_percent];
b1 = bar(ax1, Y_evm, 'grouped', 'BarWidth', 0.72);
b1(1).FaceColor = matlab_color;
b1(1).EdgeColor = 'none';
b1(2).FaceColor = rtl_color;
b1(2).EdgeColor = 'none';
style_axis(ax1);
ax1.XTick = x;
ax1.XTickLabel = cellstr(display_names);
ylim(ax1, [0 5.5]);
yline(ax1, 1.0, '--', 'Color', [0.70 0.70 0.70], 'LineWidth', 0.9);
ylabel(ax1, 'EVM (%)', 'FontName', 'Arial', 'FontSize', 13);
title(ax1, '(a) EVM', 'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
add_bar_labels(ax1, b1, '%.2f', 0.08);
add_rtl_na(ax1, b1(2), T.RTL_EVM_percent, 0.18);

ax2 = nexttile;
Y_sndr = [T.Matlab_SNDR_dB, T.RTL_SNDR_dB];
b2 = bar(ax2, Y_sndr, 'grouped', 'BarWidth', 0.72);
b2(1).FaceColor = matlab_color;
b2(1).EdgeColor = 'none';
b2(2).FaceColor = rtl_color;
b2(2).EdgeColor = 'none';
style_axis(ax2);
ax2.XTick = x;
ax2.XTickLabel = cellstr(display_names);
ylim(ax2, [0 62]);
yticks(ax2, 0:10:60);
ylabel(ax2, 'SNDR (dB)', 'FontName', 'Arial', 'FontSize', 13);
xlabel(ax2, 'Architecture', 'FontName', 'Arial', 'FontSize', 13);
title(ax2, '(b) SNDR', 'FontName', 'Arial', 'FontSize', 13, 'FontWeight', 'bold');
add_bar_labels(ax2, b2, '%.1f', 0.6);
add_rtl_na(ax2, b2(2), T.RTL_SNDR_dB, 2.2);

lgd = legend(ax1, [b1(1), b1(2)], {'MATLAB', 'RTL'}, ...
    'Orientation', 'horizontal', 'Box', 'off', ...
    'FontName', 'Arial', 'FontSize', 11);
lgd.Layout.Tile = 'north';

exportgraphics(f, png_path, 'Resolution', 400);
exportgraphics(f, pdf_path, 'ContentType', 'vector');
close(f);
end

function style_axis(ax)
ax.Box = 'off';
ax.LineWidth = 1.0;
ax.FontName = 'Arial';
ax.FontSize = 12;
ax.YGrid = 'on';
ax.XGrid = 'off';
ax.GridAlpha = 0.16;
ax.MinorGridAlpha = 0.10;
ax.Layer = 'top';
end

function add_bar_labels(ax, bh, fmt, dy)
for i = 1:numel(bh)
    x = bh(i).XEndPoints;
    y = bh(i).YEndPoints;
    for k = 1:numel(x)
        if ~isnan(y(k))
            text(ax, x(k), y(k) + dy, sprintf(fmt, y(k)), ...
                'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
                'FontName', 'Arial', 'FontSize', 9, 'Color', [0.12 0.12 0.12]);
        end
    end
end
end

function add_rtl_na(ax, bh, yv, y_text)
x = bh.XEndPoints;
for k = 1:numel(yv)
    if isnan(yv(k))
        text(ax, x(k), y_text, 'N/A', ...
            'HorizontalAlignment', 'center', 'VerticalAlignment', 'bottom', ...
            'FontName', 'Arial', 'FontSize', 8.5, 'Color', [0.45 0.45 0.45], ...
            'Rotation', 90);
    end
end
end

function [m, ac] = eval_native_metrics(y_bb, x_ref, meta, BWch, adjOffset)
recCfg = struct( ...
    'OSR', meta.OSR, ...
    'Fs_dsm', meta.Fs_dsm, ...
    'Fs_bb', meta.Fs_bb, ...
    'BWch', BWch, ...
    'StopAtt', 80, ...
    'UseFastFir', false, ...
    'ZeroPhase', false);
    [y_rec, x_ref_bb] = lp_reconstruct_and_decimate(y_bb, x_ref, recCfg);
    al = lp_align_and_ls_gain(y_rec, x_ref_bb);
    [y_al, x_al] = lp_discard_settle_pair(al.y_aligned, al.x_aligned, 64);
    m = lp_calc_sndr_evm(y_al, x_al);
    m.PAPR_BBrec_dB = calc_papr_db(y_al);

    psdCfg = default_psd_cfg(numel(y_bb));
    ac = lp_calc_acpr_aclr_from_psd(y_bb, meta.Fs_dsm, BWch, adjOffset, psdCfg);
end

function [y_bb, scale_used] = read_native_bb_dump(fp, metric_domain)
M = readmatrix(fp, 'FileType', 'text');
if isempty(M) || all(isnan(M(:)))
    fid = fopen(fp, 'r');
    if fid < 0
        error('Cannot open %s', fp);
    end
    c = textscan(fid, '%f %f', 'Delimiter', {' ', sprintf('\t'), ','}, ...
        'MultipleDelimsAsOne', true);
    fclose(fid);
    M = [c{1}, c{2}];
end

switch lower(char(metric_domain))
    case 'bb_sign1bit'
        M = round(M(:, 1:2));
        yi = 2 * M(:,1) - 1;
        yq = 2 * M(:,2) - 1;
        y_bb = yi + 1j * yq;
        scale_used = 1;
    case 'bb_multibit_yout'
        M = round(M(:, 1:2));
        yi = double(M(:,1));
        yq = double(M(:,2));
        scale_used = max(1, max(abs([yi; yq])));
        y_bb = (yi + 1j * yq) / scale_used;
    otherwise
        error('Unsupported metric domain: %s', metric_domain);
end
end

function [y_aligned, x_aligned] = align_dump_to_input(y_bb, x_ref)
y_bb = y_bb(:);
x_ref = x_ref(:);
if numel(y_bb) > 1 && numel(x_ref) > 1
    y_bb = y_bb(2:end);
    x_ref = x_ref(1:end-1);
end
N = min(numel(y_bb), numel(x_ref));
y_aligned = y_bb(1:N);
x_aligned = x_ref(1:N);
end

function [y_pm, dbg] = lp1_fixed_model(x_i64, acc_w, saturate)
N = numel(x_i64);
y_pm = zeros(N, 1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
v = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;
for n = 1:N
    if v >= 0
        q = fs;
        y_pm(n) = 1;
    else
        q = -fs;
        y_pm(n) = -1;
    end
    y_raw = v + int64(x_i64(n)) - q;
    if (y_raw > acc_max) || (y_raw < acc_min)
        ov = ov + 1;
    end
    v = sat_or_wrap(y_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if v == acc_max && y_raw > acc_max, sat_hi = sat_hi + 1; end
    if v == acc_min && y_raw < acc_min, sat_lo = sat_lo + 1; end
    vpk = max(vpk, abs(double(v)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_pm, e_hist, dbg] = ef1_fixed_model_with_error(x_i64, acc_w, saturate, dither_i64)
N = numel(x_i64);
y_pm = zeros(N,1);
e_hist = int64(zeros(N,1));
if nargin < 4 || isempty(dither_i64)
    dither_i64 = int64(zeros(N,1));
else
    dither_i64 = int64(dither_i64(:));
end
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
e1 = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;
for n = 1:N
    y_raw = int64(x_i64(n)) + dither_i64(min(n, numel(dither_i64))) + e1;
    if (y_raw > acc_max) || (y_raw < acc_min)
        ov = ov + 1;
    end
    y = sat_or_wrap(y_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if y == acc_max && y_raw > acc_max, sat_hi = sat_hi + 1; end
    if y == acc_min && y_raw < acc_min, sat_lo = sat_lo + 1; end
    if y >= 0
        q = fs;
        y_pm(n) = 1;
    else
        q = -fs;
        y_pm(n) = -1;
    end
    e1 = y - q;
    e_hist(n) = e1;
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_pm, dbg] = dsm2_singleloop_fixed_model(x_i64, acc_w, saturate)
N = numel(x_i64);
y_pm = zeros(N, 1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
v1 = int64(0);
v2 = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk1 = 0;
vpk2 = 0;
for n = 1:N
    if v2 >= 0
        q = fs;
        y_pm(n) = 1;
    else
        q = -fs;
        y_pm(n) = -1;
    end

    v1_raw = v1 + int64(x_i64(n)) - q;
    if (v1_raw > acc_max) || (v1_raw < acc_min)
        ov = ov + 1;
    end
    v1 = sat_or_wrap(v1_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if v1 == acc_max && v1_raw > acc_max, sat_hi = sat_hi + 1; end
    if v1 == acc_min && v1_raw < acc_min, sat_lo = sat_lo + 1; end

    v2_raw = v2 + v1 - q;
    if (v2_raw > acc_max) || (v2_raw < acc_min)
        ov = ov + 1;
    end
    v2 = sat_or_wrap(v2_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if v2 == acc_max && v2_raw > acc_max, sat_hi = sat_hi + 1; end
    if v2 == acc_min && v2_raw < acc_min, sat_lo = sat_lo + 1; end

    vpk1 = max(vpk1, abs(double(v1)));
    vpk2 = max(vpk2, abs(double(v2)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk1', vpk1, 'vpk2', vpk2);
end

function [y_pm, dbg] = ef2_fixed_model(x_i64, acc_w, saturate, b1, b2)
N = numel(x_i64);
y_pm = zeros(N,1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
e1 = int64(0);
e2 = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;
for n = 1:N
    y_raw = int64(x_i64(n)) + b1 * e1 + b2 * e2;
    if (y_raw > acc_max) || (y_raw < acc_min)
        ov = ov + 1;
    end
    y = sat_or_wrap(y_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if y == acc_max && y_raw > acc_max, sat_hi = sat_hi + 1; end
    if y == acc_min && y_raw < acc_min, sat_lo = sat_lo + 1; end
    if y >= 0
        q = fs;
        y_pm(n) = 1;
    else
        q = -fs;
        y_pm(n) = -1;
    end
    e0 = y - q;
    e2 = e1;
    e1 = e0;
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_mash, dbg] = mash11_fixed_model(x_i64, acc_w, saturate)
[y1_pm, e1, d1] = ef1_fixed_model_with_error(x_i64, acc_w, saturate);
[y2_pm, ~, d2] = ef1_fixed_model_with_error(e1, acc_w, saturate);
N = numel(x_i64);
y_mash = zeros(N,1);
y2_prev = 0;
for n = 1:N
    y_mash(n) = y1_pm(n) + y2_pm(n) - y2_prev;
    y2_prev = y2_pm(n);
end
dbg = struct('ov_count', d1.ov_count + d2.ov_count, ...
    'sat_hi', d1.sat_hi + d2.sat_hi, ...
    'sat_lo', d1.sat_lo + d2.sat_lo, ...
    'vpk1', d1.vpk, 'vpk2', d2.vpk);
end

function y = sat_or_wrap(y_raw, acc_w, saturate, acc_rng, acc_min, acc_max)
if saturate
    y = y_raw;
    if y > acc_max, y = acc_max; end
    if y < acc_min, y = acc_min; end
else
    y = mod(y_raw - acc_min, acc_rng) + acc_min;
    y = wrap_to_width(y, acc_w);
end
end

function y = wrap_to_width(v, w)
v = int64(v);
acc_min = int64(-2^(w-1));
modv = int64(2^w);
y = mod(v - acc_min, modv) + acc_min;
end

function cfg = default_psd_cfg(N)
cfg.winLen = 2^floor(log2(min(4096, N)));
cfg.winLen = max(cfg.winLen, 256);
cfg.winLen = min(cfg.winLen, N);
cfg.overlap = floor(cfg.winLen / 2);
cfg.nfft = max(8192, 4 * cfg.winLen);
cfg.window = hamming(cfg.winLen);
end

function v = calc_papr_db(x)
x = double(x(:));
if isempty(x)
    v = NaN;
    return;
end
v = 20 * log10(max(abs(x)) / (rms(abs(x)) + eps));
end

function write_markdown_table(T, out_md)
fid = fopen(out_md, 'w');
if fid < 0
    error('Cannot write %s', out_md);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '| Design | Matlab Domain | RTL Domain | Matlab EVM (%%) | RTL EVM (%%) | |dEVM| | Matlab SNDR (dB) | RTL SNDR (dB) | |dSNDR| |\n');
fprintf(fid, '|---|---|---|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %s | %s | %.4f | %s | %s | %.4f | %s | %s |\n', ...
        T.Design(k), T.MatlabDomain(k), T.RTLDomain(k), T.Matlab_EVM_percent(k), ...
        fmt_nan(T.RTL_EVM_percent(k)), fmt_nan(T.AbsDelta_EVM_percent(k)), ...
        T.Matlab_SNDR_dB(k), fmt_nan(T.RTL_SNDR_dB(k)), fmt_nan(T.AbsDelta_SNDR_dB(k)));
end
end

function s = fmt_nan(v)
if isnan(v)
    s = 'N/A';
else
    s = sprintf('%.4f', v);
end
end

function must_exist_file(p)
if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
end
end

function must_exist_dir(p)
if exist(p, 'dir') ~= 7
    error('Missing directory: %s', p);
end
end
