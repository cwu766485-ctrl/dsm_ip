function out = run_pa_nonlinearity_tolerance_v1(profile, cfg_in)
% run_pa_nonlinearity_tolerance_v1
% Sweep PA cubic nonlinearity (alpha3) and compare RouteA vs RouteB.
%
% Goals:
%   1) Keep RouteA/RouteB baseline settings fixed at alpha3=0
%   2) Sweep alpha3 and export paper-ready CSV
%   3) Quantify RouteA robustness vs RouteB linearity sensitivity
%
% Usage:
%   out = run_pa_nonlinearity_tolerance_v1();
%   out = run_pa_nonlinearity_tolerance_v1('quick');
%   out = run_pa_nonlinearity_tolerance_v1('long');
%   out = run_pa_nonlinearity_tolerance_v1('quick', cfg_override);

if nargin < 1 || isempty(profile)
    profile = 'quick';
end
if nargin < 2
    cfg_in = struct();
end

cfg = default_cfg(profile);
if ~isempty(cfg_in)
    cfg = apply_cfg_overrides(cfg, cfg_in);
end

root = fileparts(mfilename('fullpath'));
stamp = datestr(now, 'yyyymmdd_HHMMSS');
out_dir = fullfile(root, 'results', ['pa_nonlinearity_tolerance_v1_' stamp]);
mkpath(out_dir);

