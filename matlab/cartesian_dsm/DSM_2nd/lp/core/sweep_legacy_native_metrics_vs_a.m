function [T_detail, T_best] = sweep_legacy_native_metrics_vs_a(A_list, coe_i, coe_q, meta_file, out_prefix)
% sweep_legacy_native_metrics_vs_a
% Sweep the current legacy waveform amplitude A with MATLAB bit-true models
% matched to the legacy RTL cores, and report native-domain BB metrics.

repo = lp_find_repo_root(fileparts(mfilename('fullpath')));
if nargin < 2 || isempty(coe_i)
    coe_i = fullfile(repo, 'fpga', 'data', 'coe', ...
        'I_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 3 || isempty(coe_q)
    coe_q = fullfile(repo, 'fpga', 'data', 'coe', ...
        'Q_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
end
if nargin < 4 || isempty(meta_file)
    meta_file = fullfile(repo, 'archive', 'local_runs', 'matlab_lp', 'meta', ...
        'stage1_meta_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.mat');
end
if nargin < 5 || isempty(out_prefix)
    out_prefix = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', 'sim_logs', ...
        'legacy_native_metrics_vs_a');
end

must_exist_file(coe_i);
must_exist_file(coe_q);
must_exist_file(meta_file);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);

S = load(meta_file);
if ~isfield(S, 'meta') || ~isfield(S.meta, 'A')
    error('meta_file must contain struct meta with field A.');
end
meta = S.meta;
A_nom = double(meta.A);

if nargin < 1 || isempty(A_list)
    A_list = 0.04:0.02:0.36;
