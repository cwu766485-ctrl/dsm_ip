function T = compare_native_nominal_dsm_orders(coe_i, coe_q, meta_file, out_prefix)
% compare_native_nominal_dsm_orders
% Compare nominal-point native-domain metrics on the current OSR32 stage1
% waveform for:
%   1) 1st-order LP DSM
%   2) 1st-order EF DSM
%   3) traditional 2nd-order single-loop DSM
%   4) 2nd-order EF DSM

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
if nargin < 4 || isempty(out_prefix)
    out_prefix = fullfile(repo, 'fpga', 'vivado', 'cartesian_dsm', 'sim_logs', ...
        'legacy_native_nominal_dsm_orders');
end

must_exist_file(coe_i);
must_exist_file(coe_q);
must_exist_file(meta_file);

I_rom = lp_read_coe_int16_hex(coe_i);
Q_rom = lp_read_coe_int16_hex(coe_q);
S = load(meta_file);
if ~isfield(S, 'meta')
    error('meta_file must contain struct meta.');
end
meta = S.meta;

scale_q15 = double(2^15 - 1);
x_ref = double(I_rom(:)) / scale_q15 + 1j * double(Q_rom(:)) / scale_q15;
BWch = (max(abs(meta.active_bins)) + 1) * meta.Delta_f * 2;
adjOffset = BWch;

designs = { ...
    'LPDSM1',      'single_loop',     32, @run_lp1; ...
    'EFDSM1',      'error_feedback',  28, @run_ef1; ...
    'DSM2_CLASSIC','single_loop',     40, @run_dsm2; ...
    'EFDSM2',      'error_feedback',  28, @run_ef2 ...
};

rows = struct([]);
for k = 1:size(designs, 1)
    design_name = string(designs{k,1});
    arch = string(designs{k,2});
    acc_w = double(designs{k,3});
    runner = designs{k,4};

    [y_bb, dbg] = runner(int64(I_rom), int64(Q_rom));

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

    rows(k).Design = design_name;
    rows(k).Architecture = arch;
    rows(k).MetricDomain = "native_bb_model";
    rows(k).Modulation = get_meta_field(meta, 'mod_name', "16QAM");
    rows(k).OSR = double(meta.OSR);
    rows(k).A_nom = double(get_meta_field(meta, 'A', NaN));
    rows(k).InputDepth = numel(I_rom);
    rows(k).NativeScale = 1;
    rows(k).AccW = acc_w;
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
    rows(k).PAPR_BBrec_dB = calc_papr_db(y_al);
    rows(k).ACLR_L_dBc = ac.ACPR_L_dBc;
    rows(k).ACLR_R_dBc = ac.ACPR_R_dBc;
    rows(k).ACLR_avg_dBc = mean([ac.ACPR_L_dBc, ac.ACPR_R_dBc], 'omitnan');
    rows(k).Overflow = double(get_dbg_field(dbg, 'ov_count', 0));
    rows(k).SatCount = double(get_dbg_field(dbg, 'sat_hi', 0) + get_dbg_field(dbg, 'sat_lo', 0));
    rows(k).StatePeakRatio = double(get_state_peak(dbg)) / double(2^(acc_w-1) - 1);
end

T = struct2table(rows);

mkout(fileparts(out_prefix));
writetable(T, [out_prefix, '.csv']);
write_md_table(T, [out_prefix, '.md']);
save([out_prefix, '.mat'], 'T', 'meta');
disp(T);
fprintf('Saved CSV: %s\n', [out_prefix, '.csv']);
fprintf('Saved MD : %s\n', [out_prefix, '.md']);
end

function [y_bb, dbg] = run_lp1(Ii, Qi)
[yi, di] = lp1_fixed_model(Ii, 32, false);
[yq, dq] = lp1_fixed_model(Qi, 32, false);
y_bb = double(yi(:)) + 1j * double(yq(:));
dbg = merge_dbg(di, dq);
end

function [y_bb, dbg] = run_ef1(Ii, Qi)
[yi, ~, di] = ef1_fixed_model_with_error(Ii, 28, true);
[yq, ~, dq] = ef1_fixed_model_with_error(Qi, 28, true);
y_bb = double(yi(:)) + 1j * double(yq(:));
dbg = merge_dbg(di, dq);
end

function [y_bb, dbg] = run_dsm2(Ii, Qi)
[yi, di] = dsm2_singleloop_fixed_model(Ii, 40, true);
[yq, dq] = dsm2_singleloop_fixed_model(Qi, 40, true);
y_bb = double(yi(:)) + 1j * double(yq(:));
dbg = merge_dbg(di, dq);
end

function [y_bb, dbg] = run_ef2(Ii, Qi)
[yi, di] = ef2_fixed_model(Ii, 28, true, int64(2), int64(-1));
[yq, dq] = ef2_fixed_model(Qi, 28, true, int64(2), int64(-1));
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

function dbg = merge_dbg(di, dq)
dbg = struct();
dbg.ov_count = get_dbg_field(di, 'ov_count', 0) + get_dbg_field(dq, 'ov_count', 0);
dbg.sat_hi = get_dbg_field(di, 'sat_hi', 0) + get_dbg_field(dq, 'sat_hi', 0);
dbg.sat_lo = get_dbg_field(di, 'sat_lo', 0) + get_dbg_field(dq, 'sat_lo', 0);
dbg.vpk = max(get_state_peak(di), get_state_peak(dq));
end

function v = get_state_peak(dbg)
v = 0;
fields = {'vpk', 'vpk1', 'vpk2', 'vpk3', 'hpk'};
for k = 1:numel(fields)
    v = max(v, double(get_dbg_field(dbg, fields{k}, 0)));
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

function write_md_table(T, out_md)
fid = fopen(out_md, 'w');
if fid < 0
    error('Cannot write %s', out_md);
end
cleaner = onCleanup(@() fclose(fid)); %#ok<NASGU>
fprintf(fid, '| Design | Arch | OSR | Mod | A_nom | EVM (%%) | SNDR (dB) | ACLR_avg (dBc) | Overflow | SatCount |\n');
fprintf(fid, '|---|---|---:|---|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %s | %.0f | %s | %.6f | %.4f | %.4f | %.4f | %d | %d |\n', ...
        T.Design(k), T.Architecture(k), T.OSR(k), T.Modulation(k), T.A_nom(k), ...
        T.EVM_percent(k), T.SNDR_dB(k), T.ACLR_avg_dBc(k), T.Overflow(k), T.SatCount(k));
end
end

function mkout(p)
if exist(p, 'dir') ~= 7
    mkdir(p);
end
end

function must_exist_file(p)
if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
end
end

function v = get_meta_field(meta, f, d)
if isstruct(meta) && isfield(meta, f) && ~isempty(meta.(f))
    v = meta.(f);
else
    v = d;
end
end
