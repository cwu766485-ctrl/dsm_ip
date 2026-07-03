function T = eval_legacy_rtl_metrics_table_strict(xsim_dir, coe_i, coe_q, meta_in, out_csv)
% eval_legacy_rtl_metrics_table_strict
% Strict final-RF evaluation for the legacy RTL simulations.
% Aperture:
%   final RF digital IO -> fs/4 reconstruction (bittrue_lock with fallback)
%   -> LP reconstruction/decimation -> LS-align -> EVM/SNDR/PAPR

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
        'legacy_rtl_metrics_table_strict.csv');
end

must_exist_dir(xsim_dir);
must_exist_file(coe_i);
must_exist_file(coe_q);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);
x_ref = double(I_rom(:)) / double(2^15 - 1) + 1j * double(Q_rom(:)) / double(2^15 - 1);

BWch = (max(abs(meta.active_bins)) + meta.bw_margin_sc) * meta.Delta_f * 2;
adjOffset = BWch;

designs = { ...
    'LPDSM',      'sim_rf_bits_01.txt',           'bit01'; ...
    'EFDSM2',     'sim_rf_bits_01_ef2.txt',       'bit01'; ...
    'EFDSM4',     'sim_rf_bits_01_ef4.txt',       'bit01'; ...
    'MASH11_MB',  'sim_rf_signed_mash11_mb.txt',  'signed'; ...
    'MASH22_MB',  'sim_rf_signed_mash22_mb.txt',  'signed'; ...
    'MASH111_MB', 'sim_rf_signed_mash111_mb.txt', 'signed' ...
};

rows = repmat(struct( ...
    'Design', "", ...
    'MetricDomain', "rf_io_fs4_strict", ...
    'N_rf', 0, ...
    'N_rec', 0, ...
    'ReconMode', "", ...
    'ReconPhase', 0, ...
    'ReconQSign', 1, ...
    'ReconQShift', 0, ...
    'ReconScore', NaN, ...
    'Fs_work_Hz', NaN, ...
    'OSR_work', NaN, ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'PAPR_RFraw_dB', NaN, ...
    'PAPR_BBrec_dB', NaN, ...
    'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, ...
    'ACLR_avg_dBc', NaN), ...
    size(designs, 1), 1);

rf_eval_cfg = default_rf_eval_cfg();

for k = 1:size(designs, 1)
    design_name = string(designs{k,1});
    rf_file = fullfile(xsim_dir, designs{k,2});
    rf_kind = string(designs{k,3});
    must_exist_file(rf_file);

    y_rf = read_rf_dump(rf_file, rf_kind);
    [y_bb_raw, x_ref_work, Fs_work, osr_work, rec_meta] = rtl_fs4_reconstruct_baseband( ...
        y_rf, x_ref, meta.Fs_dsm, meta.OSR, BWch, rf_eval_cfg, x_ref);

    recCfg = struct( ...
        'OSR', max(1, round(osr_work)), ...
        'Fs_dsm', Fs_work, ...
        'Fs_bb', meta.Fs_bb, ...
        'BWch', BWch, ...
        'StopAtt', 80, ...
        'UseFastFir', false, ...
        'ZeroPhase', false);
    [y_rec, x_ref_bb] = lp_reconstruct_and_decimate(y_bb_raw, x_ref_work, recCfg);
    al = lp_align_and_ls_gain(y_rec, x_ref_bb);
    [y_al, x_al] = lp_discard_settle_pair(al.y_aligned, al.x_aligned, 64);
    m = lp_calc_sndr_evm(y_al, x_al);

    psdCfg = default_psd_cfg(numel(y_bb_raw));
    ac = lp_calc_acpr_aclr_from_psd(y_bb_raw, Fs_work, BWch, adjOffset, psdCfg);

    rows(k).Design = design_name;
    rows(k).N_rf = numel(y_rf);
    rows(k).N_rec = numel(y_al);
    rows(k).ReconMode = string(rec_meta.mode);
    rows(k).ReconPhase = rec_meta.phase;
    rows(k).ReconQSign = rec_meta.q_sign;
    rows(k).ReconQShift = rec_meta.q_shift;
    rows(k).ReconScore = rec_meta.score;
    rows(k).Fs_work_Hz = Fs_work;
    rows(k).OSR_work = osr_work;
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

function cfg = default_rf_eval_cfg()
cfg = struct();
cfg.rtl_fs4_reconstruct_impl = 'bittrue_lock';
cfg.rtl_fs4_autoselect = true;
cfg.rtl_fs4_phase_offset_list = 0:3;
cfg.rtl_fs4_q_sign_list = [1, -1];
cfg.rtl_fs4_q_shift_list = 0;
cfg.rtl_fs4_q_advance = true;
cfg.rtl_fs4_phase_offset = 0;
cfg.rtl_fs4_q_sign = 1;
cfg.rtl_fs4_q_shift = 0;
cfg.rtl_fs4_reconstruct_min_score = 0.55;
cfg.rtl_fs4_lock_fallback_autoselect = true;
cfg.iq_interp_order = 192;
cfg.iq_interp_pass_bw_scale = 1.20;
cfg.zero_phase_reconstruct = false;
end