end
A_list = unique(sort([double(A_list(:)).', A_nom]));

BWch = (max(abs(meta.active_bins)) + 1) * meta.Delta_f * 2;
adjOffset = BWch;
scale_q15 = double(2^15 - 1);

designs = { ...
    'LPDSM',      1; ...
    'EFDSM2',     1; ...
    'EFDSM4',     1; ...
    'MASH11_MB',  3; ...
    'MASH22_MB',  5; ...
    'MASH111_MB', 7 ...
};

rows = struct([]);
row_idx = 0;

for ai = 1:numel(A_list)
    A_now = double(A_list(ai));
    [Ii, Qi, clip_count] = scale_nominal_iq(I_rom, Q_rom, A_now, A_nom);
    x_ref = double(Ii(:)) / scale_q15 + 1j * double(Qi(:)) / scale_q15;

    for di = 1:size(designs, 1)
        design_name = string(designs{di,1});
        native_scale = double(designs{di,2});

        [y_bb, dbg] = run_native_model(design_name, int64(Ii), int64(Qi));
        y_bb = y_bb(:) / native_scale;

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
        rows(row_idx).Design = design_name;
        rows(row_idx).MetricDomain = "native_bb_model";
        rows(row_idx).A = A_now;
        rows(row_idx).A_rel_nom = A_now / A_nom;
        rows(row_idx).A_nom = A_nom;
        rows(row_idx).InputClipCount = double(clip_count);
        rows(row_idx).NativeScale = native_scale;
        rows(row_idx).N_bits = numel(y_bb);
        rows(row_idx).N_rec = numel(y_al);
        rows(row_idx).EVM_percent = m.EVM_rms_percent;
        rows(row_idx).SNDR_dB = m.SNDR_dB;
        rows(row_idx).PAPR_BBrec_dB = calc_papr_db(y_al);
        rows(row_idx).ACLR_L_dBc = ac.ACPR_L_dBc;
        rows(row_idx).ACLR_R_dBc = ac.ACPR_R_dBc;
        rows(row_idx).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
        rows(row_idx).Overflow = double(get_dbg_field(dbg, 'ov_count', 0));
        rows(row_idx).SatCount = double(get_dbg_field(dbg, 'sat_hi', 0) + get_dbg_field(dbg, 'sat_lo', 0));
        rows(row_idx).StatePeakRatio = double(get_state_peak(dbg)) / double(2^(get_acc_w(design_name)-1) - 1);
        rows(row_idx).Clean = double((rows(row_idx).Overflow == 0) && ...
                                     (rows(row_idx).SatCount == 0) && ...
                                     (rows(row_idx).InputClipCount == 0));
    end
end

T_detail = struct2table(rows);

best_rows = repmat(struct( ...
    'Design', "", ...
    'BestA', NaN, ...
    'BestEVM_percent', NaN, ...
    'BestSNDR_dB', NaN, ...
    'BestACLR_avg_dBc', NaN, ...
    'Overflow', NaN, ...
    'SatCount', NaN, ...
    'InputClipCount', NaN, ...
    'StatePeakRatio', NaN, ...
    'CleanPick', 0), size(designs, 1), 1);
for di = 1:size(designs, 1)
    design_name = string(designs{di,1});
    Td = T_detail(T_detail.Design == design_name, :);
    Td_clean = Td(Td.Clean == 1, :);
    use_clean = height(Td_clean) > 0;
    if use_clean
        Tpick = Td_clean;
    else
        Tpick = Td;
    end
    [~, idx_best] = min(Tpick.EVM_percent);
    r = Tpick(idx_best, :);
    best_rows(di) = struct( ...
        'Design', design_name, ...
        'BestA', r.A(1), ...
        'BestEVM_percent', r.EVM_percent(1), ...
        'BestSNDR_dB', r.SNDR_dB(1), ...
        'BestACLR_avg_dBc', r.ACLR_avg_dBc(1), ...
        'Overflow', r.Overflow(1), ...
        'SatCount', r.SatCount(1), ...
        'InputClipCount', r.InputClipCount(1), ...
        'StatePeakRatio', r.StatePeakRatio(1), ...
        'CleanPick', double(use_clean));
end
T_best = struct2table(best_rows);

detail_csv = [out_prefix, '_detail.csv'];
best_csv = [out_prefix, '_best.csv'];
mkout(fileparts(detail_csv));
writetable(T_detail, detail_csv);
writetable(T_best, best_csv);
write_md_detail(T_detail, [out_prefix, '_detail.md']);
write_md_best(T_best, [out_prefix, '_best.md']);
save([out_prefix, '.mat'], 'T_detail', 'T_best', 'meta');
plot_evm_curves(T_detail, [out_prefix, '.png']);

disp(T_best);
fprintf('Saved detail CSV: %s\n', detail_csv);
fprintf('Saved best   CSV: %s\n', best_csv);
end

function [Ii, Qi, clip_count] = scale_nominal_iq(I_nom, Q_nom, A_now, A_nom)
sf = double(A_now) / double(A_nom);
I_scaled = round(double(I_nom(:)) * sf);
Q_scaled = round(double(Q_nom(:)) * sf);
clip_hi = double(2^15 - 1);
clip_lo = -clip_hi;
clip_count = sum(I_scaled > clip_hi | I_scaled < clip_lo | Q_scaled > clip_hi | Q_scaled < clip_lo);
I_scaled = min(max(I_scaled, clip_lo), clip_hi);
Q_scaled = min(max(Q_scaled, clip_lo), clip_hi);
Ii = int16(I_scaled);
Qi = int16(Q_scaled);
end

function [y_bb, dbg] = run_native_model(design_name, Ii, Qi)
switch upper(char(design_name))
    case 'LPDSM'
        [yi, di] = lp1_fixed_model(Ii, 32, false);
        [yq, dq] = lp1_fixed_model(Qi, 32, false);
    case 'EFDSM2'
        [yi, di] = ef2_fixed_model(Ii, 28, true, int64(2), int64(-1));
        [yq, dq] = ef2_fixed_model(Qi, 28, true, int64(2), int64(-1));
    case 'EFDSM4'
        num_q = int64([18920, -46600, 39400, -11348]);
        den_q = int64([-46481, 51434, -26001, 5036]);
        [yi, di] = ef4_iir_fixed_model_rtl(Ii, 40, true, 14, num_q, den_q);
        [yq, dq] = ef4_iir_fixed_model_rtl(Qi, 40, true, 14, num_q, den_q);
    case 'MASH11_MB'
        [yi, di] = mash11_fixed_model(Ii, 28, true, struct('enable', false, 'seq_i64', int64([])));
        [yq, dq] = mash11_fixed_model(Qi, 28, true, struct('enable', false, 'seq_i64', int64([])));
    case 'MASH22_MB'
        [yi, di] = mash22_fixed_model(Ii, 28, true, int64(2), int64(-1));
        [yq, dq] = mash22_fixed_model(Qi, 28, true, int64(2), int64(-1));
    case 'MASH111_MB'
        [yi, di] = mash111_fixed_model(Ii, 28, true, struct('enable', false, 'seq_i64', int64([])));
        [yq, dq] = mash111_fixed_model(Qi, 28, true, struct('enable', false, 'seq_i64', int64([])));
    otherwise
        error('Unsupported design %s', design_name);
end
y_bb = double(yi(:)) + 1j * double(yq(:));
dbg = merge_dbg(di, dq);
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
    y_raw = int64(x_i64(n)) + b1*e1 + b2*e2;
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
    e2 = e1;
    e1 = y - q;
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_pm, dbg] = ef4_iir_fixed_model_rtl(x_i64, acc_w, saturate, coeff_shift, num_q, den_q)
N = numel(x_i64);
y_pm = zeros(N,1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
e1 = int64(0); e2 = int64(0); e3 = int64(0); e4 = int64(0);
h1 = int64(0); h2 = int64(0); h3 = int64(0); h4 = int64(0);
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;
for n = 1:N
    acc_num = num_q(1)*e1 + num_q(2)*e2 + num_q(3)*e3 + num_q(4)*e4 ...
            - den_q(1)*h1 - den_q(2)*h2 - den_q(3)*h3 - den_q(4)*h4;
    h0_wide = round_shift_int64(acc_num, coeff_shift);
    if saturate
        h0 = min(max(h0_wide, acc_min), acc_max);
    else
        h0 = wrap_to_width(h0_wide, acc_w);
    end
    y_raw = int64(x_i64(n)) + h0;
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
    e4 = e3; e3 = e2; e2 = e1; e1 = e0;
    h4 = h3; h3 = h2; h2 = h1; h1 = h0;
    vpk = max(vpk, max(abs(double(y)), abs(double(h0))));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_mash, dbg] = mash11_fixed_model(x_i64, acc_w, saturate, dither_cfg)
if nargin < 4 || ~isstruct(dither_cfg)
    dither_cfg = struct('enable', false, 'seq_i64', int64([]));
end
d1_seq = int64([]);
if get_dbg_field(dither_cfg, 'enable', false)
    d1_seq = int64(get_dbg_field(dither_cfg, 'seq_i64', int64([])));
end
[y1_pm, e1, d1] = ef1_fixed_model_with_error(x_i64, acc_w, saturate, d1_seq);
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

function [y_mash, dbg] = mash111_fixed_model(x_i64, acc_w, saturate, dither_cfg)
if nargin < 4 || ~isstruct(dither_cfg)
    dither_cfg = struct('enable', false, 'seq_i64', int64([]));
end
d1_seq = int64([]);
if get_dbg_field(dither_cfg, 'enable', false)
    d1_seq = int64(get_dbg_field(dither_cfg, 'seq_i64', int64([])));
end
[y1_pm, e1, d1] = ef1_fixed_model_with_error(x_i64, acc_w, saturate, d1_seq);
[y2_pm, e2, d2] = ef1_fixed_model_with_error(e1, acc_w, saturate);
[y3_pm, ~, d3] = ef1_fixed_model_with_error(e2, acc_w, saturate);
N = numel(x_i64);
y_mash = zeros(N,1);
y2_prev = 0;
y3_prev1 = 0;
y3_prev2 = 0;
for n = 1:N
    y_mash(n) = y1_pm(n) + (y2_pm(n) - y2_prev) + (y3_pm(n) - 2*y3_prev1 + y3_prev2);
    y2_prev = y2_pm(n);
    y3_prev2 = y3_prev1;
    y3_prev1 = y3_pm(n);
end
dbg = struct('ov_count', d1.ov_count + d2.ov_count + d3.ov_count, ...
    'sat_hi', d1.sat_hi + d2.sat_hi + d3.sat_hi, ...
    'sat_lo', d1.sat_lo + d2.sat_lo + d3.sat_lo, ...
    'vpk1', d1.vpk, 'vpk2', d2.vpk, 'vpk3', d3.vpk);
end

function [y_pm, e_hist, dbg] = ef1_fixed_model_with_error(x_i64, acc_w, saturate, dither_i64)
N = numel(x_i64);
y_pm = zeros(N,1);
e_hist = int64(zeros(N,1));
if nargin < 4 || isempty(dither_i64)
    dither_i64 = int64(zeros(N,1));
else
    dither_i64 = int64(dither_i64(:));
    if numel(dither_i64) < N
        dither_i64 = [dither_i64; repmat(dither_i64(end), N - numel(dither_i64), 1)];
    elseif numel(dither_i64) > N
        dither_i64 = dither_i64(1:N);
    end
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
    y_raw = int64(x_i64(n)) + dither_i64(n) + e1;
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

function [y_mash, dbg] = mash22_fixed_model(x_i64, acc_w, saturate, b1, b2)
N = numel(x_i64);
y_mash = zeros(N,1);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
e11 = int64(0); e12 = int64(0);
e21 = int64(0); e22 = int64(0);
y2_prev1 = 0; y2_prev2 = 0;
ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk1 = 0;
vpk2 = 0;
for n = 1:N
    y1_raw = int64(x_i64(n)) + b1*e11 + b2*e12;
    if (y1_raw > acc_max) || (y1_raw < acc_min), ov = ov + 1; end
    y1_int = sat_or_wrap(y1_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if y1_int == acc_max && y1_raw > acc_max, sat_hi = sat_hi + 1; end
    if y1_int == acc_min && y1_raw < acc_min, sat_lo = sat_lo + 1; end
    if y1_int >= 0, q1 = fs; y1_pm = 1; else, q1 = -fs; y1_pm = -1; end
    e10 = y1_int - q1;
    e12 = e11; e11 = e10;
    vpk1 = max(vpk1, abs(double(y1_int)));

    y2_raw = e10 + b1*e21 + b2*e22;
    if (y2_raw > acc_max) || (y2_raw < acc_min), ov = ov + 1; end
    y2_int = sat_or_wrap(y2_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if y2_int == acc_max && y2_raw > acc_max, sat_hi = sat_hi + 1; end
    if y2_int == acc_min && y2_raw < acc_min, sat_lo = sat_lo + 1; end
    if y2_int >= 0, q2 = fs; y2_pm = 1; else, q2 = -fs; y2_pm = -1; end
    e20 = y2_int - q2;
    e22 = e21; e21 = e20;
    vpk2 = max(vpk2, abs(double(y2_int)));

    y_mash(n) = y1_pm + y2_pm - 2*y2_prev1 + y2_prev2;
    y2_prev2 = y2_prev1;
    y2_prev1 = y2_pm;
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk1', vpk1, 'vpk2', vpk2);
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

function y = round_shift_int64(v, sh)
if sh <= 0
    y = int64(v);
    return;
end
half = int64(2^(sh-1));
if v >= 0
    y = bitshift(int64(v) + half, -sh);
else
    y = bitshift(int64(v) - half, -sh);
end
end

function y = wrap_to_width(v, w)
v = int64(v);
acc_min = int64(-2^(w-1));
modv = int64(2^w);
y = mod(v - acc_min, modv) + acc_min;
end

function dbg = merge_dbg(di, dq)
dbg = struct();
dbg.ov_count = get_dbg_field(di, 'ov_count', 0) + get_dbg_field(dq, 'ov_count', 0);
dbg.sat_hi = get_dbg_field(di, 'sat_hi', 0) + get_dbg_field(dq, 'sat_hi', 0);
dbg.sat_lo = get_dbg_field(di, 'sat_lo', 0) + get_dbg_field(dq, 'sat_lo', 0);
dbg.vpk = max(get_state_peak(di), get_state_peak(dq));
end

function v = get_state_peak(dbg)
fields = {'vpk', 'vpk1', 'vpk2', 'vpk3'};
v = 0;
for k = 1:numel(fields)
    v = max(v, double(get_dbg_field(dbg, fields{k}, 0)));
end
end

function w = get_acc_w(design_name)
switch upper(char(design_name))
    case 'LPDSM'
        w = 32;
    case 'EFDSM2'
        w = 28;
    case 'EFDSM4'
        w = 40;
    otherwise
        w = 28;
end
end

function v = get_dbg_field(s, f, d)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = d;
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

function mkout(p)
if exist(p, 'dir') ~= 7
    mkdir(p);
end
end

function write_md_detail(T, out_md)
fid = fopen(out_md, 'w');
if fid < 0
    error('Cannot write %s', out_md);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '| Design | A | EVM (%%) | SNDR (dB) | ACLR_avg (dBc) | Overflow | SatCount | ClipCount | Clean |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %.6f | %.4f | %.4f | %.4f | %d | %d | %d | %d |\n', ...
        T.Design(k), T.A(k), T.EVM_percent(k), T.SNDR_dB(k), T.ACLR_avg_dBc(k), ...
        T.Overflow(k), T.SatCount(k), T.InputClipCount(k), T.Clean(k));
end
end

function write_md_best(T, out_md)
fid = fopen(out_md, 'w');
if fid < 0
    error('Cannot write %s', out_md);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '| Design | BestA | BestEVM (%%) | BestSNDR (dB) | BestACLR_avg (dBc) | CleanPick |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %.6f | %.4f | %.4f | %.4f | %d |\n', ...
        T.Design(k), T.BestA(k), T.BestEVM_percent(k), T.BestSNDR_dB(k), ...
        T.BestACLR_avg_dBc(k), T.CleanPick(k));
end
end

function plot_evm_curves(T, out_png)
fig = figure('Visible', 'off', 'Color', 'w');
hold on; grid on;
names = unique(T.Design, 'stable');
for k = 1:numel(names)
    Td = sortrows(T(T.Design == names(k), :), 'A');
    plot(Td.A, Td.EVM_percent, '-o', 'LineWidth', 1.2, 'MarkerSize', 4, 'DisplayName', char(names(k)));
end
xlabel('Input amplitude A');
ylabel('EVM (%)');
title('Legacy Native Metrics: EVM vs A');
legend('Location', 'best');
saveas(fig, out_png);
close(fig);
end

function must_exist_file(p)
if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
end
end
