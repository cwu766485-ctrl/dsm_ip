function out = run_rtl_regression_cov_v1(profile, cfg_in)
% run_rtl_regression_cov_v1
% Regression + basic coverage for industrial RTL closure.
%
% What it runs:
%   1) RouteA EFDSM4 one-click RTL<->MATLAB compare
%   2) RouteB MASH111 one-click RTL<->MATLAB compare
%   3) RouteB MASH22 one-click RTL<->MATLAB compare
%
% For each case/seed, exports:
%   - pass/fail table
%   - basic signal coverage (binary symbol/toggling occupancy)
%   - aggregate coverage summary
%
% Usage:
%   out = run_rtl_regression_cov_v1();
%   out = run_rtl_regression_cov_v1('quick');
%   out = run_rtl_regression_cov_v1('quick', struct('seeds',[7 17]));
%   out = run_rtl_regression_cov_v1('long', struct('seeds',7));

if nargin < 1 || isempty(profile)
    profile = 'quick';
end
if nargin < 2
    cfg_in = struct();
end

cfg = default_cfg(profile);
cfg = apply_cfg_overrides(cfg, cfg_in);
cfg = finalize_cfg(cfg);

root_lp = fileparts(mfilename('fullpath'));
stamp = datestr(now, 'yyyymmdd_HHMMSS');
exp_name = ['rtl_regression_cov_v1_' stamp];
out_dir = fullfile(root_lp, 'results', exp_name);
if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
end

fprintf('\n=== RTL Regression + Basic Coverage (%s) ===\n', upper(char(cfg.profile)));
fprintf('Seeds: %s\n', mat2str(cfg.seeds));
fprintf('Designs: EFDSM4 + MASH111 + MASH22\n');

run_rows = [];
t_start = tic;
ckpt_csv = fullfile(out_dir, 'regression_runs_checkpoint.csv');
ckpt_mat = fullfile(out_dir, 'regression_checkpoint.mat');

for is = 1:numel(cfg.seeds)
    seed = cfg.seeds(is);
    fprintf('\n[Seed %d]\n', seed);

    % RouteA EFDSM4
    try
        cA = struct('random_seed', seed, 'run_full_checker', cfg.routeA_run_full_checker);
        outA = run_routeA_rtl_matlab_oneclick_compare_v1(char(cfg.profile), cA);
        run_rows = [run_rows; collect_row_routeA(outA, seed)]; %#ok<AGROW>
    catch ME
        run_rows = [run_rows; error_row("EFDSM4", "RouteA", seed, cfg.profile, ME.message)]; %#ok<AGROW>
    end
    checkpoint_write(run_rows, ckpt_csv, ckpt_mat);

    % RouteB MASH111
    try
        cB111 = struct('random_seed', seed);
        outB111 = run_routeB_rtl_matlab_oneclick_compare_v1('mash111', char(cfg.profile), cB111);
        run_rows = [run_rows; collect_row_routeB(outB111, seed, "MASH111")]; %#ok<AGROW>
    catch ME
        run_rows = [run_rows; error_row("MASH111", "RouteB", seed, cfg.profile, ME.message)]; %#ok<AGROW>
    end
    checkpoint_write(run_rows, ckpt_csv, ckpt_mat);

    % RouteB MASH22
    try
        cB22 = struct('random_seed', seed);
        outB22 = run_routeB_rtl_matlab_oneclick_compare_v1('mash22', char(cfg.profile), cB22);
        run_rows = [run_rows; collect_row_routeB(outB22, seed, "MASH22")]; %#ok<AGROW>
    catch ME
        run_rows = [run_rows; error_row("MASH22", "RouteB", seed, cfg.profile, ME.message)]; %#ok<AGROW>
    end
    checkpoint_write(run_rows, ckpt_csv, ckpt_mat);
end

T_runs = struct2table(run_rows);
T_runs.Pass = build_pass_flag(T_runs, cfg);

T_cov = build_coverage_summary(T_runs, cfg);

main_csv = fullfile(out_dir, 'regression_runs.csv');
cov_csv = fullfile(out_dir, 'coverage_summary.csv');
writetable(T_runs, main_csv);
writetable(T_cov, cov_csv);

md_file = fullfile(out_dir, 'regression_report.md');
write_report_md(md_file, cfg, T_runs, T_cov, toc(t_start), main_csv, cov_csv);

out = struct();
out.output_dir = out_dir;
out.cfg = cfg;
out.tables = struct('runs', T_runs, 'coverage', T_cov);
out.files = struct('runs_csv', main_csv, 'coverage_csv', cov_csv, 'report_md', md_file);

save(fullfile(out_dir, 'rtl_regression_cov_v1.mat'), 'out');

fprintf('\nDone.\n  %s\n  %s\n  %s\n', main_csv, cov_csv, md_file);
end

