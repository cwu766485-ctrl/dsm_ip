function T = eval_legacy_rtl_metrics_table(xsim_dir, coe_i, coe_q, meta_in, out_csv)
% eval_legacy_rtl_metrics_table
% Evaluate the current legacy RTL simulations:
%   LPDSM / EFDSM2 / EFDSM3 / EFDSM4 / MASH11_MB / MASH22_MB / MASH111_MB
%
% Metric aperture:
%   final RF digital IO -> fs/4 bit-true demux -> complex baseband
%   -> LP reconstruction/decimation -> EVM/SNDR/PAPR
%
% ACLR is computed on the demuxed complex baseband waveform before the final
% low-pass reconstruction, which keeps the metric tied to the emitted fs/4
% digital output rather than the internal native-domain dumps.

if nargin < 1 || isempty(xsim_dir)
    repo = lp_find_repo_root(fileparts(mfilename('fullpath')));
    xsim_dir = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', ...
        'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim');
else
    repo = lp_find_repo_root(fileparts(mfilename('fullpath')));
end
if nargin < 2 || isempty(coe_i)
    coe_i = fullfile(repo, 'fpga', 'data', 'coe', ...
        'I_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 3 || isempty(coe_q)
    coe_q = fullfile(repo, 'fpga', 'data', 'coe', ...
        'Q_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 4 || isempty(meta_in)
    meta = default_meta();
else
    meta = normalize_meta(meta_in);
end
if nargin < 5 || isempty(out_csv)
    out_csv = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', 'sim_logs', ...
        'legacy_rtl_metrics_table.csv');
end

must_exist_dir(xsim_dir);
must_exist_file(coe_i);
must_exist_file(coe_q);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);
x_ref = double(I_rom(:)) / double(2^15 - 1) + 1j * double(Q_rom(:)) / double(2^15 - 1);

BWch = (max(abs(meta.active_bins)) + meta.bw_margin_sc) * meta.Delta_f * 2;
adjOffset = BWch;
Fs_work = meta.Fs_dsm / 2;
OSR_work = max(1, round(meta.OSR / 2));

designs = { ...
    'LPDSM',     'sim_rf_bits_01.txt',            'bit01'; ...
    'EFDSM2',    'sim_rf_bits_01_ef2.txt',        'bit01'; ...
    'EFDSM3',    'sim_rf_bits_01_ef3.txt',        'bit01'; ...
    'EFDSM4',    'sim_rf_bits_01_ef4.txt',        'bit01'; ...
    'MASH11_MB', 'sim_rf_signed_mash11_mb.txt',   'signed'; ...
    'MASH22_MB', 'sim_rf_signed_mash22_mb.txt',   'signed'; ...
    'MASH111_MB','sim_rf_signed_mash111_mb.txt',  'signed'  ...
};

rows = repmat(struct( ...
    'Design', "", ...
    'MetricDomain', "rf_io_fs4_demux", ...
    'N_rf', 0, ...
    'N_rec', 0, ...
    'ReconPhase', 0, ...
    'ReconQSign', 1, ...
    'ReconQShift', 0, ...
    'ReconScore', NaN, ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'PAPR_RFraw_dB', NaN, ...
    'PAPR_BBrec_dB', NaN, ...
    'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, ...
    'ACLR_avg_dBc', NaN), ...
    size(designs, 1), 1);

for k = 1:size(designs, 1)
    design_name = string(designs{k,1});
    rf_file = fullfile(xsim_dir, designs{k,2});
    rf_kind = string(designs{k,3});
    must_exist_file(rf_file);

    y_rf = read_rf_dump(rf_file, rf_kind);
    [y_bb_raw, x_ref_h, rec_meta] = reconstruct_fs4_halfrate(y_rf, x_ref);

    psdCfg = default_psd_cfg(numel(y_bb_raw));
    ac = lp_calc_acpr_aclr_from_psd(y_bb_raw, Fs_work, BWch, adjOffset, psdCfg);

    recCfg = struct( ...
        'OSR', OSR_work, ...
        'Fs_dsm', Fs_work, ...
        'Fs_bb', meta.Fs_bb, ...
        'BWch', BWch, ...
        'StopAtt', 80, ...
        'UseFastFir', false, ...
        'ZeroPhase', false);

    [y_rec, x_ref_bb] = lp_reconstruct_and_decimate(y_bb_raw, x_ref_h, recCfg);
    al = lp_align_and_ls_gain(y_rec, x_ref_bb);
    [y_al, x_al] = lp_discard_settle_pair(al.y_aligned, al.x_aligned, 64);
    m = lp_calc_sndr_evm(y_al, x_al);

    rows(k).Design = design_name;
    rows(k).N_rf = numel(y_rf);
    rows(k).N_rec = numel(y_al);
    rows(k).ReconPhase = rec_meta.phase;
    rows(k).ReconQSign = rec_meta.q_sign;
    rows(k).ReconQShift = rec_meta.q_shift;
    rows(k).ReconScore = rec_meta.score;
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
    rows(k).PAPR_RFraw_dB = calc_papr_db(y_rf);
    rows(k).PAPR_BBrec_dB = calc_papr_db(y_al);
    rows(k).ACLR_L_dBc = ac.ACPR_L_dBc;
    rows(k).ACLR_R_dBc = ac.ACPR_R_dBc;
    rows(k).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
end

T = struct2table(rows);

out_dir = fileparts(out_csv);
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end
writetable(T, out_csv);