function [y_bb_raw, x_ref, Fs_work, osr_work, meta] = rtl_fs4_reconstruct_baseband(y_rf, x_ref_osr, Fs_dsm, osr_in, bw_hz, rf_eval_cfg, score_ref_in)
y_rf = double(y_rf(:));
x_ref = x_ref_osr(:);
if nargin < 7 || isempty(score_ref_in)
    score_ref = x_ref_osr(:);
else
    score_ref = score_ref_in(:);
end
L = min(numel(y_rf), numel(x_ref));
y_rf = y_rf(1:L);
x_ref = x_ref(1:L);
score_ref = score_ref(1:L);
L = L - mod(L, 4);
if L < 8
    y_bb_raw = complex(y_rf, 0);
    Fs_work = Fs_dsm;
    osr_work = osr_in;
    meta = struct('mode', 'rtl_fs4_too_short', 'score', NaN, 'phase', 0, 'q_sign', 1, 'q_shift', 0);
    return;
end
y_rf = y_rf(1:L);
x_ref = x_ref(1:L);
score_ref = score_ref(1:L);

recon_impl = lower(string(getfield_default(rf_eval_cfg, 'rtl_fs4_reconstruct_impl', 'bittrue_lock')));
auto_sel = getfield_default(rf_eval_cfg, 'rtl_fs4_autoselect', true);
phase_list = getfield_default(rf_eval_cfg, 'rtl_fs4_phase_offset_list', 0:3);
q_sign_list = getfield_default(rf_eval_cfg, 'rtl_fs4_q_sign_list', [1, -1]);
q_shift_list = getfield_default(rf_eval_cfg, 'rtl_fs4_q_shift_list', 0);
if getfield_default(rf_eval_cfg, 'rtl_fs4_q_advance', false)
    q_shift_list = unique([q_shift_list(:).', -1, 0, 1]);
end
lock_phase = round(getfield_default(rf_eval_cfg, 'rtl_fs4_phase_offset', 0));
lock_q_sign = sign(getfield_default(rf_eval_cfg, 'rtl_fs4_q_sign', 1));
if lock_q_sign == 0
    lock_q_sign = 1;
end
lock_q_shift = round(getfield_default(rf_eval_cfg, 'rtl_fs4_q_shift', 0));
if ~auto_sel && recon_impl ~= "bittrue_lock"
    phase_list = lock_phase;
    q_sign_list = lock_q_sign;
    q_shift_list = lock_q_shift;
end

if recon_impl == "bittrue_halfrate"
    x_ref_h = rtl_fs4_make_halfrate_ref(x_ref);
    score_ref_h = rtl_fs4_make_halfrate_ref(score_ref);
    M_ref = min(numel(x_ref_h), numel(score_ref_h));
    x_ref_h = x_ref_h(1:M_ref);
    score_ref_h = score_ref_h(1:M_ref);
    q_advance_half = getfield_default(rf_eval_cfg, 'rtl_fs4_q_advance', false);

    best = struct('score', -Inf, 'q_sign', lock_q_sign, 'q_shift', lock_q_shift, ...
        'phase', lock_phase, 'mode', 'rtl_fs4_bittrue_halfrate');
    y_best = complex(zeros(M_ref, 1));
    x_best = x_ref_h;

    for ph0 = phase_list(:).'
        for qs = q_sign_list(:).'
            for qsh = q_shift_list(:).'
                y_h = rtl_fs4_demux_halfrate_once(y_rf, ph0, qs, qsh);
                if q_advance_half
                    y_h = complex(real(y_h), fs4_halfsample_advance(imag(y_h)));
                end
                M = min([numel(y_h), numel(score_ref_h), numel(x_ref_h)]);
                if M < 128
                    continue;
                end
                y_c = y_h(1:M);
                s_c = score_ref_h(1:M);
                c = abs((y_c' * s_c) / (norm(y_c) * norm(s_c) + eps));
                if c > best.score
                    best.score = c;
                    best.q_sign = sign(qs);
                    best.q_shift = round(qsh);
                    best.phase = round(ph0);
                    y_best = y_c;
                    x_best = x_ref_h(1:M);
                end
            end
        end
    end

    y_bb_raw = y_best;
    x_ref = x_best;
    Fs_work = Fs_dsm / 2;
    osr_work = max(osr_in / 2, 1);
    meta = struct( ...
        'mode', sprintf('%s(ph=%d,qs=%+d,qsh=%+d,score=%.4f)', ...
            best.mode, best.phase, best.q_sign, best.q_shift, best.score), ...
        'score', best.score, ...
        'phase', best.phase, ...
        'q_sign', best.q_sign, ...
        'q_shift', best.q_shift);
    return;
end

ord = max(32, round(getfield_default(rf_eval_cfg, 'iq_interp_order', 192)));
if mod(ord, 2) ~= 0
    ord = ord + 1;
end
pbw_scale = getfield_default(rf_eval_cfg, 'iq_interp_pass_bw_scale', 1.20);
fc_lp = min(0.49 * Fs_dsm, max(1.0, pbw_scale * (bw_hz / 2)));
Wn = min(max(fc_lp / (Fs_dsm / 2), 1e-4), 0.9999);
h = fir1(ord, Wn, blackman(ord + 1));
if getfield_default(rf_eval_cfg, 'zero_phase_reconstruct', false) && (exist('filtfilt', 'file') == 2)
    filt_op = @(v) filtfilt(h, 1, double(v));
else
    filt_op = @(v) filter(h, 1, v);
end

x_ref_f_full = filt_op(x_ref);
score_ref_f = filt_op(score_ref);

best = struct('score', -Inf, 'q_sign', lock_q_sign, 'q_shift', lock_q_shift, ...
    'phase', lock_phase, 'mode', 'rtl_fs4_bittrue_lock');
y_bb_raw = zeros(L, 1);
x_ref_f = x_ref_f_full;

[y_lock, x_lock, s_lock] = rtl_fs4_reconstruct_once(y_rf, x_ref_f_full, score_ref_f, filt_op, ...
    lock_phase, lock_q_sign, lock_q_shift);
best.score = s_lock;
y_bb_raw = y_lock;
x_ref_f = x_lock;
min_lock_score = getfield_default(rf_eval_cfg, 'rtl_fs4_reconstruct_min_score', 0.55);
do_fallback = getfield_default(rf_eval_cfg, 'rtl_fs4_lock_fallback_autoselect', true) && (s_lock < min_lock_score);
if do_fallback
    for ph0 = phase_list(:).'
        for qs = q_sign_list(:).'
            for qsh = q_shift_list(:).'
                [y_c, x_c, c] = rtl_fs4_reconstruct_once(y_rf, x_ref_f_full, score_ref_f, filt_op, ph0, qs, qsh);
                if c > best.score
                    best.score = c;
                    best.q_sign = sign(qs);
                    best.q_shift = round(qsh);
                    best.phase = round(ph0);
                    best.mode = 'rtl_fs4_sparse_fallback';
                    y_bb_raw = y_c;
                    x_ref_f = x_c;
                end
            end
        end
    end
end

x_ref = x_ref_f;
Fs_work = Fs_dsm;
osr_work = osr_in;
meta = struct( ...
    'mode', sprintf('%s(ph=%d,qs=%+d,qsh=%+d,score=%.4f)', ...
        best.mode, best.phase, best.q_sign, best.q_shift, best.score), ...
    'score', best.score, ...
    'phase', best.phase, ...
    'q_sign', best.q_sign, ...
    'q_shift', best.q_shift);
end

function [y_c, x_ref_f, c] = rtl_fs4_reconstruct_once(y_rf, x_ref_f_full, score_ref_f, filt_op, ph0, qs, qsh)
L = numel(y_rf);
n_all = (1:L).';
ph = mod(n_all - 1 - round(ph0), 4);
idx_i = (ph == 0) | (ph == 2);
idx_q = (ph == 1) | (ph == 3);
s_i = ones(L, 1);
s_q = ones(L, 1);
s_i(ph == 2) = -1;
s_q(ph == 3) = -1;

I_sparse = zeros(L, 1);
Q_sparse_base = zeros(L, 1);
I_sparse(idx_i) = s_i(idx_i) .* y_rf(idx_i);
Q_sparse_base(idx_q) = s_q(idx_q) .* y_rf(idx_q);
I_interp = filt_op(I_sparse);
Q_sparse = circshift(Q_sparse_base, round(qsh));
Q_interp = filt_op(sign(qs) * Q_sparse);
y_c = I_interp + 1j * Q_interp;
x_ref_f = x_ref_f_full;
c = abs((y_c' * score_ref_f) / (norm(y_c) * norm(score_ref_f) + eps));
end

function y_h = rtl_fs4_demux_halfrate_once(y_rf, ph0, q_sign, q_shift)
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

Ih = zeros(2 * M, 1);
Qh = zeros(2 * M, 1);
Ih(1:2:end) = i0;
Ih(2:2:end) = i2;
Qh(1:2:end) = q1;
Qh(2:2:end) = q3;
Qh = sign(q_sign) * circshift(Qh, round(q_shift));

y_h = Ih + 1j * Qh;
end

function x_h = rtl_fs4_make_halfrate_ref(x_full)
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
need = {'Delta_f', 'Fs_bb', 'OSR', 'Fs_dsm', 'active_bins'};
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

fprintf(fid, '| Design | ReconMode | ReconScore | EVM (%%) | SNDR (dB) | PAPR_RFraw (dB) | PAPR_BBrec (dB) | ACLR_avg (dBc) |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        T.Design(k), T.ReconMode(k), T.ReconScore(k), T.EVM_percent(k), T.SNDR_dB(k), ...
        T.PAPR_RFraw_dB(k), T.PAPR_BBrec_dB(k), T.ACLR_avg_dBc(k));
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

function v = getfield_default(s, f, d)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = d;
end
end