function cfg = default_cfg(profile)
cfg = struct();
cfg.profile = lower(string(profile));
if ~(cfg.profile == "quick" || cfg.profile == "long")
    error('profile must be quick/long');
end
cfg.seeds = 7;
cfg.routeA_run_full_checker = false;
cfg.max_abs_delta_evm_pct = 0.20;
cfg.max_abs_delta_sndr_db = 0.30;
cfg.max_abs_delta_aclr_db = 1.00;
cfg.qam256_evm_limit_pct = 3.5;
end

function cfg = apply_cfg_overrides(cfg, in)
if ~isstruct(in)
    return;
end
f = fieldnames(in);
for i = 1:numel(f)
    cfg.(f{i}) = in.(f{i});
end
end

function cfg = finalize_cfg(cfg)
cfg.seeds = double(cfg.seeds(:)).';
cfg.seeds = unique(round(cfg.seeds));
cfg.seeds = cfg.seeds(isfinite(cfg.seeds));
if isempty(cfg.seeds)
    cfg.seeds = 7;
end
end

function r = collect_row_routeA(outA, seed)
pm = outA.paper.matlab;
pr = outA.paper.rtl;
bf = NaN;
if isfield(outA, 'bittrue') && isfield(outA.bittrue, 'pass')
    bf = outA.bittrue.pass;
end

[sig_cov, rf_cov] = coverage_binary_bits(outA.files.rtl_bits, outA.files.rtl_rf_bits);

r = struct();
r.Design = "EFDSM4";
r.Route = "RouteA";
r.Seed = seed;
r.Profile = string(outA.profile);
r.PaperValid_MAT = pm.PaperValid;
r.PaperValid_RTL = pr.PaperValid;
r.BittruePass = bf;
r.EVM_MAT_pct = pm.EVM_percent;
r.EVM_RTL_pct = pr.EVM_percent;
r.SNDR_MAT_dB = pm.SNDR_dB;
r.SNDR_RTL_dB = pr.SNDR_dB;
r.ACLR_MAT_dBc = pm.ACLR_avg_dBc;
r.ACLR_RTL_dBc = pr.ACLR_avg_dBc;
r.Delta_EVM_pct = pr.EVM_percent - pm.EVM_percent;
r.Delta_SNDR_dB = pr.SNDR_dB - pm.SNDR_dB;
r.Delta_ACLR_dB = pr.ACLR_avg_dBc - pm.ACLR_avg_dBc;
r.QAM256_OK_RTL = double(isfinite(pr.EVM_percent) && pr.EVM_percent <= 3.5);
r.Cov_I_has0 = sig_cov.I_has0;
r.Cov_I_has1 = sig_cov.I_has1;
r.Cov_Q_has0 = sig_cov.Q_has0;
r.Cov_Q_has1 = sig_cov.Q_has1;
r.Cov_RF_has0 = rf_cov.has0;
r.Cov_RF_has1 = rf_cov.has1;
r.Cov_Y_neg = NaN;
r.Cov_Y_zero = NaN;
r.Cov_Y_pos = NaN;
r.Runtime_MAT_s = outA.runtime.matlab_s;
r.Runtime_VIVADO_s = outA.runtime.vivado_s;
r.Runtime_RTL_EVAL_s = outA.runtime.rtl_eval_s;
r.OutputDir = string(outA.output_dir);
end

function r = collect_row_routeB(outB, seed, design_name)
pm = outB.paper.matlab;
pr = outB.paper.rtl;
bf = NaN;
if isfield(outB, 'bittrue') && isfield(outB.bittrue, 'pass')
    bf = outB.bittrue.pass;
end

[y_cov, rf_cov] = coverage_multibit_y(outB.files.rtl_yout, outB.files.rtl_rf_bits);

r = struct();
r.Design = string(design_name);
r.Route = "RouteB";
r.Seed = seed;
r.Profile = string(outB.profile);
r.PaperValid_MAT = pm.PaperValid;
r.PaperValid_RTL = pr.PaperValid;
r.BittruePass = bf;
r.EVM_MAT_pct = pm.EVM_percent;
r.EVM_RTL_pct = pr.EVM_percent;
r.SNDR_MAT_dB = pm.SNDR_dB;
r.SNDR_RTL_dB = pr.SNDR_dB;
r.ACLR_MAT_dBc = pm.ACLR_avg_dBc;
r.ACLR_RTL_dBc = pr.ACLR_avg_dBc;
r.Delta_EVM_pct = pr.EVM_percent - pm.EVM_percent;
r.Delta_SNDR_dB = pr.SNDR_dB - pm.SNDR_dB;
r.Delta_ACLR_dB = pr.ACLR_avg_dBc - pm.ACLR_avg_dBc;
r.QAM256_OK_RTL = double(isfinite(pr.EVM_percent) && pr.EVM_percent <= 3.5);
r.Cov_I_has0 = NaN;
r.Cov_I_has1 = NaN;
r.Cov_Q_has0 = NaN;
r.Cov_Q_has1 = NaN;
r.Cov_RF_has0 = rf_cov.has0;
r.Cov_RF_has1 = rf_cov.has1;
r.Cov_Y_neg = y_cov.has_neg;
r.Cov_Y_zero = y_cov.has_zero;
r.Cov_Y_pos = y_cov.has_pos;
r.Runtime_MAT_s = outB.runtime.matlab_s;
r.Runtime_VIVADO_s = outB.runtime.vivado_s;
r.Runtime_RTL_EVAL_s = outB.runtime.rtl_eval_s;
r.OutputDir = string(outB.output_dir);
end