md_path = replace(string(out_csv), ".csv", ".md");
write_markdown_table(T, char(md_path));

disp(T);
fprintf('Saved CSV: %s\n', out_csv);
fprintf('Saved MD : %s\n', md_path);
end

function meta = default_meta()
meta = struct();
meta.M = 16;
meta.Nfft = 64;
meta.Ncp = 16;
meta.Nsym = 500;
meta.Delta_f = 15e3;
meta.Fs_bb = 960e3;
meta.OSR = 32;
meta.Fs_dsm = meta.Fs_bb * meta.OSR;
meta.active_bins = [-26:-1, 1:26];
meta.bw_margin_sc = 1;
end

function meta = normalize_meta(meta)
need = {'Delta_f','Fs_bb','OSR','Fs_dsm','active_bins'};
for k = 1:numel(need)
    if ~isfield(meta, need{k})
        error('meta missing required field "%s".', need{k});
    end
end
if ~isfield(meta, 'bw_margin_sc')
    meta.bw_margin_sc = 1;
end
end

function y_rf = read_rf_dump(fp, kind)
v = readmatrix(fp, 'FileType', 'text');
if isempty(v) || all(isnan(v(:)))
    fid = fopen(fp, 'r');
    if fid < 0
        error('Cannot open %s', fp);
    end
    c = textscan(fid, '%f', 'Delimiter', {' ', sprintf('\t'), ','}, ...
        'MultipleDelimsAsOne', true);
    fclose(fid);
    v = c{1};
end
v = double(v(:));
v = v(isfinite(v));
if isempty(v)
    error('No numeric data in %s', fp);
end
if strcmpi(kind, 'bit01')
    y_rf = 2 * round(v) - 1;
else
    y_rf = round(v);
end
end

function [y_h, x_ref_h, meta] = reconstruct_fs4_halfrate(y_rf, x_ref)
y_rf = double(y_rf(:));
x_ref = x_ref(:);
L = min(numel(y_rf), numel(x_ref));
L = L - mod(L, 4);
if L < 8
    error('RF record too short for fs/4 reconstruction.');
end

y_rf = y_rf(1:L);
x_ref = x_ref(1:L);
x_ref_h_full = make_halfrate_ref(x_ref);

phase_list = 0:3;
q_sign_list = [1, -1];
q_shift_list = [-1, 0, 1];

best.score = -Inf;
best.phase = 0;
best.q_sign = 1;
best.q_shift = 0;
best.y_h = complex(zeros(0,1));
best.x_h = complex(zeros(0,1));

for ph0 = phase_list
    for qs = q_sign_list
        for qsh = q_shift_list
            y_c = demux_halfrate_once(y_rf, ph0, qs, qsh);
            y_c = complex(real(y_c), fs4_halfsample_advance(imag(y_c)));
            M = min(numel(y_c), numel(x_ref_h_full));
            if M < 128
                continue;
            end
            yc = y_c(1:M);
            xc = x_ref_h_full(1:M);
            score = abs((yc' * xc) / (norm(yc) * norm(xc) + eps));
            if score > best.score
                best.score = score;
                best.phase = ph0;
                best.q_sign = qs;
                best.q_shift = qsh;
                best.y_h = yc;
                best.x_h = xc;
            end
        end
    end
end

y_h = best.y_h;
x_ref_h = best.x_h;
meta = rmfield(best, {'y_h', 'x_h'});
end

function y_h = demux_halfrate_once(y_rf, ph0, q_sign, q_shift)
L = numel(y_rf);
n_all = (1:L).';
ph = mod(n_all - 1 - round(ph0), 4);

i0 = y_rf(ph == 0);
i2 = -y_rf(ph == 2);
q1 = y_rf(ph == 1);
q3 = -y_rf(ph == 3);

Mi = min(numel(i0), numel(i2));
Mq = min(numel(q1), numel(q3));
M = min(Mi, Mq);
if M <= 0
    y_h = complex(zeros(0, 1));
    return;
end

i0 = i0(1:M);
i2 = i2(1:M);
q1 = q1(1:M);
q3 = q3(1:M);

Ih = zeros(2*M, 1);
Qh = zeros(2*M, 1);
Ih(1:2:end) = i0;
Ih(2:2:end) = i2;
Qh(1:2:end) = q1;
Qh(2:2:end) = q3;
Qh = sign(q_sign) * circshift(Qh, round(q_shift));

y_h = Ih + 1j * Qh;
end

function x_h = make_halfrate_ref(x_full)
x = x_full(:);
L = numel(x) - mod(numel(x), 2);
if L < 2
    x_h = complex(zeros(0, 1));
    return;
end
x = x(1:L);
x_h = x(1:2:end);
end

function q_out = fs4_halfsample_advance(q_in)
q = q_in(:);
if numel(q) <= 1
    q_out = q;
    return;
end
q_prev = [q(1); q(1:end-1)];
q_out = 0.5 * (q + q_prev);
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

fprintf(fid, '| Design | EVM (%%) | SNDR (dB) | PAPR_RFraw (dB) | PAPR_BBrec (dB) | ACLR_L (dBc) | ACLR_R (dBc) | ACLR_avg (dBc) |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        T.Design(k), T.EVM_percent(k), T.SNDR_dB(k), T.PAPR_RFraw_dB(k), ...
        T.PAPR_BBrec_dB(k), T.ACLR_L_dBc(k), T.ACLR_R_dBc(k), T.ACLR_avg_dBc(k));
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
