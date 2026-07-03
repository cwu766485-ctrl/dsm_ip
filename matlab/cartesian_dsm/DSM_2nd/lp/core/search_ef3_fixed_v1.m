function out = search_ef3_fixed_v1(A_list, b1_list, b2_list, b3_list, coe_i, coe_q, meta_file, out_prefix)
% search_ef3_fixed_v1
% Sweep a simple 3rd-order error-feedback DSM:
%   y[n] = x[n] + b1*e[n-1] + b2*e[n-2] + b3*e[n-3]
% and report native-domain BB metrics on the nominal OFDM/QAM dataset.

repo = lp_find_repo_root(fileparts(mfilename('fullpath')));
if nargin < 5 || isempty(coe_i)
    coe_i = fullfile(repo, 'fpga', 'data', 'coe', ...
        'I_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 6 || isempty(coe_q)
    coe_q = fullfile(repo, 'fpga', 'data', 'coe', ...
        'Q_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 7 || isempty(meta_file)
    meta_file = fullfile(repo, 'archive', 'local_runs', 'matlab_lp', 'meta', ...
        'stage1_meta_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.mat');
end
if nargin < 8 || isempty(out_prefix)
    out_prefix = fullfile(repo, 'matlab', 'cartesian_dsm', 'DSM_2nd', 'lp', 'core', ...
        'results', 'search_ef3_fixed_v1');
end

must_exist_file(coe_i);
must_exist_file(coe_q);
must_exist_file(meta_file);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);

S = load(meta_file);
meta = normalize_meta_from_file(S);
A_nom = double(meta.A);

if nargin < 1 || isempty(A_list)
    A_list = 0.08:0.02:0.32;
end
if nargin < 2 || isempty(b1_list)
    b1_list = 2:4;
end
if nargin < 3 || isempty(b2_list)
    b2_list = -4:-1;
end
if nargin < 4 || isempty(b3_list)
    b3_list = 0:2;
end

A_list = unique(sort([double(A_list(:)).', A_nom]));
b1_list = unique(int64(b1_list(:).'));
b2_list = unique(int64(b2_list(:).'));
b3_list = unique(int64(b3_list(:).'));

BWch = (max(abs(meta.active_bins)) + 1) * meta.Delta_f * 2;
adjOffset = BWch;
scale_q15 = double(2^15 - 1);

rows = struct([]);
row_idx = 0;

for ai = 1:numel(A_list)
    A_now = double(A_list(ai));
    [Ii, Qi, clip_count] = scale_nominal_iq(I_rom, Q_rom, A_now, A_nom);
    x_ref = double(Ii(:)) / scale_q15 + 1j * double(Qi(:)) / scale_q15;

    for i1 = 1:numel(b1_list)
        for i2 = 1:numel(b2_list)
            for i3 = 1:numel(b3_list)
                b1 = b1_list(i1);
                b2 = b2_list(i2);
                b3 = b3_list(i3);

                [yi, di] = ef3_fixed_model(int64(Ii), 28, true, b1, b2, b3);
                [yq, dq] = ef3_fixed_model(int64(Qi), 28, true, b1, b2, b3);
                y_bb = double(yi(:)) + 1j * double(yq(:));
                dbg = merge_dbg(di, dq);

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

                psdCfg = default_psd_cfg(numel(y_bb));
                ac = lp_calc_acpr_aclr_from_psd(y_bb, meta.Fs_dsm, BWch, adjOffset, psdCfg);

                row_idx = row_idx + 1;
                rows(row_idx).A = A_now;
                rows(row_idx).b1 = double(b1);
                rows(row_idx).b2 = double(b2);
                rows(row_idx).b3 = double(b3);
                rows(row_idx).clip_count = double(clip_count);
                rows(row_idx).ov_count = double(dbg.ov_count);
                rows(row_idx).sat_hi = double(dbg.sat_hi);
                rows(row_idx).sat_lo = double(dbg.sat_lo);
                rows(row_idx).vpk = double(dbg.vpk);
                rows(row_idx).EVM_percent = m.EVM_rms_percent;
                rows(row_idx).SNDR_dB = m.SNDR_dB;
                rows(row_idx).PAPR_BBrec_dB = calc_papr_db(y_al);
                rows(row_idx).ACLR_L_dBc = ac.ACPR_L_dBc;
                rows(row_idx).ACLR_R_dBc = ac.ACPR_R_dBc;
                rows(row_idx).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
            end
        end
    end
end

T = struct2table(rows);
T = sortrows(T, {'EVM_percent','SNDR_dB'}, {'ascend','descend'});
zero_ov = T(T.ov_count == 0 & T.clip_count == 0, :);
if ~isempty(zero_ov)
    Tbest = zero_ov(1,:);
else
    Tbest = T(1,:);
end

stamp = datestr(now, 'yyyymmdd_HHMMSS');
csv_path = out_prefix + "_" + stamp + ".csv";
md_path  = out_prefix + "_" + stamp + ".md";
mat_path = out_prefix + "_" + stamp + ".mat";

writetable(T, csv_path);
save(mat_path, 'T', 'Tbest');
write_markdown(Tbest, T, md_path);

out = struct();
out.T = T;
out.Tbest = Tbest;
out.csv_path = csv_path;
out.md_path = md_path;
out.mat_path = mat_path;

disp(Tbest);
fprintf('Saved CSV: %s\\n', csv_path);
fprintf('Saved MD : %s\\n', md_path);
fprintf('Saved MAT: %s\\n', mat_path);
end

function [y_pm, dbg] = ef3_fixed_model(x_i64, acc_w, saturate, b1, b2, b3)
N = numel(x_i64);
y_pm = zeros(N,1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
e1 = int64(0);
e2 = int64(0);
e3 = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;
for n = 1:N
    y_raw = int64(x_i64(n)) + b1*e1 + b2*e2 + b3*e3;
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
    e3 = e2;
    e2 = e1;
    e1 = y - q;
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [Ii, Qi, clip_count] = scale_nominal_iq(I_rom, Q_rom, A_now, A_nom)
scale = A_now / A_nom;
I_scaled = round(double(I_rom) * scale);
Q_scaled = round(double(Q_rom) * scale);
I_scaled = max(min(I_scaled, double(intmax('int16'))), double(intmin('int16')));
Q_scaled = max(min(Q_scaled, double(intmax('int16'))), double(intmin('int16')));
clip_count = nnz(I_scaled ~= round(double(I_rom) * scale)) + nnz(Q_scaled ~= round(double(Q_rom) * scale));
Ii = int16(I_scaled);
Qi = int16(Q_scaled);
end

function meta = normalize_meta_from_file(S)
if isfield(S, 'meta')
    meta = S.meta;
elseif isfield(S, 'cfg')
    meta = S.cfg;
else
    error('Unknown meta MAT structure.');
end
if ~isfield(meta, 'bw_margin_sc')
    meta.bw_margin_sc = 1;
end
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

function y = sat_or_wrap(v, acc_w, saturate, acc_rng, acc_min, acc_max)
if saturate
    if v > acc_max
        y = acc_max;
    elseif v < acc_min
        y = acc_min;
    else
        y = v;
    end
else
    y = mod(v - acc_min, acc_rng) + acc_min;
end
end

function dbg = merge_dbg(di, dq)
dbg = struct();
dbg.ov_count = double(di.ov_count) + double(dq.ov_count);
dbg.sat_hi = double(di.sat_hi) + double(dq.sat_hi);
dbg.sat_lo = double(di.sat_lo) + double(dq.sat_lo);
dbg.vpk = max(double(di.vpk), double(dq.vpk));
end

function write_markdown(Tbest, T, out_md)
fid = fopen(out_md, 'w');
if fid < 0
    error('Cannot write %s', out_md);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>

fprintf(fid, '# EFDSM3 Fixed Search\\n\\n');
fprintf(fid, '## Best Candidate\\n\\n');
fprintf(fid, '- `A = %.6f`\\n', Tbest.A);
fprintf(fid, '- `b1 = %.0f`, `b2 = %.0f`, `b3 = %.0f`\\n', Tbest.b1, Tbest.b2, Tbest.b3);
fprintf(fid, '- `EVM = %.4f%%`\\n', Tbest.EVM_percent);
fprintf(fid, '- `SNDR = %.4f dB`\\n', Tbest.SNDR_dB);
fprintf(fid, '- `ACLR_avg = %.4f dBc`\\n', Tbest.ACLR_avg_dBc);
fprintf(fid, '- `ov_count = %.0f`, `clip_count = %.0f`\\n\\n', Tbest.ov_count, Tbest.clip_count);

fprintf(fid, '## Top 10 by EVM\\n\\n');
fprintf(fid, '| A | b1 | b2 | b3 | EVM (%%) | SNDR (dB) | ACLR_avg (dBc) | ov_count | clip_count |\\n');
fprintf(fid, '|---:|---:|---:|---:|---:|---:|---:|---:|---:|\\n');
N = min(10, height(T));
for k = 1:N
    fprintf(fid, '| %.6f | %.0f | %.0f | %.0f | %.4f | %.4f | %.4f | %.0f | %.0f |\\n', ...
        T.A(k), T.b1(k), T.b2(k), T.b3(k), T.EVM_percent(k), T.SNDR_dB(k), ...
        T.ACLR_avg_dBc(k), T.ov_count(k), T.clip_count(k));
end
end

function must_exist_file(p)
if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
end
end