function pass = build_pass_flag(T, cfg)
n = height(T);
pass = false(n,1);
for i = 1:n
    valid_ok = (T.PaperValid_MAT(i) == 1) && (T.PaperValid_RTL(i) == 1);
    bittrue_ok = true;
    if isfinite(T.BittruePass(i))
        bittrue_ok = (T.BittruePass(i) == 1);
    end
    delta_ok = isfinite(T.Delta_EVM_pct(i)) && isfinite(T.Delta_SNDR_dB(i)) && isfinite(T.Delta_ACLR_dB(i)) && ...
               (abs(T.Delta_EVM_pct(i)) <= cfg.max_abs_delta_evm_pct) && ...
               (abs(T.Delta_SNDR_dB(i)) <= cfg.max_abs_delta_sndr_db) && ...
               (abs(T.Delta_ACLR_dB(i)) <= cfg.max_abs_delta_aclr_db);
    qam_ok = (T.QAM256_OK_RTL(i) == 1);
    pass(i) = valid_ok && bittrue_ok && delta_ok && qam_ok;
end
end

function T_cov = build_coverage_summary(T_runs, cfg)
designs = unique(T_runs.Design, 'stable');
rows = [];
for i = 1:numel(designs)
    d = designs(i);
    idx = (T_runs.Design == d);
    Td = T_runs(idx,:);
    n_total = height(Td);
    n_pass = sum(Td.Pass == 1);
    n_valid = sum((Td.PaperValid_MAT == 1) & (Td.PaperValid_RTL == 1));
    n_qam = sum(Td.QAM256_OK_RTL == 1);
    if any(isfinite(Td.BittruePass))
        n_bt = sum(Td.BittruePass == 1);
        bt_cov = n_bt / n_total;
    else
        bt_cov = NaN;
    end
    seed_cov = numel(unique(Td.Seed)) / numel(cfg.seeds);

    if d == "EFDSM4"
        sig_cov = mean(double((Td.Cov_I_has0==1)&(Td.Cov_I_has1==1)&(Td.Cov_Q_has0==1)&(Td.Cov_Q_has1==1)));
    else
        sig_cov = mean(double((Td.Cov_Y_neg==1)&(Td.Cov_Y_zero==1)&(Td.Cov_Y_pos==1)));
    end
    rf_cov = mean(double((Td.Cov_RF_has0==1)&(Td.Cov_RF_has1==1)));

    r = struct();
    r.Design = d;
    r.Cases_Total = n_total;
    r.Cases_Pass = n_pass;
    r.Pass_Rate = n_pass / max(1,n_total);
    r.Seed_Coverage = seed_cov;
    r.ValidMetric_Coverage = n_valid / max(1,n_total);
    r.QAM256_EVM_Coverage = n_qam / max(1,n_total);
    r.Bittrue_Coverage = bt_cov;
    r.Signal_Coverage = sig_cov;
    r.RF_Bit_Coverage = rf_cov;
    rows = [rows; r]; %#ok<AGROW>
end
T_cov = struct2table(rows);
end

function write_report_md(md_file, cfg, T_runs, T_cov, runtime_s, main_csv, cov_csv)
fid = fopen(md_file, 'w');
if fid < 0
    return;
end

fprintf(fid, '# RTL Regression + Basic Coverage Report\n\n');
fprintf(fid, '- Profile: `%s`\n', char(cfg.profile));
fprintf(fid, '- Seeds: `%s`\n', mat2str(cfg.seeds));
fprintf(fid, '- Runtime: `%.2f s`\n', runtime_s);
fprintf(fid, '- Runs CSV: `%s`\n', main_csv);
fprintf(fid, '- Coverage CSV: `%s`\n\n', cov_csv);

