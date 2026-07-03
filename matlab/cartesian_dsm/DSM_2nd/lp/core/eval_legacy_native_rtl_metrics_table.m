function T = eval_legacy_native_rtl_metrics_table(xsim_dir, coe_i, coe_q, meta_in, out_csv)
% eval_legacy_native_rtl_metrics_table
% Evaluate the legacy RTL simulations in their native implementation domains:
%   LPDSM / EFDSM1 / EFDSM2 / EFDSM3 / EFDSM4  -> 1-bit complex baseband sign outputs
%   MASH11/22/111_MB         -> native multibit yout outputs

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
        'legacy_native_rtl_metrics_table.csv');
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
    'LPDSM',      'bb_sign1bit',       'sim_bits_01.txt'; ...
    'EFDSM1',     'bb_sign1bit',       'sim_bits_01_ef1.txt'; ...
    'DSM2_CLASSIC','bb_sign1bit',      'sim_bits_01_dsm2.txt'; ...
    'EFDSM2',     'bb_sign1bit',       'sim_bits_01_ef2.txt'; ...
    'EFDSM3',     'bb_sign1bit',       'sim_bits_01_ef3.txt'; ...
    'EFDSM4',     'bb_sign1bit',       'sim_bits_01_ef4.txt'; ...
    'MASH11_MB',  'bb_multibit_yout',  'sim_yout_signed_mash11_mb.txt'; ...
    'MASH22_MB',  'bb_multibit_yout',  'sim_yout_signed_mash22_mb.txt'; ...
    'MASH111_MB', 'bb_multibit_yout',  'sim_yout_signed_mash111_mb.txt' ...
};

rows = repmat(struct( ...
    'Design', "", ...
    'MetricDomain', "", ...
    'NativeScale', NaN, ...
    'N_bits', 0, ...
    'N_rec', 0, ...
    'EVM_percent', NaN, ...
    'SNDR_dB', NaN, ...
    'PAPR_BBrec_dB', NaN, ...
    'ACLR_L_dBc', NaN, ...
    'ACLR_R_dBc', NaN, ...
    'ACLR_avg_dBc', NaN), ...
    size(designs, 1), 1);

for k = 1:size(designs, 1)
    design_name = string(designs{k,1});
    metric_domain = string(designs{k,2});
    dump_file = fullfile(xsim_dir, designs{k,3});
    must_exist_file(dump_file);

    [y_bb, scale_used] = read_native_bb_dump(dump_file, metric_domain);
    [y_bb, x_ref_now] = align_dump_to_input(y_bb, x_ref);

    recCfg = struct( ...
        'OSR', meta.OSR, ...
        'Fs_dsm', meta.Fs_dsm, ...
        'Fs_bb', meta.Fs_bb, ...
        'BWch', BWch, ...
        'StopAtt', 80, ...
        'UseFastFir', false, ...
        'ZeroPhase', false);
    [y_rec, x_ref_bb] = lp_reconstruct_and_decimate(y_bb, x_ref_now, recCfg);
    al = lp_align_and_ls_gain(y_rec, x_ref_bb);
    [y_al, x_al] = lp_discard_settle_pair(al.y_aligned, al.x_aligned, 64);
    m = lp_calc_sndr_evm(y_al, x_al);

    psdCfg = default_psd_cfg(numel(y_bb));
    ac = lp_calc_acpr_aclr_from_psd(y_bb, meta.Fs_dsm, BWch, adjOffset, psdCfg);

    rows(k).Design = design_name;
    rows(k).MetricDomain = metric_domain;
    rows(k).NativeScale = scale_used;
    rows(k).N_bits = numel(y_bb);
    rows(k).N_rec = numel(y_al);
    rows(k).EVM_percent = m.EVM_rms_percent;
    rows(k).SNDR_dB = m.SNDR_dB;
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

function [y_bb, scale_used] = read_native_bb_dump(fp, metric_domain)
switch lower(char(metric_domain))
    case 'bb_sign1bit'
        M = readmatrix(fp, 'FileType', 'text');
        if isempty(M) || size(M,2) < 2 || all(isnan(M(:)))
            fid = fopen(fp, 'r');
            if fid < 0
                error('Cannot open %s', fp);
            end
            c = textscan(fid, '%f %f', 'Delimiter', {' ', sprintf('\t'), ','}, ...
                'MultipleDelimsAsOne', true);
            fclose(fid);
            M = [c{1}, c{2}];
        end
        M = round(M(:,1:2));
        yi = 2 * M(:,1) - 1;
        yq = 2 * M(:,2) - 1;
        y_bb = yi + 1j * yq;
        scale_used = 1;

    case 'bb_multibit_yout'
        M = readmatrix(fp, 'FileType', 'text');
        if isempty(M) || size(M,2) < 2 || all(isnan(M(:)))
            fid = fopen(fp, 'r');
            if fid < 0
                error('Cannot open %s', fp);
            end
            c = textscan(fid, '%f %f', 'Delimiter', {' ', sprintf('\t'), ','}, ...
                'MultipleDelimsAsOne', true);
            fclose(fid);
            M = [c{1}, c{2}];
        end
        M = round(M(:,1:2));
        yi = double(M(:,1));
        yq = double(M(:,2));
        scale_used = max(1, max(abs([yi; yq])));
        y_bb = (yi + 1j * yq) / scale_used;

    otherwise
        error('Unsupported metric domain: %s', metric_domain);
end
end

function [y_aligned, x_aligned] = align_dump_to_input(y_bb, x_ref)
% The behavioral TBs sample native RTL outputs on the same rising edge as
% sample_valid, so the dumped DSM/yout sequence is delayed by one sample
% relative to the ROM input stream. Drop that first dumped sample to align
% the sequence with x_ref before reconstruction/metric evaluation.
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

fprintf(fid, '| Design | Domain | EVM (%%) | SNDR (dB) | PAPR_BBrec (dB) | ACLR_L (dBc) | ACLR_R (dBc) | ACLR_avg (dBc) |\n');
fprintf(fid, '|---|---|---:|---:|---:|---:|---:|---:|\n');
for k = 1:height(T)
    fprintf(fid, '| %s | %s | %.4f | %.4f | %.4f | %.4f | %.4f | %.4f |\n', ...
        T.Design(k), T.MetricDomain(k), T.EVM_percent(k), T.SNDR_dB(k), ...
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