fprintf('\n=== PA Nonlinearity Tolerance (%s) ===\n', upper(char(cfg.profile)));
fprintf('BW list (MHz): %s\n', mat2str(cfg.bw_list_hz(:).'/1e6, 4));
fprintf('alpha3 list: %s\n', mat2str(cfg.pa_alpha3_list, 4));

rows_main = {};
rows_baseline = {};
rows_routea_scan = {};

for ibw = 1:numel(cfg.bw_list_hz)
    bw_hz = cfg.bw_list_hz(ibw);
    [nfft, ncp] = pick_fft_cp(bw_hz);
    c_common = build_common_cfg(cfg, bw_hz, nfft, ncp);

    fprintf('\n--- BW %.1f MHz | Nfft=%d Ncp=%d | Nsym=%d ---\n', ...
        bw_hz/1e6, nfft, ncp, c_common.Nsym);

    [ra_best, ra_scan] = select_routea_best_a0(c_common, cfg.routeA, bw_hz);
    for i = 1:numel(ra_scan)
        rows_routea_scan{end+1,1} = ra_scan{i}; %#ok<AGROW>
    end

    rb_sel_cfg = build_routeb_select_cfg(c_common, cfg.routeB);
    rb_out = run_routeB_parallel_v1('b1', rb_sel_cfg);
    [rb_best, rb_alg] = pick_best_routeb_record(rb_out.records);
    rb_A0 = rb_best.auto.A_used;

    fprintf('Baseline @alpha3=0: RouteA A=%.3f | RouteB %s A=%.3f\n', ...
        ra_best.A_used, upper(rb_alg), rb_A0);

    rows_baseline{end+1,1} = struct( ... %#ok<AGROW>
        'BW_MHz', bw_hz/1e6, ...
        'RouteA_A0', ra_best.A_used, ...
        'RouteA_EVM0_percent', ra_best.EVM_percent, ...
        'RouteA_SNDR0_dB', ra_best.SNDR_dB, ...
        'RouteB_Alg0', string(upper(rb_alg)), ...
        'RouteB_A0', rb_A0, ...
        'RouteB_EVM0_percent', rb_best.auto.EVM_percent, ...
        'RouteB_SNDR0_dB', rb_best.auto.SNDR_dB);

    for ia = 1:numel(cfg.pa_alpha3_list)
        alpha3 = cfg.pa_alpha3_list(ia);
        fprintf('  alpha3=%.4f\n', alpha3);

        ra = eval_routea_alpha3(c_common, cfg.routeA, ra_best.A_used, alpha3);
        rb = eval_routeb_alpha3(c_common, cfg.routeB, rb_alg, rb_A0, alpha3);

        rows_main{end+1,1} = make_row(bw_hz, cfg, "RouteA", "EFDSM4(stage4)", ... %#ok<AGROW>
            ra.metric_domain, alpha3, ra.A_used, ra.EVM_percent, ra.SNDR_dB, ra.ACLR_dBc, ...
            ra.ov, ra.sat, ra.ofdm_valid, ra.runtime_s);
        rows_main{end+1,1} = make_row(bw_hz, cfg, "RouteB", string(sprintf('%s(stage1)', upper(rb_alg))), ... %#ok<AGROW>
            rb.metric_domain, alpha3, rb.A_used, rb.EVM_percent, rb.SNDR_dB, rb.ACLR_dBc, ...
            rb.ov, rb.sat, rb.ofdm_valid, rb.runtime_s);
    end
end

T_main = cellrows_to_table(rows_main);
T_base = cellrows_to_table(rows_baseline);
T_ra_scan = cellrows_to_table(rows_routea_scan);
if ~isempty(T_main)
    T_main.Clean = (T_main.Overflow == 0) & (T_main.Sat == 0) & ...
        isfinite(T_main.EVM_percent) & isfinite(T_main.SNDR_dB);
    T_main.Pass_256QAM = T_main.EVM_percent <= 3.5;
end

main_csv = fullfile(out_dir, 'pa_nonlinearity_main.csv');
base_csv = fullfile(out_dir, 'pa_nonlinearity_baseline.csv');
ra_csv = fullfile(out_dir, 'pa_nonlinearity_routeA_A0_scan.csv');
writetable(T_main, main_csv);
writetable(T_base, base_csv);
writetable(T_ra_scan, ra_csv);

txt_file = fullfile(out_dir, 'pa_nonlinearity_summary.txt');
fid = fopen(txt_file, 'w');
if fid >= 0
    fprintf(fid, 'PA nonlinearity tolerance summary\n');
    fprintf(fid, 'profile=%s\n', char(cfg.profile));
    fprintf(fid, 'BW list (MHz)=%s\n', mat2str(cfg.bw_list_hz(:).'/1e6));
    fprintf(fid, 'alpha3 list=%s\n', mat2str(cfg.pa_alpha3_list));
    fprintf(fid, 'RouteA eval: EFDSM4 stage4, fixed A from alpha3=0 best point\n');
    fprintf(fid, 'RouteB eval: stage1 best algorithm fixed at alpha3=0, RF output mode=%s\n', char(cfg.routeB.rf_output_mode));
    fprintf(fid, 'Use only rows with OfdmValid=1 and Clean=1 for paper conclusions.\n');
    fclose(fid);
end

out = struct();
out.timestamp = stamp;
out.output_dir = out_dir;
out.cfg = cfg;
out.tables = struct('main', T_main, 'baseline', T_base, 'routeA_a0_scan', T_ra_scan);
out.csv = struct('main', main_csv, 'baseline', base_csv, 'routeA_a0_scan', ra_csv);

mat_file = fullfile(out_dir, ['pa_nonlinearity_tolerance_v1_' stamp '.mat']);
save(mat_file, 'out');

fprintf('\nSaved PA sweep package:\n');
fprintf('  %s\n', out_dir);
fprintf('  %s\n', main_csv);
fprintf('  %s\n', base_csv);
fprintf('  %s\n', ra_csv);
fprintf('  %s\n', txt_file);
fprintf('  %s\n', mat_file);
end

function cfg = default_cfg(profile)
cfg = struct();
cfg.profile = lower(string(profile));
if ~(cfg.profile == "quick" || cfg.profile == "long")
    error('profile must be ''quick'' or ''long''.');
end

is_quick = cfg.profile == "quick";
cfg.seed = 7;
cfg.M = 256;
cfg.delta_f = 15e3;
cfg.osr_main = 32;
cfg.bw_list_hz = [20e6, 40e6];
cfg.pa_alpha3_list = [0.00, 0.005, 0.01, 0.02, 0.03, 0.04, 0.05];

if is_quick
    cfg.Nsym = 20;
    cfg.debug = struct('enable', true, 'Nsym', 20, 'psd_win_len', 1024, ...
        'psd_nfft', 4096, 'disable_coe', true, 'disable_save', true);
else
    cfg.Nsym = 120;
    cfg.debug = struct('enable', false);
end

cfg.industrial = struct();
cfg.industrial.fc_rf_hz = 3.5e9;
cfg.industrial.fs_eq_hz = 14e9;
cfg.industrial.lanes = 8;
cfg.industrial.r_lane_hz = cfg.industrial.fs_eq_hz / cfg.industrial.lanes;
cfg.industrial.ddr_clk_hz = cfg.industrial.r_lane_hz / 2;

cfg.routeA = struct();
cfg.routeA.Hinf = 1.60;
cfg.routeA.coeff_q = 24;
cfg.routeA.lanes_internal = 4;
cfg.routeA.lookahead_alpha = 0.25;
cfg.routeA.lsb_bits = 6;
cfg.routeA.lsb_weight = 0.25;
cfg.routeA.use_bb_proxy_from_rf_dig = false;
cfg.routeA.A_list_20m = [0.22, 0.23, 0.24, 0.25, 0.26];
cfg.routeA.A_list_40m = [0.21, 0.22, 0.23, 0.24];

cfg.routeB = struct();
cfg.routeB.include_mash11 = true;
cfg.routeB.fixed_A = 0.15;
cfg.routeB.A_list_by_alg = struct();
cfg.routeB.A_list_by_alg.ef4 = [0.12, 0.15, 0.18, 0.22];
cfg.routeB.A_list_by_alg.mash11 = [0.22, 0.26, 0.30, 0.34];
cfg.routeB.A_list_by_alg.mash111 = [0.22, 0.26, 0.30, 0.34];
cfg.routeB.A_list_by_alg.mash22 = [0.15, 0.18, 0.22, 0.26];
cfg.routeB.rf_output_mode = 'pm1'; % 'pm1' (stable) | 'multibit' (experimental)
end

function [nfft, ncp] = pick_fft_cp(bw_hz)
if bw_hz <= 20e6
    nfft = 2048;
    ncp = 144;
else
    nfft = 4096;
    ncp = 288;
end
end

function c = build_common_cfg(cfg, bw_hz, nfft, ncp)
c = struct();
c.exp_name = sprintf('pa_nl_tmp_bw%.0fM', bw_hz/1e6);
c.M = cfg.M;
c.random_seed = cfg.seed;
c.Nfft = nfft;
c.Ncp = ncp;
c.Nsym = cfg.Nsym;
c.delta_f = cfg.delta_f;
c.bw_targets_hz = bw_hz;
c.osr_main = cfg.osr_main;
c.rf_mode = 'ideal_lo';
Fs_bb = c.Nfft * c.delta_f;
c.fc_req_hz = Fs_bb * c.osr_main / 4;
c.input_clip = 0.999;
c.fast_mode = true;
c.enable_sweep = false;
c.enable_tradeoff = false;
c.enable_plots = false;
c.export_coe = false;
c.aclr_adj_offset_hz = max(20e6, bw_hz);
c.debug = cfg.debug;

c.metrics = struct();
c.metrics.domain = 'dual';
c.metrics.primary = 'rf_final_digital';
c.metrics.aclr_domain = 'rf_final_digital';
c.metrics.rf_waveform_in_rtl_fs4 = false;
c.metrics.print_rf_final = false;

c.rf_eval = struct();
c.rf_eval.rtl_fs4_reconstruct_impl = 'bittrue_lock';
c.rf_eval.rtl_fs4_autoselect = false;
c.rf_eval.rtl_fs4_phase_offset = 0;
c.rf_eval.rtl_fs4_q_sign = 1;
c.rf_eval.rtl_fs4_q_shift = 0;
c.rf_eval.rtl_fs4_lock_fallback_autoselect = true;

c.rf_final = struct();
c.rf_final.enable = true;
c.rf_final.enable_ab = true;
c.rf_final.eval_pick = 'best_evm';
c.rf_final.save_obs = false;
c.rf_final.obs_max_len = 32768;
c.rf_final.duc_consistency_test = struct('enable', false);
c.rf_final.rtl_fs4_reconstruct_impl = 'bittrue_lock';
c.rf_final.rtl_fs4_autoselect = false;
c.rf_final.rtl_fs4_phase_offset = 0;
c.rf_final.rtl_fs4_q_sign = 1;
c.rf_final.rtl_fs4_q_shift = 0;
c.rf_final.rtl_fs4_lock_fallback_autoselect = true;
c.rf_final.halfrate_fallback_scope = 'none';
c.rf_final.pa_alpha3 = 0.0;

c.ef4_autobackoff = struct();
c.ef4_autobackoff.enable = false;
c.ef4_autobackoff.print = false;

c.cic_comp = struct();
c.cic_comp.enable = true;
c.cic_comp.stages = 3;
c.cic_comp.diff_delay = 1;
c.cic_comp.interp_rate = c.osr_main;
c.cic_comp.fir_order = 48;
c.cic_comp.max_boost_db = 6.0;
c.cic_comp.pass_edge_scale = 1.00;
c.cic_comp.stop_edge_scale = 1.25;

c.mash = struct();
c.mash.dither = struct();
c.mash.dither.enable = true;
c.mash.dither.variants = {'mash11', 'mash111'};
c.mash.dither.amp_lsb = 1;
c.mash.dither.pdf = 'tpdf';
end

function [best_row, rows] = select_routea_best_a0(c_common, ra_cfg, bw_hz)
A_list = pick_routea_a_list(ra_cfg, bw_hz);
rows = cell(1, numel(A_list));
for i = 1:numel(A_list)
    rows{i} = eval_routea_alpha3(c_common, ra_cfg, A_list(i), 0.0);
end
best_row = pick_best_eval_row(rows);
end

function A_list = pick_routea_a_list(ra_cfg, bw_hz)
if bw_hz <= 20e6
    A_list = ra_cfg.A_list_20m;
else
    A_list = ra_cfg.A_list_40m;
end
A_list = unique(double(A_list(:).'), 'stable');
end

function row = eval_routea_alpha3(c_common, ra_cfg, A_used, alpha3)
cfg = c_common;
cfg.input_backoff = A_used;
cfg.alg_enable = struct('ef2', false, 'ef4', true, 'mash22', false);
cfg.ef4_autobackoff = struct('enable', false, 'print', false);
cfg.rf_final.pa_alpha3 = alpha3;
cfg.metrics.domain = 'dual';
cfg.metrics.primary = 'rf_final_digital';
cfg.metrics.aclr_domain = 'rf_final_digital';

cfg.routeA_arch = struct();
cfg.routeA_arch.enable = true;
cfg.routeA_arch.bus_split = struct('enable', true, 'lsb_bits', ra_cfg.lsb_bits, ...
    'msb_core', 'ef4', 'lsb_core', 'ef4', 'combine_mode', 'weighted_sum_sign', ...
    'lsb_weight', ra_cfg.lsb_weight);
cfg.routeA_arch.lookahead = struct('enable', true, 'mode', 'first_diff', 'alpha', ra_cfg.lookahead_alpha);
cfg.routeA_arch.multi_lane = struct('enable', true, 'lanes', ra_cfg.lanes_internal, ...
    'bb_proxy_from_rf_dig', logical(ra_cfg.use_bb_proxy_from_rf_dig));

cfg = inject_ef4_coeff(cfg, ra_cfg.Hinf, ra_cfg.coeff_q);

t0 = tic;
r = run_chain_if200_osr16_v1(cfg);
dt = toc(t0);
r0 = r(1);
[m_use, md] = pick_metric_source(r0.metrics.ef4);
d = r0.overflow.ef4;

row = struct();
row.A_used = A_used;
row.EVM_percent = m_use.EVM_percent;
row.SNDR_dB = m_use.SNDR_dB;
row.ACLR_dBc = m_use.ACLR_avg_dBc;
row.ov = d.ov_count;
row.sat = d.sat_hi + d.sat_lo;
row.ofdm_valid = metric_ofdm_valid(m_use);
row.metric_domain = string(md);
row.runtime_s = dt;
end

function row = eval_routeb_alpha3(c_common, rb_cfg, alg, A_used, alpha3)
cfg = c_common;
cfg.input_backoff = A_used;
cfg.ef4_autobackoff.enable = false;
cfg.metrics.domain = 'dual';
cfg.metrics.primary = 'rf_final_digital';
cfg.metrics.aclr_domain = 'rf_final_digital';
cfg.rf_final.pa_alpha3 = alpha3;

cfg.alg_enable = struct('ef2', false, 'ef4', false, 'mash22', false);
if strcmpi(alg, 'ef4')
    cfg.alg_enable.ef4 = true;
else
    cfg.alg_enable.mash22 = true;
    if ~(isfield(cfg, 'mash') && isstruct(cfg.mash))
        cfg.mash = struct();
    end
    cfg.mash.variant = char(lower(string(alg)));
    cfg.mash.output_mode = 'multibit';
    rf_out_mode = 'pm1';
    if isstruct(rb_cfg) && isfield(rb_cfg, 'rf_output_mode') && ~isempty(rb_cfg.rf_output_mode)
        rf_out_mode = char(lower(string(rb_cfg.rf_output_mode)));
    end
    if strcmpi(rf_out_mode, 'multibit')
        cfg.mash.rf_output_mode = 'multibit';
    else
        cfg.mash.rf_output_mode = 'pm1';
    end
end

t0 = tic;
r = run_chain_if200_osr16_v1(cfg);
dt = toc(t0);
r0 = r(1);

if strcmpi(alg, 'ef4')
    m_all = r0.metrics.ef4;
    d = r0.overflow.ef4;
else
    m_all = r0.metrics.mash22;
    d = r0.overflow.mash22;
end
[m_use, md] = pick_metric_source(m_all);

row = struct();
row.A_used = A_used;
row.EVM_percent = m_use.EVM_percent;
row.SNDR_dB = m_use.SNDR_dB;
row.ACLR_dBc = m_use.ACLR_avg_dBc;
row.ov = d.ov_count;
row.sat = d.sat_hi + d.sat_lo;
row.ofdm_valid = metric_ofdm_valid(m_use);
row.metric_domain = string(md);
row.runtime_s = dt;
end

function cfg = inject_ef4_coeff(cfg, Hinf, coeff_q)
ntf = synthesizeNTF(4, cfg.osr_main, 1, Hinf);
[z, p, k] = zpkdata(ntf, 'v');
b = real(k * poly(z));
a = real(poly(p));
if abs(a(1) - 1) > 1e-12
    b = b / a(1);
    a = a / a(1);
end
L = max(numel(a), numel(b));
den = [a(:).' zeros(1, L - numel(a))];
b_pad = [b(:).' zeros(1, L - numel(b))];
num = den - b_pad;
num(1) = 0;

cfg.ef4 = struct();
cfg.ef4.acc_w = 40;
cfg.ef4.saturate = true;
cfg.ef4.coeff_shift = coeff_q;
cfg.ef4.num_q = int64(round(num(2:end) * (2^coeff_q)));
cfg.ef4.den_q = int64(round(den(2:end) * (2^coeff_q)));
end

function cfg = build_routeb_select_cfg(c_common, rb_cfg)
cfg = c_common;
cfg.metrics.domain = 'bb';
cfg.metrics.primary = 'bb';
cfg.metrics.aclr_domain = 'bb';
cfg.metrics.print_rf_final = false;
cfg.rf_final.enable = false;

cfg.fixed_A = rb_cfg.fixed_A;
cfg.include_mash11 = logical(rb_cfg.include_mash11);
cfg.auto = struct();
cfg.auto.A_list_by_alg = rb_cfg.A_list_by_alg;
end

function [best_rec, best_alg] = pick_best_routeb_record(records)
if isempty(records)
    error('RouteB records are empty.');
end
best_idx = 1;
best_evm = inf;
best_sndr = -inf;
for i = 1:numel(records)
    r = records{i};
    evm = r.auto.EVM_percent;
    sndr = r.auto.SNDR_dB;
    if evm < best_evm || (abs(evm - best_evm) <= 1e-12 && sndr > best_sndr)
        best_idx = i;
        best_evm = evm;
        best_sndr = sndr;
    end
end
best_rec = records{best_idx};
best_alg = char(best_rec.alg);
end

function best_row = pick_best_eval_row(rows)
idx = [];
for i = 1:numel(rows)
    r = rows{i};
    clean = (r.ov == 0) && (r.sat == 0) && isfinite(r.EVM_percent) && isfinite(r.SNDR_dB);
    if clean && logical(r.ofdm_valid)
        idx(end+1) = i; %#ok<AGROW>
    end
end
if isempty(idx)
    for i = 1:numel(rows)
        r = rows{i};
        clean = (r.ov == 0) && (r.sat == 0) && isfinite(r.EVM_percent) && isfinite(r.SNDR_dB);
        if clean
            idx(end+1) = i; %#ok<AGROW>
        end
    end
end
if isempty(idx)
    idx = 1:numel(rows);
end

best_i = idx(1);
best_evm = inf;
best_sndr = -inf;
for k = 1:numel(idx)
    i = idx(k);
    r = rows{i};
    if r.EVM_percent < best_evm || (abs(r.EVM_percent - best_evm) <= 1e-12 && r.SNDR_dB > best_sndr)
        best_i = i;
        best_evm = r.EVM_percent;
        best_sndr = r.SNDR_dB;
    end
end
best_row = rows{best_i};
end

function [m_use, md] = pick_metric_source(m)
if isfield(m, 'rf_final_digital')
    m_use = m.rf_final_digital;
    md = 'rf_final_digital';
elseif isfield(m, 'rf_final')
    m_use = m.rf_final;
    md = 'rf_final';
elseif isfield(m, 'bb')
    m_use = m.bb;
    md = 'bb';
else
    m_use = m;
    md = 'main';
end
end

function tf = metric_ofdm_valid(m)
tf = true;
if isstruct(m)
    if isfield(m, 'ofdm_eval') && isstruct(m.ofdm_eval) && isfield(m.ofdm_eval, 'valid')
        tf = logical(m.ofdm_eval.valid);
    elseif isfield(m, 'OFDM_valid')
        tf = logical(m.OFDM_valid);
    end
end
end

function row = make_row(bw_hz, cfg, route, design, metric_domain, alpha3, A, evm, sndr, aclr, ov, sat, ofdm_valid, runtime_s)
row = struct();
row.BW_MHz = bw_hz/1e6;
row.Route = string(route);
row.Design = string(design);
row.MetricDomain = string(metric_domain);
row.pa_alpha3 = alpha3;
row.A_used = A;
row.EVM_percent = evm;
row.SNDR_dB = sndr;
row.ACLR_dBc = aclr;
row.Overflow = ov;
row.Sat = sat;
row.OfdmValid = logical(ofdm_valid);
row.Runtime_s = runtime_s;
row.Profile = string(cfg.profile);
row.IsQuick = strcmpi(char(cfg.profile), 'quick');
row.fc_rf_GHz = cfg.industrial.fc_rf_hz/1e9;
row.Fs_eq_Gbps = cfg.industrial.fs_eq_hz/1e9;
row.lanes = cfg.industrial.lanes;
row.R_lane_Gbps = cfg.industrial.r_lane_hz/1e9;
row.DDR_clk_MHz = cfg.industrial.ddr_clk_hz/1e6;
end

function T = cellrows_to_table(rows)
if isempty(rows)
    T = table();
else
    T = struct2table(vertcat(rows{:}));
end
end

function s = apply_cfg_overrides(s, o)
if ~isstruct(o)
    return;
end
f = fieldnames(o);
for i = 1:numel(f)
    k = f{i};
    if isstruct(o.(k)) && isfield(s, k) && isstruct(s.(k))
        s.(k) = apply_cfg_overrides(s.(k), o.(k));
    else
        s.(k) = o.(k);
    end
end
end

function mkpath(p)
if ~exist(p, 'dir')
    mkdir(p);
end
end