fprintf(fid, '## Coverage Summary\n\n');
fprintf(fid, '| Design | Cases | Pass | PassRate | SeedCov | ValidMetricCov | QAM256Cov | BittrueCov | SignalCov | RFBitCov |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:height(T_cov)
    fprintf(fid, '| %s | %d | %d | %.3f | %.3f | %.3f | %.3f | %s | %.3f | %.3f |\n', ...
        string(T_cov.Design(i)), ...
        T_cov.Cases_Total(i), T_cov.Cases_Pass(i), T_cov.Pass_Rate(i), ...
        T_cov.Seed_Coverage(i), T_cov.ValidMetric_Coverage(i), T_cov.QAM256_EVM_Coverage(i), ...
        num2str_nan(T_cov.Bittrue_Coverage(i)), ...
        T_cov.Signal_Coverage(i), T_cov.RF_Bit_Coverage(i));
end

fprintf(fid, '\n## Run Matrix (Top)\n\n');
fprintf(fid, '| Design | Seed | Pass | EVM_RTL(%%) | SNDR_RTL(dB) | ACLR_RTL(dBc) | dEVM | dSNDR | dACLR |\n');
fprintf(fid, '|---|---:|---:|---:|---:|---:|---:|---:|---:|\n');
for i = 1:min(height(T_runs), 24)
    fprintf(fid, '| %s | %d | %d | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        string(T_runs.Design(i)), T_runs.Seed(i), T_runs.Pass(i), ...
        T_runs.EVM_RTL_pct(i), T_runs.SNDR_RTL_dB(i), T_runs.ACLR_RTL_dBc(i), ...
        T_runs.Delta_EVM_pct(i), T_runs.Delta_SNDR_dB(i), T_runs.Delta_ACLR_dB(i));
end

fclose(fid);
end

function s = num2str_nan(v)
if isnan(v)
    s = 'NaN';
else
    s = sprintf('%.3f', v);
end
end

function [cov2, covrf] = coverage_binary_bits(bits_file, rf_file)
xy = read_matrix_int(bits_file, 2);
rf = read_matrix_int(rf_file, 1);

I = xy(:,1);
Q = xy(:,2);
R = rf(:,1);

cov2 = struct();
cov2.I_has0 = double(any(I == 0));
cov2.I_has1 = double(any(I == 1));
cov2.Q_has0 = double(any(Q == 0));
cov2.Q_has1 = double(any(Q == 1));

covrf = struct();
covrf.has0 = double(any(R == 0));
covrf.has1 = double(any(R == 1));
end

function [covy, covrf] = coverage_multibit_y(y_file, rf_file)
y = read_matrix_int(y_file, 2);
rf = read_matrix_int(rf_file, 1);

yi = y(:,1);
yq = y(:,2);
ym = [yi; yq];

covy = struct();
covy.has_neg = double(any(ym < 0));
covy.has_zero = double(any(ym == 0));
covy.has_pos = double(any(ym > 0));

R = rf(:,1);
covrf = struct();
covrf.has0 = double(any(R == 0));
covrf.has1 = double(any(R == 1));
end

function A = read_matrix_int(p, ncol)
must_exist(p);
v = readmatrix(p, 'FileType', 'text');
if isempty(v)
    A = zeros(0,ncol);
    return;
end
if size(v,2) < ncol
    error('File %s has %d columns, expected >= %d', p, size(v,2), ncol);
end
A = int32(v(:,1:ncol));
end

function r = error_row(design, route, seed, profile, msg)
r = struct();
r.Design = string(design);
r.Route = string(route);
r.Seed = seed;
r.Profile = string(profile);
r.PaperValid_MAT = 0;
r.PaperValid_RTL = 0;
r.BittruePass = NaN;
r.EVM_MAT_pct = NaN;
r.EVM_RTL_pct = NaN;
r.SNDR_MAT_dB = NaN;
r.SNDR_RTL_dB = NaN;
r.ACLR_MAT_dBc = NaN;
r.ACLR_RTL_dBc = NaN;
r.Delta_EVM_pct = NaN;
r.Delta_SNDR_dB = NaN;
r.Delta_ACLR_dB = NaN;
r.QAM256_OK_RTL = 0;
r.Cov_I_has0 = NaN;
r.Cov_I_has1 = NaN;
r.Cov_Q_has0 = NaN;
r.Cov_Q_has1 = NaN;
r.Cov_RF_has0 = NaN;
r.Cov_RF_has1 = NaN;
r.Cov_Y_neg = NaN;
r.Cov_Y_zero = NaN;
r.Cov_Y_pos = NaN;
r.Runtime_MAT_s = NaN;
r.Runtime_VIVADO_s = NaN;
r.Runtime_RTL_EVAL_s = NaN;
r.OutputDir = string("ERROR: " + string(msg));
end

function checkpoint_write(run_rows, ckpt_csv, ckpt_mat)
if isempty(run_rows)
    return;
end
T = struct2table(run_rows);
writetable(T, ckpt_csv);
save(ckpt_mat, 'run_rows');
end

function must_exist(p)
if exist(p, 'file') ~= 2
    error('Missing file: %s', p);
end
end
