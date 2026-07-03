function results = run_chain_if200_osr16_v1(cfg_in)
% run_chain_if200_osr16_v1
% Route-A Stage-1 end-to-end MATLAB chain (corrected order):
%   1) Practical OFDM baseband generation (10/15 MHz class)
%   2) Cartesian LPDSM on I/Q (EF2 / EF4-IIR / MASH2-2)
%   3) DUC upconversion (rtl_fs4 or ideal_lo)
%   4) PSD / ACLR / EVM metrics
%   5) COE export for RTL ROM input (I/Q)
%
% Note:
%   Main run uses OSR=32:
%       Fs_bb  = 15.36 MHz
%       Fs_dsm = 491.52 MHz
%   DUC mode:
%       rtl_fs4 -> fc=Fs_dsm/4 (bit-true to RTL duc_fs4_merge)
%       ideal_lo -> fc=cfg.fc_req_hz (arbitrary LO for system exploration)

clc;
close all;

cfg = default_cfg();
if nargin >= 1 && ~isempty(cfg_in)
    cfg = apply_cfg_overrides(cfg, cfg_in);
end
cfg = apply_debug_profile(cfg);
cfg = refresh_derived_cfg(cfg);
validate_cfg(cfg);
if ~isfield(cfg, 'random_seed') || isempty(cfg.random_seed)
    cfg.random_seed = 7;
end
rng(cfg.random_seed, 'twister');

root = fileparts(mfilename('fullpath'));
out_fig = fullfile(root, 'figs', cfg.exp_name);
out_res = fullfile(root, 'results', cfg.exp_name);
out_coe = fullfile(root, 'coe');
mkpath(out_fig);
mkpath(out_res);
mkpath(out_coe);
disable_save = isfield(cfg, 'debug') && isfield(cfg.debug, 'disable_save') && cfg.debug.disable_save;

fprintf('=== Route-A Stage-1 Chain (Cartesian LPDSM then IF DUC) ===\n');
fprintf('Fs_bb=%.3f MHz, Fs_dsm(main)=%.3f MHz, fc=%.3f MHz\n', ...
    cfg.Fs_bb/1e6, cfg.Fs_dsm_main/1e6, cfg.fc_hz/1e6);
fprintf('Random seed=%d\n', cfg.random_seed);
if isfield(cfg, 'fc_req_hz')
    fprintf('DUC mode=%s, fc_req=%.3f MHz, fc_used=%.3f MHz\n', ...
        cfg.rf_mode, cfg.fc_req_hz/1e6, cfg.fc_hz/1e6);
end
fprintf('BW targets (MHz): %s\n', mat2str(cfg.bw_targets_hz(:).' / 1e6, 4));
fprintf('ACLR adjacent offset: %.3f MHz\n', cfg.aclr_adj_offset_hz/1e6);
fprintf('Enabled algs: EF2=%d EF4=%d MASH2-2=%d\n', ...
    cfg.alg_enable.ef2, cfg.alg_enable.ef4, cfg.alg_enable.mash22);
if cfg.alg_enable.mash22
    fprintf('MASH variant: %s\n', mash_display_name(mash_variant_name(cfg)));
end

duc_diag = struct();
if isfield(cfg, 'rf_final') && isfield(cfg.rf_final, 'duc_consistency_test') && ...
        isfield(cfg.rf_final.duc_consistency_test, 'enable') && cfg.rf_final.duc_consistency_test.enable
    duc_diag = run_duc_consistency_test(cfg);
    fprintf('DUC unit-test: corr=%.4f | mode=%s | EVM=%.2f%% | pass=%d\n', ...
        duc_diag.corr_abs, duc_diag.best_mode, duc_diag.evm_percent, duc_diag.pass);
end

n_cases = numel(cfg.bw_targets_hz);
results = repmat(struct(), n_cases, 1);
x_bb_ref = [];

for k = 1:n_cases
    bw_tgt = cfg.bw_targets_hz(k);
    active_sc = calc_active_subcarriers(cfg.Nfft, cfg.delta_f, bw_tgt);
    bw_eff = active_sc * cfg.delta_f;

    [x_bb, bb_meta] = gen_ofdm_bb_qam(cfg, active_sc, bw_eff);
    [x_osr, osr_meta] = osr_interpolate(x_bb, cfg.osr_main, cfg.Fs_bb, bw_eff, cfg.fast_mode);
    x_osr = x_osr / max(rms(x_osr), eps);

    backoff_use = cfg.input_backoff;
    auto_bo = struct('enabled', false);
    if cfg.alg_enable.ef4 && isfield(cfg, 'ef4_autobackoff') && isfield(cfg.ef4_autobackoff, 'enable') && cfg.ef4_autobackoff.enable
        auto_bo = ef4_autotune_input_backoff(x_osr, bw_eff, cfg);
        backoff_use = auto_bo.backoff_sel;
    end
    x_ref_osr = backoff_use * x_osr;

    [i_i16, q_i16, x_ref_clip] = quantize_iq_q15(x_ref_osr, cfg.input_clip);
    i_i64 = int64(i_i16);
    q_i64 = int64(q_i16);
    use_rm_fs4 = strcmpi(cfg.rf_mode, 'rtl_fs4_rate_matched');
    is_stage1_routea = ~(isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable);
    need_rm_obs = strcmpi(cfg.rf_mode, 'rtl_fs4') && is_stage1_routea && ...
        isfield(cfg, 'rf_final') && getfield_default(cfg.rf_final, 'stage1_halfrate_fallback_enable', false);
    if use_rm_fs4
        i_i64_h = i_i64(1:2:end);
        q_i64_h = q_i64(1:2:end);
    elseif need_rm_obs
        i_i64_h = i_i64(1:2:end);
        q_i64_h = q_i64(1:2:end);
    else
        i_i64_h = int64([]);
        q_i64_h = int64([]);
    end

    % Input IF spectrum (before DSM), for Fig2 reference
    x_if_in = duc_to_if_real(x_ref_clip, cfg.fc_hz, cfg.Fs_dsm_main);

    yI_ef2 = []; yQ_ef2 = []; yrf_ef2 = []; yrf_ef2_rm = []; dbg_ef2 = empty_dbg(); met_ef2 = struct(); Pef2 = [];
    yI_ef4 = []; yQ_ef4 = []; yrf_ef4 = []; yrf_ef4_rm = []; dbg_ef4 = empty_dbg(); met_ef4 = struct(); Pef4 = []; arch_ef4 = struct();
    yI_m22 = []; yQ_m22 = []; yrf_m22 = []; yrf_m22_rm = []; dbg_m22 = empty_dbg(); met_m22 = struct(); Pm22 = [];
    mash_tag = mash_variant_name(cfg);
    mash_name = mash_display_name(mash_tag);

    if cfg.alg_enable.ef2
        [yI_ef2, dbgI_ef2] = ef2_fixed_model(i_i64, cfg.ef2.acc_w, cfg.ef2.saturate, cfg.ef2.b1, cfg.ef2.b2);
        [yQ_ef2, dbgQ_ef2] = ef2_fixed_model(q_i64, cfg.ef2.acc_w, cfg.ef2.saturate, cfg.ef2.b1, cfg.ef2.b2);
        if use_rm_fs4 || need_rm_obs
            [yI_ef2_rf, ~] = ef2_fixed_model(i_i64_h, cfg.ef2.acc_w, cfg.ef2.saturate, cfg.ef2.b1, cfg.ef2.b2);
            [yQ_ef2_rf, ~] = ef2_fixed_model(q_i64_h, cfg.ef2.acc_w, cfg.ef2.saturate, cfg.ef2.b1, cfg.ef2.b2);
            yrf_ef2_rm = synth_rf_from_iq_pm1(yI_ef2_rf, yQ_ef2_rf, cfg.fc_hz, cfg.Fs_dsm_main, 'rtl_fs4_rate_matched');
            if use_rm_fs4
                yrf_ef2 = yrf_ef2_rm;
            else
                yrf_ef2 = synth_rf_from_iq_pm1(yI_ef2, yQ_ef2, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
            end
        else
            yrf_ef2 = synth_rf_from_iq_pm1(yI_ef2, yQ_ef2, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
        end
        dbg_ef2 = merge_dbg(dbgI_ef2, dbgQ_ef2);
        met_ef2 = eval_if_metrics_dual(yrf_ef2, yI_ef2, yQ_ef2, x_ref_clip, cfg.Fs_dsm_main, cfg.Fs_bb, cfg.osr_main, cfg.fc_hz, bw_eff, cfg, yrf_ef2_rm);
    end

    if cfg.alg_enable.ef4
        ext_en = isfield(cfg, 'external_ef4') && isstruct(cfg.external_ef4) && ...
            getfield_default(cfg.external_ef4, 'enable', false);
        if ext_en
            yI_ext = ext_bits_to_pm1(getfield_default(cfg.external_ef4, 'i_bits', []));
            yQ_ext = ext_bits_to_pm1(getfield_default(cfg.external_ef4, 'q_bits', []));
            L_ext = min([numel(yI_ext), numel(yQ_ext), numel(i_i64), numel(q_i64)]);
            if L_ext < 1024
                error('external_ef4 bits too short (L=%d).', L_ext);
            end
            yI_ef4 = yI_ext(1:L_ext);
            yQ_ef4 = yQ_ext(1:L_ext);
            yI_ef4 = yI_ef4(:);
            yQ_ef4 = yQ_ef4(:);
            yrf_ef4_rm = [];
            rf_ext = ext_bits_to_pm1(getfield_default(cfg.external_ef4, 'rf_bits', []));
            if ~isempty(rf_ext)
                yrf_ef4 = rf_ext(1:min(numel(rf_ext), L_ext));
                yrf_ef4 = yrf_ef4(:);
            else
                yrf_ef4 = synth_rf_from_iq_pm1(yI_ef4, yQ_ef4, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
            end
            dbg_ef4 = empty_dbg();
            lanes_ext = NaN;
            if isfield(cfg, 'routeA_arch') && isstruct(cfg.routeA_arch) && ...
                    isfield(cfg.routeA_arch, 'multi_lane') && isstruct(cfg.routeA_arch.multi_lane)
                lanes_ext = getfield_default(cfg.routeA_arch.multi_lane, 'lanes', NaN);
            end
            arch_ef4 = struct( ...
                'i', struct('path', 'external_ef4_bits', 'lanes', lanes_ext), ...
                'q', struct('path', 'external_ef4_bits', 'lanes', lanes_ext));
        else
            [yI_ef4, yQ_ef4, dbg_ef4, arch_ef4] = ef4_arch_process_iq(i_i64, q_i64, cfg);
            if use_rm_fs4 || need_rm_obs
                [yI_ef4_rf, yQ_ef4_rf] = ef4_arch_process_iq(i_i64_h, q_i64_h, cfg);
                yrf_ef4_rm = synth_rf_from_iq_pm1(yI_ef4_rf, yQ_ef4_rf, cfg.fc_hz, cfg.Fs_dsm_main, 'rtl_fs4_rate_matched');
                if use_rm_fs4
                    yrf_ef4 = yrf_ef4_rm;
                else
                    yrf_ef4 = synth_rf_from_iq_pm1(yI_ef4, yQ_ef4, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
                end
            else
                yrf_ef4 = synth_rf_from_iq_pm1(yI_ef4, yQ_ef4, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
            end
        end
        met_ef4 = eval_if_metrics_dual(yrf_ef4, yI_ef4, yQ_ef4, x_ref_clip, cfg.Fs_dsm_main, cfg.Fs_bb, cfg.osr_main, cfg.fc_hz, bw_eff, cfg, yrf_ef4_rm);
    end

    if cfg.alg_enable.mash22
        ext_m_en = isfield(cfg, 'external_mash') && isstruct(cfg.external_mash) && ...
            getfield_default(cfg.external_mash, 'enable', false);
        if ext_m_en
            yI_ext = getfield_default(cfg.external_mash, 'i_y', []);
            yQ_ext = getfield_default(cfg.external_mash, 'q_y', []);
            if isempty(yI_ext) || isempty(yQ_ext)
                yI_ext = ext_bits_to_pm1(getfield_default(cfg.external_mash, 'i_bits', []));
                yQ_ext = ext_bits_to_pm1(getfield_default(cfg.external_mash, 'q_bits', []));
            end
            yI_ext = double(yI_ext(:));
            yQ_ext = double(yQ_ext(:));
            L_ext = min([numel(yI_ext), numel(yQ_ext), numel(i_i64), numel(q_i64)]);
            if L_ext < 1024
                error('external_mash sequence too short (L=%d).', L_ext);
            end
            yI_m22_raw = yI_ext(1:L_ext);
            yQ_m22_raw = yQ_ext(1:L_ext);
            if is_mash_multibit(cfg)
                yI_m22 = yI_m22_raw;
                yQ_m22 = yQ_m22_raw;
            else
                yI_m22 = sign_pm1(yI_m22_raw);
                yQ_m22 = sign_pm1(yQ_m22_raw);
            end
            mash_rf_mode = mash_rf_output_mode(cfg);
            if is_mash_multibit(cfg) && mash_rf_mode == "multibit"
                yI_m22_rf_full = yI_m22_raw;
                yQ_m22_rf_full = yQ_m22_raw;
            else
                yI_m22_rf_full = sign_pm1(yI_m22_raw);
                yQ_m22_rf_full = sign_pm1(yQ_m22_raw);
            end
            yrf_m22_rm = [];
            rf_ext = ext_bits_to_pm1(getfield_default(cfg.external_mash, 'rf_bits', []));
            if ~isempty(rf_ext)
                yrf_m22 = rf_ext(1:min(numel(rf_ext), L_ext));
                yrf_m22 = yrf_m22(:);
            else
                yrf_m22 = synth_rf_from_iq_pm1(yI_m22_rf_full, yQ_m22_rf_full, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
            end
            dbg_m22 = empty_dbg();
        else
            [yI_m22_raw, dbgI_m22] = mash_fixed_model(i_i64, cfg);
            [yQ_m22_raw, dbgQ_m22] = mash_fixed_model(q_i64, cfg);
            if is_mash_multibit(cfg)
                % Keep multibit DSM output for BB-domain metrics.
                yI_m22 = double(yI_m22_raw);
                yQ_m22 = double(yQ_m22_raw);
            else
                % 1-bit mode: quantize to PM1 before BB/RF evaluation.
                yI_m22 = sign_pm1(yI_m22_raw);
                yQ_m22 = sign_pm1(yQ_m22_raw);
            end
            % RF DUC path defaults to PM1 for backward compatibility.
            % Industrial studies can opt-in to multibit RF drive via:
            %   cfg.mash.rf_output_mode = 'multibit'
            mash_rf_mode = mash_rf_output_mode(cfg);
            if is_mash_multibit(cfg) && mash_rf_mode == "multibit"
                yI_m22_rf_full = double(yI_m22_raw);
                yQ_m22_rf_full = double(yQ_m22_raw);
            else
                yI_m22_rf_full = sign_pm1(yI_m22_raw);
                yQ_m22_rf_full = sign_pm1(yQ_m22_raw);
            end
            if use_rm_fs4 || need_rm_obs
                [yI_m22_raw_rf, ~] = mash_fixed_model(i_i64_h, cfg);
                [yQ_m22_raw_rf, ~] = mash_fixed_model(q_i64_h, cfg);
                if is_mash_multibit(cfg) && mash_rf_mode == "multibit"
                    yI_m22_rf = double(yI_m22_raw_rf);
                    yQ_m22_rf = double(yQ_m22_raw_rf);
                else
                    yI_m22_rf = sign_pm1(yI_m22_raw_rf);
                    yQ_m22_rf = sign_pm1(yQ_m22_raw_rf);
                end
                yrf_m22_rm = synth_rf_from_iq_pm1(yI_m22_rf, yQ_m22_rf, cfg.fc_hz, cfg.Fs_dsm_main, 'rtl_fs4_rate_matched');
                if use_rm_fs4
                    yrf_m22 = yrf_m22_rm;
                else
                    yrf_m22 = synth_rf_from_iq_pm1(yI_m22_rf_full, yQ_m22_rf_full, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
                end
            else
                yrf_m22 = synth_rf_from_iq_pm1(yI_m22_rf_full, yQ_m22_rf_full, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
            end
            dbg_m22 = merge_dbg(dbgI_m22, dbgQ_m22);
        end
        met_m22 = eval_if_metrics_dual(yrf_m22, yI_m22, yQ_m22, x_ref_clip, cfg.Fs_dsm_main, cfg.Fs_bb, cfg.osr_main, cfg.fc_hz, bw_eff, cfg, yrf_m22_rm);
    end

    [Pbb, fbb] = calc_psd_db(x_bb, cfg.Fs_bb, cfg.psd.nfft, cfg.psd.win_len);
    [Pif_in, fif] = calc_psd_db(x_if_in, cfg.Fs_dsm_main, cfg.psd.nfft, cfg.psd.win_len);
    if cfg.alg_enable.ef2
        [Pef2, ~] = calc_psd_db(yrf_ef2, cfg.Fs_dsm_main, cfg.psd.nfft, cfg.psd.win_len);
    end
    if cfg.alg_enable.ef4
        [Pef4, ~] = calc_psd_db(yrf_ef4, cfg.Fs_dsm_main, cfg.psd.nfft, cfg.psd.win_len);
    end
    if cfg.alg_enable.mash22
        [Pm22, ~] = calc_psd_db(yrf_m22, cfg.Fs_dsm_main, cfg.psd.nfft, cfg.psd.win_len);
    end

    results(k).bw_target_hz = bw_tgt;
    results(k).bw_effective_hz = bw_eff;
    results(k).active_sc = active_sc;
    results(k).input_backoff_nominal = cfg.input_backoff;
    results(k).input_backoff_used = backoff_use;
    results(k).ef4_autobackoff = auto_bo;
    results(k).bb_meta = bb_meta;
    results(k).osr_meta = osr_meta;
    if ~isempty(fieldnames(duc_diag))
        results(k).duc_diag = duc_diag;
    end
    if cfg.alg_enable.ef2
        results(k).metrics.ef2 = met_ef2;
        results(k).overflow.ef2 = dbg_ef2;
        results(k).psd.P_ef2_dB = Pef2;
    end
    if cfg.alg_enable.ef4
        results(k).metrics.ef4 = met_ef4;
        results(k).overflow.ef4 = dbg_ef4;
        results(k).psd.P_ef4_dB = Pef4;
        if ~isempty(fieldnames(arch_ef4))
            results(k).arch.ef4 = arch_ef4;
        end
        if isfield(met_ef4, 'rf_final') && isfield(met_ef4.rf_final, 'obs')
            results(k).rf_final_obs = met_ef4.rf_final.obs;
        end
    end
    if cfg.alg_enable.mash22
        results(k).metrics.mash22 = met_m22;
        results(k).overflow.mash22 = dbg_m22;
        results(k).psd.P_m22_dB = Pm22;
    end
    results(k).psd.f_bb = fbb;
    results(k).psd.P_bb_dB = Pbb;
    results(k).psd.f_if = fif;
    results(k).psd.P_if_in_dB = Pif_in;

    fprintf('\nCase %d/%d: BW target=%.1f MHz, BW eff=%.3f MHz, active_sc=%d\n', ...
        k, n_cases, bw_tgt/1e6, bw_eff/1e6, active_sc);
    if isfield(auto_bo, 'enabled') && auto_bo.enabled
        fprintf('Input backoff: nominal=%.4f, auto-selected=%.4f (%s)\n', ...
            auto_bo.backoff_init, auto_bo.backoff_sel, auto_bo.select_reason);
    else
        fprintf('Input backoff: %.4f (auto-tune disabled)\n', backoff_use);
    end
    if cfg.alg_enable.ef2
        print_metrics('EF2    ', met_ef2, dbg_ef2);
        warn_near_rail('EF2', dbg_ef2, cfg.ef2.acc_w);
    end
    if cfg.alg_enable.ef4
        print_metrics('EF4-IIR', met_ef4, dbg_ef4);
        if ~isempty(fieldnames(arch_ef4)) && isfield(arch_ef4, 'i') && isfield(arch_ef4.i, 'path')
            fprintf('EF4 arch path: I=%s', arch_ef4.i.path);
            if isfield(arch_ef4, 'q') && isfield(arch_ef4.q, 'path')
                fprintf(', Q=%s', arch_ef4.q.path);
            end
            if isfield(arch_ef4.i, 'lanes')
                fprintf(', lanes=%d', arch_ef4.i.lanes);
            end
            fprintf('\n');
        end
        warn_near_rail('EF4-IIR', dbg_ef4, cfg.ef4.acc_w);
    end
    if cfg.alg_enable.mash22
        print_metrics(mash_name, met_m22, dbg_m22);
        warn_near_rail(mash_name, dbg_m22, cfg.m22.acc_w);
    end

    % Export I/Q COE for RTL ROM input
    tag = sprintf('M%d_Nfft%d_Ncp%d_Nsym%d_BW%dm_Fc%dm_OSR%d_W16_DEPTH%d', ...
        cfg.M, cfg.Nfft, cfg.Ncp, cfg.Nsym, round(bw_eff/1e6), ...
        round(cfg.fc_hz/1e6), cfg.osr_main, cfg.rom_depth);
    coe_i = fullfile(out_coe, ['I_' tag '.coe']);
    coe_q = fullfile(out_coe, ['Q_' tag '.coe']);
    if cfg.export_coe
        write_coe_int16_hex(coe_i, fit_depth(i_i16, cfg.rom_depth));
        write_coe_int16_hex(coe_q, fit_depth(q_i16, cfg.rom_depth));
        fprintf('Exported COE: %s\n', coe_i);
        fprintf('Exported COE: %s\n', coe_q);
    else
        fprintf('COE export disabled in debug profile.\n');
    end

    % EF4 I/Q reference bits for RTL alignment
    wr_n = min(cfg.rom_depth, numel(i_i16));
    if cfg.alg_enable.ef4
        ref_bits_file_ef4 = fullfile(out_res, ['ef4_ref_bits_01_' tag '.csv']);
        ref_rf_file_ef4 = fullfile(out_res, ['ef4_ref_rf_bits_01_' tag '.csv']);
        writematrix(uint8([yI_ef4(1:wr_n) > 0, yQ_ef4(1:wr_n) > 0]), ref_bits_file_ef4);
        writematrix(uint8(yrf_ef4(1:wr_n) > 0), ref_rf_file_ef4);
    end
    if cfg.alg_enable.ef2
        ref_bits_file_ef2 = fullfile(out_res, ['ef2_ref_bits_01_' tag '.csv']);
        ref_rf_file_ef2 = fullfile(out_res, ['ef2_ref_rf_bits_01_' tag '.csv']);
        writematrix(uint8([yI_ef2(1:wr_n) > 0, yQ_ef2(1:wr_n) > 0]), ref_bits_file_ef2);
        writematrix(uint8(yrf_ef2(1:wr_n) > 0), ref_rf_file_ef2);
    end
    if cfg.alg_enable.mash22
        ref_bits_file_m22 = fullfile(out_res, [char(mash_tag) '_ref_bits_01_' tag '.csv']);
        ref_rf_file_m22 = fullfile(out_res, [char(mash_tag) '_ref_rf_bits_01_' tag '.csv']);
        writematrix(uint8([yI_m22(1:wr_n) > 0, yQ_m22(1:wr_n) > 0]), ref_bits_file_m22);
        writematrix(uint8(yrf_m22(1:wr_n) > 0), ref_rf_file_m22);
    end
    if k == n_cases
        x_bb_ref = x_bb;
        bw_ref_hz = bw_eff;
    end
end

if ~isfield(cfg, 'enable_sweep')
    cfg.enable_sweep = true;
end
if ~isfield(cfg, 'enable_tradeoff')
    cfg.enable_tradeoff = true;
end
if ~isfield(cfg, 'enable_plots')
    cfg.enable_plots = true;
end

if cfg.enable_sweep && cfg.alg_enable.ef4 && cfg.alg_enable.mash22
    sweep = run_stability_sweep(x_bb_ref, bw_ref_hz, cfg);
elseif cfg.enable_sweep
    warning('Stability sweep skipped: requires both EF4 and MASH2-2 enabled.');
    sweep = struct();
else
    sweep = struct();
end
if cfg.enable_tradeoff && cfg.alg_enable.ef4
    tradeoff = run_osr_tradeoff(x_bb_ref, bw_ref_hz, cfg);
elseif cfg.enable_tradeoff
    warning('OSR tradeoff skipped: requires EF4 enabled.');
    tradeoff = struct();
else
    tradeoff = struct();
end

if cfg.enable_plots
    plot_fig_1_baseband(results, out_fig);
    plot_fig_2_if(results, out_fig);
    if cfg.alg_enable.ef4 && cfg.alg_enable.ef2
        plot_fig_3_ef4_vs_ef2(results, out_fig);
    end
    if cfg.alg_enable.ef4 && cfg.alg_enable.mash22
        plot_fig_4_ef4_vs_mash22(results, out_fig);
    end
    if cfg.enable_sweep && isfield(sweep, 'A_list')
        plot_fig_5_stability(sweep, out_fig);
    end
    if cfg.enable_tradeoff && isfield(tradeoff, 'osr_list')
        plot_fig_6_osr_tradeoff(tradeoff, out_fig);
    end
end

stamp = datestr(now, 'yyyymmdd_HHMMSS');
out_mat = fullfile(out_res, ['run_chain_if200_osr16_v1_' stamp '.mat']);
if disable_save
    fprintf('\nSaved summary skipped (cfg.debug.disable_save=true)\n');
else
    save(out_mat, 'results', 'sweep', 'tradeoff', 'cfg');
    fprintf('\nSaved summary: %s\n', out_mat);
end

end

function cfg = default_cfg()
cfg = struct();
cfg.exp_name = 'routeA_stage1_best';
cfg.M = 16;
cfg.Nfft = 1024;
cfg.Ncp = 72;
cfg.Nsym = 180;
cfg.delta_f = 15e3;
cfg.Fs_bb = cfg.Nfft * cfg.delta_f;
cfg.random_seed = 7;

cfg.bw_targets_hz = 10e6;
cfg.osr_main = 32;
cfg.fc_req_hz = 122.88e6;
cfg.rf_mode = 'rtl_fs4'; % 'rtl_fs4' | 'rtl_fs4_interleave' | 'rtl_fs4_rate_matched' | 'ideal_lo'
cfg.Fs_dsm_main = [];
cfg.fc_hz = [];

cfg.alg_enable = struct();
cfg.alg_enable.ef2 = false;
cfg.alg_enable.ef4 = true;
cfg.alg_enable.mash22 = false;

cfg.input_backoff = 0.24;
cfg.input_clip = 0.999;
cfg.fast_mode = true;
cfg.rom_depth = 65536;
cfg.export_coe = true;

cfg.psd.win_len = 4096;
cfg.psd.nfft = 16384;

cfg.n_settle_osr = 2048;
cfg.rec_stop_att = 80;
cfg.aclr_adj_offset_hz = 20e6;
cfg.metrics = struct();
cfg.metrics.min_eval_fs_over_bw = 4; % evaluate EVM/SNDR at Fs_eval >= 4*BW
cfg.metrics.domain = 'dual';         % 'rf' | 'bb' | 'dual'
cfg.metrics.primary = 'bb';          % displayed SNDR/EVM source when dual
cfg.metrics.aclr_domain = 'bb';      % displayed ACLR source when dual
cfg.metrics.rf_waveform_in_rtl_fs4 = true; % true: evaluate RF via reconstruction path in rtl_fs4
cfg.metrics.print_rf_final = true;   % print RF_Final metrics in console when available
cfg.metrics.rf_ofdm_eval_enable = true; % for RF paths: use CP-sync OFDM EVM/SNDR when possible
cfg.metrics.rf_ofdm_cp_search_syms = 24;
cfg.metrics.rf_ofdm_min_syms = 8;
cfg.metrics.rf_ofdm_pow_thr_db = -35;
cfg.metrics.rf_ofdm_min_corr = 0.80;

cfg.rf_eval = struct();
cfg.rf_eval.preselect_bpf = true;    % preselect IF band before DDC
cfg.rf_eval.bpf_pass_bw_scale = 1.20;
cfg.rf_eval.bpf_guard_hz = 3e6;
cfg.rf_eval.bpf_order = 256;
cfg.rf_eval.bpf_zero_phase = true;
cfg.rf_eval.rtl_fs4_reconstruct = true;  % use TDM demux + reconstruction for rtl_fs4
cfg.rf_eval.rtl_fs4_reconstruct_impl = 'bittrue_halfrate'; % 'bittrue_halfrate' | 'bittrue_lock' | 'sparse_autoselect'
cfg.rf_eval.iq_interp_order = 192;       % FIR order for I/Q sparse reconstruction
cfg.rf_eval.iq_interp_pass_bw_scale = 1.20;
cfg.rf_eval.rtl_fs4_q_advance = true;    % compensate half-sample I/Q staggering
cfg.rf_eval.rtl_fs4_autoselect = false;  % legacy sparse auto-search disabled in bit-true lock mode
cfg.rf_eval.rtl_fs4_phase_offset = 0;    % lock phase in bit-true mode
cfg.rf_eval.rtl_fs4_q_sign = 1;          % lock Q sign in bit-true mode
cfg.rf_eval.rtl_fs4_q_shift = 0;         % lock Q sample shift in bit-true mode
cfg.rf_eval.rtl_fs4_lock_fallback_autoselect = true; % fallback to sparse search if lock score too low
cfg.rf_eval.rtl_fs4_phase_offset_list = 0:3;
cfg.rf_eval.rtl_fs4_q_shift_list = [-1, 0, 1];
cfg.rf_eval.rtl_fs4_q_sign_list = [1, -1];
cfg.rf_eval.rtl_fs4_reconstruct_min_score = 0.55;
cfg.rf_eval.zero_phase_reconstruct = true;
cfg.rf_eval.stop_att = 100;
cfg.rf_eval.use_analytic_ddc = true;

cfg.rf_final = struct();
cfg.rf_final.enable = true;               % reconstructed RF final metrics (BPF + nonideal + DDC/reconstruct)
cfg.rf_final.bpf_enable = true;
cfg.rf_final.bpf_pass_bw_scale = 1.20;
cfg.rf_final.bpf_guard_hz = 3e6;
cfg.rf_final.bpf_order = 256;
cfg.rf_final.bpf_zero_phase = true;
cfg.rf_final.tx_gain_db = 0.0;
cfg.rf_final.pa_alpha3 = 0.0;             % y = x + alpha3*x^3
cfg.rf_final.awgn_snr_db = inf;           % set finite value to enable AWGN
cfg.rf_final.eval_pick = 'best_evm';      % 'best_evm' | 'causal' | 'zero_phase'
cfg.rf_final.enable_ab = true;            % run causal vs zero-phase A/B
cfg.rf_final.save_obs = true;             % save RF_Final intermediate observation points
cfg.rf_final.obs_max_len = 32768;
cfg.rf_final.rtl_fs4_use_bittrue_rf = true; % in rtl_fs4, evaluate RF_Final from actual y_rf path
cfg.rf_final.rtl_fs4_reconstruct_min_score = 0.05;
cfg.rf_final.rtl_fs4_reconstruct_digital = true;
cfg.rf_final.rtl_fs4_reconstruct_analog = false;
cfg.rf_final.rtl_fs4_demux_pre_frontend = true;
cfg.rf_final.rtl_fs4_score_ref = 'x_ref'; % 'x_ref' or 'y_lane'
cfg.rf_final.digital_preselect_bpf = true;
cfg.rf_final.zero_phase_reconstruct = true;
cfg.rf_final.stop_att = 100;
cfg.rf_final.use_analytic_ddc = true;
cfg.rf_final.duc_consistency_test = struct('enable', true, 'N', 8192, 'f0_hz', 1.2e6);
cfg.rf_final.stage1_halfrate_fallback_enable = true;
cfg.rf_final.stage1_halfrate_fallback_on_low_score = true;
cfg.rf_final.stage1_halfrate_fallback_on_ofdm_invalid = true;
cfg.rf_final.stage1_halfrate_fallback_score_min = 0.55;
cfg.rf_final.halfrate_fallback_scope = 'stage1'; % 'stage1' | 'all' | 'none'

cfg.debug = struct();
cfg.debug.enable = false;
cfg.debug.Nsym = 20;
cfg.debug.psd_win_len = 1024;
cfg.debug.psd_nfft = 4096;
cfg.debug.disable_coe = true;

cfg.ef4_autobackoff = struct();
cfg.ef4_autobackoff.enable = true;       % true: auto-retreat input_backoff for EF4
cfg.ef4_autobackoff.min = 0.03;
cfg.ef4_autobackoff.step = 0.01;
cfg.ef4_autobackoff.rail_ratio_max = 0.90;
cfg.ef4_autobackoff.require_clean = true; % require ov=0 and sat=0
cfg.ef4_autobackoff.print = true;
cfg.ef4_autobackoff.metric_domain = 'bb'; % 'bb' | 'rf_dig'
cfg.ef4_autobackoff.rf_require_ofdm_valid = true;
cfg.ef4_autobackoff.rf_corr_min = 0.90;

cfg.ef2 = struct('acc_w', 28, 'saturate', true, 'b1', int64(2), 'b2', int64(-1));
cfg.ef4 = struct( ...
    'acc_w', 40, 'saturate', true, 'coeff_shift', 14, ...
    'num_q', int64([18920, -46600, 39400, -11348]), ...
    'den_q', int64([-46481, 51434, -26001, 5036]));
cfg.m22 = struct('acc_w', 28, 'saturate', true, 'b1', int64(2), 'b2', int64(-1));
cfg.mash = struct('variant', 'mash22', 'output_mode', 'multibit');
cfg.mash.dither = struct();
cfg.mash.dither.enable = false;      % set true to enable first-stage MASH dither
cfg.mash.dither.variants = {'mash11', 'mash111'};
cfg.mash.dither.amp_lsb = 1;         % integer dither amplitude in input LSB
cfg.mash.dither.pdf = 'tpdf';        % 'tpdf' | 'uniform'

cfg.cic_comp = struct();
cfg.cic_comp.enable = false;         % baseband CIC droop pre-compensation
cfg.cic_comp.stages = 3;             % CIC stages (for HW interpolation model)
cfg.cic_comp.diff_delay = 1;         % CIC differential delay M
cfg.cic_comp.interp_rate = [];       % default: cfg.osr_main
cfg.cic_comp.fir_order = 48;         % compensation FIR order
cfg.cic_comp.max_boost_db = 6.0;     % cap compensation gain
cfg.cic_comp.pass_edge_scale = 1.00; % pass edge = scale * BW/2
cfg.cic_comp.stop_edge_scale = 1.25; % stop edge = scale * BW/2

% Route-A staged architecture switches:
% Stage-1: all disabled (baseline EF4 chain)
% Stage-2: bus_split.enable=true
% Stage-3: + lookahead.enable=true
% Stage-4: + multi_lane.enable=true
cfg.routeA_arch = struct();
cfg.routeA_arch.enable = false;
cfg.routeA_arch.bus_split = struct( ...
    'enable', false, ...
    'lsb_bits', 6, ...
    'msb_core', 'ef4', ...
    'lsb_core', 'ef4', ...
    'combine_mode', 'weighted_sum_sign', ...
    'lsb_weight', 0.25);
cfg.routeA_arch.lookahead = struct( ...
    'enable', false, ...
    'mode', 'first_diff', ...
    'alpha', 0.25);
cfg.routeA_arch.multi_lane = struct( ...
    'enable', false, ...
    'lanes', 4, ...
    'bb_proxy_from_rf_dig', false);

cfg.sweep.A_list = 0.05:0.05:0.50;
cfg.sweep.max_len = 65536;

cfg.tradeoff.osr_list = [16, 32];
cfg.tradeoff.fc_hz = 100e6; % fair and valid for both OSR16/32

cfg.enable_sweep = false;
cfg.enable_tradeoff = false;
cfg.enable_plots = true;
end

function cfg = refresh_derived_cfg(cfg)
cfg.Fs_bb = cfg.Nfft * cfg.delta_f;
cfg.Fs_dsm_main = cfg.Fs_bb * cfg.osr_main;
if is_fs4_mode(cfg.rf_mode)
    cfg.fc_hz = cfg.Fs_dsm_main / 4;
else
    cfg.fc_hz = cfg.fc_req_hz;
end
cfg.alg_enable = normalize_alg_enable(getfield_default(cfg, 'alg_enable', struct()));
end

function tf = is_fs4_mode(rf_mode)
tf = strcmpi(rf_mode, 'rtl_fs4') || ...
     strcmpi(rf_mode, 'rtl_fs4_interleave') || ...
     strcmpi(rf_mode, 'rtl_fs4_rate_matched');
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

function cfg = apply_debug_profile(cfg)
if ~isfield(cfg, 'debug') || ~isfield(cfg.debug, 'enable') || ~cfg.debug.enable
    return;
end
if isfield(cfg.debug, 'Nsym') && ~isempty(cfg.debug.Nsym)
    cfg.Nsym = cfg.debug.Nsym;
end
if isfield(cfg.debug, 'psd_win_len') && ~isempty(cfg.debug.psd_win_len)
    cfg.psd.win_len = cfg.debug.psd_win_len;
end
if isfield(cfg.debug, 'psd_nfft') && ~isempty(cfg.debug.psd_nfft)
    cfg.psd.nfft = cfg.debug.psd_nfft;
end
cfg.enable_plots = false;
cfg.enable_sweep = false;
cfg.enable_tradeoff = false;
if isfield(cfg.debug, 'disable_coe') && cfg.debug.disable_coe
    cfg.export_coe = false;
end
end

function validate_cfg(cfg)
if ~(cfg.alg_enable.ef2 || cfg.alg_enable.ef4 || cfg.alg_enable.mash22)
    error('No algorithm enabled. Set cfg.alg_enable.(ef2/ef4/mash22) at least one true.');
end
if is_fs4_mode(cfg.rf_mode)
    fc_fs4 = cfg.Fs_dsm_main / 4;
    if abs(cfg.fc_hz - fc_fs4) > 1
        error('%s mode requires fc = Fs_dsm/4.', cfg.rf_mode);
    end
    if abs(cfg.fc_req_hz - cfg.fc_hz) > 1
        warning('%s mode overrides fc_req %.3f MHz -> fc_used %.3f MHz.', ...
            cfg.rf_mode, cfg.fc_req_hz/1e6, cfg.fc_hz/1e6);
    end
else
    if cfg.fc_hz >= cfg.Fs_dsm_main/2
        error('Invalid main setup: fc must be < Fs_dsm/2.');
    end
end
for k = 1:numel(cfg.bw_targets_hz)
    bw = cfg.bw_targets_hz(k);
    if bw >= cfg.Fs_bb
        error('BW %.3f MHz must be < Fs_bb %.3f MHz.', bw/1e6, cfg.Fs_bb/1e6);
    end
    guard_ratio = (cfg.Fs_bb - bw) / cfg.Fs_bb;
    if guard_ratio < 0.08
        warning(['BW %.3f MHz occupies %.1f%% of Fs_bb %.3f MHz. ', ...
            'Decimate-to-Fs_bb EVM is filter-limited; this script evaluates EVM/SNDR at higher Fs_eval.'], ...
            bw/1e6, 100*bw/cfg.Fs_bb, cfg.Fs_bb/1e6);
    end
end
if isfield(cfg, 'ef4_autobackoff') && isfield(cfg.ef4_autobackoff, 'enable') && cfg.ef4_autobackoff.enable
    if ~cfg.alg_enable.ef4
        warning('ef4_autobackoff enabled but EF4 is disabled. Auto-backoff will be ignored.');
    end
    if cfg.ef4_autobackoff.min <= 0 || cfg.ef4_autobackoff.min >= 1
        error('ef4_autobackoff.min must be in (0,1).');
    end
    if cfg.ef4_autobackoff.step <= 0
        error('ef4_autobackoff.step must be > 0.');
    end
    if cfg.ef4_autobackoff.rail_ratio_max <= 0 || cfg.ef4_autobackoff.rail_ratio_max >= 1
        error('ef4_autobackoff.rail_ratio_max must be in (0,1).');
    end
    md = lower(string(getfield_default(cfg.ef4_autobackoff, 'metric_domain', 'bb')));
    if ~(md == "bb" || md == "rf_dig")
        error('ef4_autobackoff.metric_domain must be ''bb'' or ''rf_dig''.');
    end
end
if isfield(cfg, 'rf_eval')
    if isfield(cfg.rf_eval, 'bpf_pass_bw_scale') && cfg.rf_eval.bpf_pass_bw_scale <= 1
        error('rf_eval.bpf_pass_bw_scale must be > 1.');
    end
    if isfield(cfg.rf_eval, 'bpf_guard_hz') && cfg.rf_eval.bpf_guard_hz <= 0
        error('rf_eval.bpf_guard_hz must be > 0.');
    end
    if isfield(cfg.rf_eval, 'bpf_order') && cfg.rf_eval.bpf_order < 32
        error('rf_eval.bpf_order must be >= 32.');
    end
end
if isfield(cfg, 'rf_final')
    if isfield(cfg.rf_final, 'bpf_pass_bw_scale') && cfg.rf_final.bpf_pass_bw_scale <= 1
        error('rf_final.bpf_pass_bw_scale must be > 1.');
    end
    if isfield(cfg.rf_final, 'bpf_guard_hz') && cfg.rf_final.bpf_guard_hz <= 0
        error('rf_final.bpf_guard_hz must be > 0.');
    end
    if isfield(cfg.rf_final, 'bpf_order') && cfg.rf_final.bpf_order < 32
        error('rf_final.bpf_order must be >= 32.');
    end
end
if isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable
    if isfield(cfg.routeA_arch, 'bus_split') && isfield(cfg.routeA_arch.bus_split, 'enable') && cfg.routeA_arch.bus_split.enable
        lsb_bits = round(getfield_default(cfg.routeA_arch.bus_split, 'lsb_bits', 6));
        if lsb_bits < 1 || lsb_bits > 12
            error('routeA_arch.bus_split.lsb_bits must be in [1,12].');
        end
    end
    if isfield(cfg.routeA_arch, 'multi_lane') && isfield(cfg.routeA_arch.multi_lane, 'enable') && cfg.routeA_arch.multi_lane.enable
        lanes = round(getfield_default(cfg.routeA_arch.multi_lane, 'lanes', 4));
        if lanes < 2
            error('routeA_arch.multi_lane.lanes must be >= 2 when enabled.');
        end
    end
end
if isfield(cfg, 'cic_comp') && isstruct(cfg.cic_comp)
    if getfield_default(cfg.cic_comp, 'enable', false)
        fir_order = round(getfield_default(cfg.cic_comp, 'fir_order', 48));
        if fir_order < 8
            error('cic_comp.fir_order must be >= 8 when enabled.');
        end
        if getfield_default(cfg.cic_comp, 'stages', 3) < 1
            error('cic_comp.stages must be >= 1.');
        end
        if getfield_default(cfg.cic_comp, 'diff_delay', 1) < 1
            error('cic_comp.diff_delay must be >= 1.');
        end
        if getfield_default(cfg.cic_comp, 'max_boost_db', 6.0) < 0
            error('cic_comp.max_boost_db must be >= 0.');
        end
    end
end
if isfield(cfg, 'mash') && isstruct(cfg.mash) && isfield(cfg.mash, 'dither') && isstruct(cfg.mash.dither)
    if getfield_default(cfg.mash.dither, 'enable', false)
        amp_lsb = round(getfield_default(cfg.mash.dither, 'amp_lsb', 1));
        if amp_lsb < 1
            error('mash.dither.amp_lsb must be >= 1 when dither is enabled.');
        end
        pdf = lower(string(getfield_default(cfg.mash.dither, 'pdf', 'tpdf')));
        if ~(pdf == "tpdf" || pdf == "uniform")
            error('mash.dither.pdf must be ''tpdf'' or ''uniform''.');
        end
    end
end
end

function mkpath(p)
if ~exist(p, 'dir')
    mkdir(p);
end
end

function active_sc = calc_active_subcarriers(Nfft, delta_f, bw_hz)
active_sc = 2 * floor((bw_hz / delta_f) / 2);
active_sc = min(active_sc, Nfft - 2);
active_sc = max(active_sc, 2);
if mod(active_sc, 2) ~= 0
    active_sc = active_sc - 1;
end
end

function [x_bb, meta] = gen_ofdm_bb_qam(cfg, active_sc, bw_hz)
if nargin < 3 || isempty(bw_hz)
    bw_hz = active_sc * cfg.delta_f;
end

k = log2(cfg.M);
if ~(cfg.M == 16 || cfg.M == 256)
    error('This script currently supports M=16 or M=256.');
end

half_sc = active_sc / 2;
active_bins = [-half_sc:-1, 1:half_sc];
used_sc = bins_to_fft_indices(active_bins, cfg.Nfft);

Nb = cfg.Nsym * active_sc * k;
bits = randi([0 1], Nb, 1);
qam_data = qam_square_gray(bits, cfg.M);
qam_data = reshape(qam_data, active_sc, cfg.Nsym);

Xk = zeros(cfg.Nfft, cfg.Nsym);
Xk(used_sc, :) = qam_data;

ofdm_td = ifft(Xk, cfg.Nfft, 1);
ofdm_cp = [ofdm_td(end-cfg.Ncp+1:end, :); ofdm_td];
x_bb = ofdm_cp(:);

cic_meta = struct('enabled', false);
if isfield(cfg, 'cic_comp') && isstruct(cfg.cic_comp) && getfield_default(cfg.cic_comp, 'enable', false)
    [x_bb, cic_meta] = apply_cic_compensation(x_bb, cfg, bw_hz);
end
x_bb = x_bb / max(rms(x_bb), eps);

meta = struct();
meta.active_sc = active_sc;
meta.active_bins = active_bins;
meta.used_sc = used_sc;
meta.cic_comp = cic_meta;
end

function [x_out, info] = apply_cic_compensation(x_in, cfg, bw_hz)
x_out = x_in(:);
info = struct('enabled', false);

cc = getfield_default(cfg, 'cic_comp', struct());
if ~(isstruct(cc) && getfield_default(cc, 'enable', false))
    return;
end

R = round(getfield_default(cc, 'interp_rate', cfg.osr_main));
if isempty(R) || ~isfinite(R) || R < 2
    R = max(2, round(cfg.osr_main));
end
nst = max(1, round(getfield_default(cc, 'stages', 3)));
md = max(1, round(getfield_default(cc, 'diff_delay', 1)));
ord = max(8, round(getfield_default(cc, 'fir_order', 48)));
if mod(ord, 2) ~= 0
    ord = ord + 1;
end
pass_scale = getfield_default(cc, 'pass_edge_scale', 1.00);
stop_scale = getfield_default(cc, 'stop_edge_scale', 1.25);
max_boost_db = getfield_default(cc, 'max_boost_db', 6.0);

nyq = cfg.Fs_bb / 2;
fpass = min(0.95 * nyq, max(cfg.delta_f, pass_scale * bw_hz / 2));
fstop = min(0.995 * nyq, max(fpass + cfg.delta_f, stop_scale * bw_hz / 2));
if fstop <= fpass
    fstop = min(0.995 * nyq, fpass + cfg.delta_f);
end

[b, dinfo] = design_cic_comp_fir_cached(cfg.Fs_bb, fpass, fstop, R, nst, md, ord, max_boost_db);
x_out = filter(b, 1, x_out);

info = dinfo;
info.enabled = true;
info.fpass_hz = fpass;
info.fstop_hz = fstop;
end

function [b, info] = design_cic_comp_fir_cached(Fs_bb, fpass, fstop, R, nst, md, ord, max_boost_db)
persistent key_cache b_cache info_cache
key = sprintf('Fs=%.12g|fp=%.12g|fs=%.12g|R=%d|N=%d|M=%d|ord=%d|max=%.4f', ...
    Fs_bb, fpass, fstop, R, nst, md, ord, max_boost_db);

if ischar(key_cache) && strcmp(key_cache, key)
    b = b_cache;
    info = info_cache;
    return;
end

npt = 512;
f_pass = linspace(0, fpass, npt);
h_cic = cic_interp_mag(f_pass, Fs_bb, R, nst, md);
g_inv = 1 ./ max(h_cic, eps);
g_inv = min(g_inv, 10^(max_boost_db/20));
g_inv = g_inv(:).';

f01_pass = f_pass / (Fs_bb/2);
f01_stop = min(1, fstop / (Fs_bb/2));
fgrid = [f01_pass, f01_stop, 1.0];
agrid = [g_inv, 0, 0];
[fgrid_u, ia] = unique(fgrid, 'stable');
agrid_u = agrid(ia);

if numel(fgrid_u) < 2
    b = 1;
else
    b = fir2(ord, fgrid_u, agrid_u, hamming(ord + 1));
end

info = struct();
info.method = 'fir2_inverse_cic';
info.R = R;
info.stages = nst;
info.diff_delay = md;
info.fir_order = ord;
info.max_boost_db = max_boost_db;
info.dc_gain = sum(b);

key_cache = key;
b_cache = b;
info_cache = info;
end

function h = cic_interp_mag(f_hz, Fs_bb, R, nst, md)
f_hz = double(f_hz(:));
Fs_out = Fs_bb * R;

num = sin(pi * f_hz * md * R / Fs_out);
den = R * sin(pi * f_hz * md / Fs_out);

ratio = ones(size(f_hz));
idx = abs(den) > 1e-12;
ratio(idx) = num(idx) ./ den(idx);

h = abs(ratio) .^ nst;
if ~isempty(h)
    h(1) = 1;
end
end

function used_sc = bins_to_fft_indices(active_bins, Nfft)
used_sc = zeros(1, numel(active_bins));
for ii = 1:numel(active_bins)
    b = active_bins(ii);
    if b == 0
        used_sc(ii) = 1;
    elseif b > 0
        used_sc(ii) = b + 1;
    else
        used_sc(ii) = Nfft + b + 1;
    end
end
end

function s = qam_square_gray(bits, M)
k = log2(M);
if mod(numel(bits), k) ~= 0
    error('bits length must be multiple of log2(M).');
end
L = sqrt(M);
if abs(L - round(L)) > eps
    error('Only square QAM is supported.');
end
L = round(L);
k2 = k/2;

b = reshape(bits(:), k, []).';
bi = b(:, 1:k2);
bq = b(:, k2+1:k);

idxI = gray_to_bin(bi);
idxQ = gray_to_bin(bq);
levels = -(L-1):2:(L-1);
xi = levels(idxI+1).';
xq = levels(idxQ+1).';

scale = sqrt((2/3) * (M - 1));
s = (xi + 1j*xq) / scale;
end

function idx = gray_to_bin(b)
k = size(b,2);
bin = zeros(size(b));
bin(:,1) = b(:,1);
for bit_idx = 2:k
    bin(:,bit_idx) = xor(bin(:,bit_idx-1), b(:,bit_idx));
end
idx = zeros(size(b,1),1);
for bit_idx = 1:k
    idx = idx + bin(:,bit_idx) * 2^(k-bit_idx);
end
end

function [x_osr, meta] = osr_interpolate(x_bb, osr, Fs_bb, bw_hz, fast_mode)
x_up = upsample(x_bb, osr);
if fast_mode
    Nfir = max(160, 10*osr);
else
    Nfir = max(320, 20*osr);
end
if mod(Nfir, 2) ~= 0
    Nfir = Nfir + 1;
end
% Preserve the occupied baseband bandwidth after upsampling:
% Wn (fir1) is normalized to (Fs_up/2), Fs_up = Fs_bb*osr.
% Required Wn >= (BW/2)/(Fs_up/2) = BW/(Fs_bb*osr).
wn_need = 1.05 * (bw_hz / (Fs_bb * osr));
wn = min(0.98/osr, max(0.50/osr, wn_need));
h = fir1(Nfir, wn);
x_f = filter(h, 1, x_up);
gd = floor(Nfir/2);
x_osr = x_f(gd+1:end);
x_osr = x_osr / max(rms(x_osr), eps);

meta = struct('Nfir', Nfir, 'group_delay', gd, 'wn', wn);
end

function [i_i16, q_i16, x_clip] = quantize_iq_q15(x_cplx, clip_val)
i = max(min(real(x_cplx(:)), clip_val), -clip_val);
q = max(min(imag(x_cplx(:)), clip_val), -clip_val);
i_i16 = int16(round(i * (2^15 - 1)));
q_i16 = int16(round(q * (2^15 - 1)));
x_clip = double(i_i16)/(2^15-1) + 1j*double(q_i16)/(2^15-1);
end

function x_if = duc_to_if_real(x_cplx, fc_hz, Fs_hz)
n = (0:numel(x_cplx)-1).';
lo = exp(1j * 2*pi * fc_hz/Fs_hz * n);
x_if = real(x_cplx(:) .* lo);
x_if = x_if / max(abs(x_if) + eps);
end

function y_rf = upconvert_cartesian_pm1(yI_pm, yQ_pm, fc_hz, Fs_hz)
n = (0:numel(yI_pm)-1).';
wc = 2*pi*fc_hz/Fs_hz;
y_rf = double(yI_pm(:)) .* cos(wc*n) - double(yQ_pm(:)) .* sin(wc*n);
end

function y_rf = duc_fs4_merge_pm1(yI_pm, yQ_pm)
N = min(numel(yI_pm), numel(yQ_pm));
yI_pm = sign_pm1(yI_pm(1:N));
yQ_pm = sign_pm1(yQ_pm(1:N));
y_rf = zeros(N, 1);
for n = 1:N
    ph = mod(n-1, 4);
    switch ph
        case 0
            y_rf(n) = yI_pm(n);      % +I
        case 1
            y_rf(n) = yQ_pm(n);      % +Q
        case 2
            y_rf(n) = -yI_pm(n);     % -I
        otherwise
            y_rf(n) = -yQ_pm(n);     % -Q
    end
end
end

function y_rf = synth_rf_from_iq_pm1(yI_pm, yQ_pm, fc_hz, Fs_hz, rf_mode)
if strcmpi(rf_mode, 'rtl_fs4')
    y_rf = duc_fs4_merge_pm1(yI_pm, yQ_pm);
elseif strcmpi(rf_mode, 'rtl_fs4_interleave')
    y_rf = duc_fs4_interleave_pm1(yI_pm, yQ_pm);
elseif strcmpi(rf_mode, 'rtl_fs4_rate_matched')
    y_rf = duc_fs4_rate_matched_pm1(yI_pm, yQ_pm);
else
    y_rf = upconvert_cartesian_pm1(yI_pm, yQ_pm, fc_hz, Fs_hz);
end
end

function y_rf = duc_fs4_interleave_pm1(yI_pm, yQ_pm)
% Paper-style rate-matched interleave model:
%   take half-rate I/Q streams and interleave as [I0,Q0,-I1,-Q1,...]
% This is NOT bit-true to current rtl_fs4 merge; it is an architectural study mode.
N = min(numel(yI_pm), numel(yQ_pm));
yI_pm = sign_pm1(yI_pm(1:N));
yQ_pm = sign_pm1(yQ_pm(1:N));
yI_h = yI_pm(1:2:end);
yQ_h = yQ_pm(1:2:end);
M = min(numel(yI_h), numel(yQ_h));
yI_h = yI_h(1:M);
yQ_h = yQ_h(1:M);
y_rf = zeros(2*M, 1);
for k = 1:M
    sgn = 1;
    if mod(k-1, 2) == 1
        sgn = -1;
    end
    y_rf(2*k-1) = sgn * yI_h(k);
    y_rf(2*k) = sgn * yQ_h(k);
end
end

function y_rf = duc_fs4_rate_matched_pm1(yI_pm, yQ_pm)
% Rate-matched Fs/4 stream from half-rate I/Q DSM outputs.
% Input yI_pm / yQ_pm are assumed generated at Fs/2.
% Output sequence at Fs: [ +I0, -Q0, -I1, +Q1, +I2, -Q2, ... ].
N = min(numel(yI_pm), numel(yQ_pm));
if N <= 0
    y_rf = zeros(0, 1);
    return;
end
yI_pm = sign_pm1(yI_pm(1:N));
yQ_pm = sign_pm1(yQ_pm(1:N));

sgn = ones(N, 1);
sgn(mod((0:N-1)', 2) == 1) = -1;

y_rf = zeros(2*N, 1);
y_rf(1:2:end) = sgn .* yI_pm;
y_rf(2:2:end) = -sgn .* yQ_pm;
end

function y_pm = sign_pm1(x)
y_pm = ones(size(x));
y_pm(x < 0) = -1;
end

function dbg = empty_dbg()
dbg = struct('ov_count', 0, 'sat_hi', 0, 'sat_lo', 0, 'vpk', 0);
end

function dbg = merge_dbg(dbg_i, dbg_q)
dbg = struct();
dbg.ov_count = dbg_i.ov_count + dbg_q.ov_count;
dbg.sat_hi = dbg_i.sat_hi + dbg_q.sat_hi;
dbg.sat_lo = dbg_i.sat_lo + dbg_q.sat_lo;
if isfield(dbg_i, 'vpk1')
    dbg.vpk1 = max(dbg_i.vpk1, dbg_q.vpk1);
    dbg.vpk2 = max(dbg_i.vpk2, dbg_q.vpk2);
else
    dbg.vpk = max(dbg_i.vpk, dbg_q.vpk);
end
end

function warn_near_rail(name, dbg, acc_w)
rail = double(2^(acc_w-1) - 1);
thr = 0.90 * rail;
if isfield(dbg, 'vpk')
    if double(dbg.vpk) > thr
        warning('%s near-rail state: vpk=%.3e (%.1f%% of full-scale). Consider lower input_backoff.', ...
            name, double(dbg.vpk), 100*double(dbg.vpk)/rail);
    end
end
if isfield(dbg, 'vpk1') && isfield(dbg, 'vpk2')
    vpkm = max(double(dbg.vpk1), double(dbg.vpk2));
    if vpkm > thr
        warning('%s near-rail state: max(vpk1,vpk2)=%.3e (%.1f%% of full-scale). Consider lower input_backoff.', ...
            name, vpkm, 100*vpkm/rail);
    end
end
end

function ab = ef4_autotune_input_backoff(x_osr, bw_hz, cfg)
ab = struct();
ab.enabled = true;
ab.backoff_init = cfg.input_backoff;
ab.backoff_sel = cfg.input_backoff;
ab.select_reason = 'init';
ab.require_clean = logical(cfg.ef4_autobackoff.require_clean);
ab.rail_ratio_max = cfg.ef4_autobackoff.rail_ratio_max;
ab.metric_domain = char(lower(string(getfield_default(cfg.ef4_autobackoff, 'metric_domain', 'bb'))));
ab.rf_require_ofdm_valid = logical(getfield_default(cfg.ef4_autobackoff, 'rf_require_ofdm_valid', true));
ab.rf_corr_min = getfield_default(cfg.ef4_autobackoff, 'rf_corr_min', 0.90);

A_hi = min(cfg.input_backoff, cfg.input_clip);
A_lo = min(A_hi, cfg.ef4_autobackoff.min);
step = cfg.ef4_autobackoff.step;

A_list = A_hi:-step:A_lo;
if isempty(A_list)
    A_list = A_hi;
end
if abs(A_list(end) - A_lo) > 1e-12
    A_list = [A_list, A_lo];
end
A_list = unique(round(A_list, 6), 'stable');
nA = numel(A_list);

evm_bb = inf(1, nA);
sndr_bb = -inf(1, nA);
rail_ratio = inf(1, nA);
ov_cnt = zeros(1, nA);
sat_cnt = zeros(1, nA);
is_feasible = false(1, nA);
rf_corr_peak = nan(1, nA);
rf_ofdm_valid = false(1, nA);

for i = 1:nA
    A = A_list(i);
    [i_i16, q_i16, x_ref_clip] = quantize_iq_q15(A * x_osr, cfg.input_clip);
    [yI, yQ, dbg] = ef4_arch_process_iq(int64(i_i16), int64(q_i16), cfg);
    if strcmpi(ab.metric_domain, 'rf_dig')
        y_rf_tune = synth_rf_from_iq_pm1(yI, yQ, cfg.fc_hz, cfg.Fs_dsm_main, cfg.rf_mode);
        met_tune = eval_if_metrics_rf_final_core( ...
            y_rf_tune, yI, yQ, x_ref_clip, cfg.Fs_dsm_main, cfg.Fs_bb, ...
            cfg.osr_main, cfg.fc_hz, bw_hz, cfg, 'digital', []);
        evm_bb(i) = met_tune.EVM_percent;
        sndr_bb(i) = met_tune.SNDR_dB;
        rf_corr_peak(i) = getfield_default(met_tune, 'CorrPeak', NaN);
        ofdm_t = getfield_default(met_tune, 'ofdm', struct());
        rf_ofdm_valid(i) = logical(getfield_default(ofdm_t, 'valid', false));
    else
        met_bb = eval_if_metrics_from_bb_iq_core(yI, yQ, x_ref_clip, cfg.Fs_dsm_main, cfg.Fs_bb, cfg.osr_main, bw_hz, cfg);
        evm_bb(i) = met_bb.EVM_percent;
        sndr_bb(i) = met_bb.SNDR_dB;
    end

    rail_ratio(i) = ef4_dbg_rail_ratio(dbg, cfg.ef4.acc_w);
    ov_cnt(i) = double(dbg.ov_count);
    sat_cnt(i) = double(dbg.sat_hi + dbg.sat_lo);
    clean_ok = (~ab.require_clean) || ((ov_cnt(i) == 0) && (sat_cnt(i) == 0));
    rf_ok = true;
    if strcmpi(ab.metric_domain, 'rf_dig')
        if ab.rf_require_ofdm_valid
            rf_ok = rf_ok && rf_ofdm_valid(i);
        end
        if isfinite(ab.rf_corr_min)
            rf_ok = rf_ok && isfinite(rf_corr_peak(i)) && (rf_corr_peak(i) >= ab.rf_corr_min);
        end
    end
    is_feasible(i) = clean_ok && (rail_ratio(i) <= ab.rail_ratio_max) && rf_ok;
end

if any(is_feasible)
    idx_candidates = find(is_feasible);
    [~, irel] = min(evm_bb(idx_candidates));
    idx_sel = idx_candidates(irel);
    ab.select_reason = 'feasible_min_evm';
else
    [~, idx_sel] = min(evm_bb);
    ab.select_reason = 'no_feasible_min_evm_relaxed';
    warning(['EF4 auto-backoff found no candidate meeting constraints. ', ...
        'Select min-EVM relaxed point; consider reducing input_backoff or retuning EF4 coefficients.']);
end

ab.backoff_sel = A_list(idx_sel);
ab.evm_bb_sel = evm_bb(idx_sel);
ab.sndr_bb_sel = sndr_bb(idx_sel);
ab.rail_ratio_sel = rail_ratio(idx_sel);
ab.ov_sel = ov_cnt(idx_sel);
ab.sat_sel = sat_cnt(idx_sel);
ab.candidates = struct( ...
    'A', A_list, ...
    'evm_bb_percent', evm_bb, ...
    'sndr_bb_dB', sndr_bb, ...
    'rail_ratio', rail_ratio, ...
    'ov_count', ov_cnt, ...
    'sat_count', sat_cnt, ...
    'rf_corr_peak', rf_corr_peak, ...
    'rf_ofdm_valid', rf_ofdm_valid, ...
    'feasible', is_feasible);

if isfield(cfg.ef4_autobackoff, 'print') && cfg.ef4_autobackoff.print
    fprintf(['EF4 auto-backoff: A_init=%.4f -> A_sel=%.4f | reason=%s | ', ...
        'domain=%s | EVM=%.2f%% | SNDR=%.2f dB | rail=%.1f%% | ov=%d sat=%d\n'], ...
        ab.backoff_init, ab.backoff_sel, ab.select_reason, ...
        ab.metric_domain, ab.evm_bb_sel, ab.sndr_bb_sel, 100*ab.rail_ratio_sel, ...
        ab.ov_sel, ab.sat_sel);
end
end

function rr = ef4_dbg_rail_ratio(dbg, acc_w)
rail = double(2^(acc_w-1) - 1);
vpk = 0;
if isfield(dbg, 'vpk')
    vpk = max(vpk, double(dbg.vpk));
end
if isfield(dbg, 'vpk1')
    vpk = max(vpk, double(dbg.vpk1));
end
if isfield(dbg, 'vpk2')
    vpk = max(vpk, double(dbg.vpk2));
end
rr = vpk / max(rail, eps);
end

function [yI, yQ, dbg, arch] = ef4_arch_process_iq(i_i64, q_i64, cfg)
[yI, dI, aI] = ef4_arch_process_scalar(i_i64, cfg);
[yQ, dQ, aQ] = ef4_arch_process_scalar(q_i64, cfg);
dbg = merge_dbg(dI, dQ);
arch = struct();
arch.enabled = isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable;
arch.i = aI;
arch.q = aQ;
end

function [y, dbg, arch] = ef4_arch_process_scalar(x_i64, cfg)
arch = struct();
if ~(isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable)
    [y, dbg] = ef4_iir_fixed_model(x_i64, cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    arch.path = 'stage1_baseline_ef4';
    return;
end

ra = cfg.routeA_arch;
if isfield(ra, 'multi_lane') && isfield(ra.multi_lane, 'enable') && ra.multi_lane.enable
    L = round(getfield_default(ra.multi_lane, 'lanes', 4));
    L = max(2, L);
    N = numel(x_i64);
    y = zeros(N, 1);
    dbg = empty_dbg();
    lane_dbg = repmat(empty_dbg(), 1, L);
    cfg_lane = cfg;
    cfg_lane.routeA_arch.multi_lane.enable = false;
    for lane = 1:L
        idx = lane:L:N;
        [yl, dl, ~] = ef4_arch_process_scalar(x_i64(idx), cfg_lane);
        y(idx) = yl;
        lane_dbg(lane) = dl;
        dbg.ov_count = dbg.ov_count + dl.ov_count;
        dbg.sat_hi = dbg.sat_hi + dl.sat_hi;
        dbg.sat_lo = dbg.sat_lo + dl.sat_lo;
        dbg.vpk = max(dbg.vpk, dl.vpk);
    end
    arch.path = 'stage4_multilane';
    arch.lanes = L;
    arch.lane_dbg = lane_dbg;
else
    [y, dbg, arch] = ef4_arch_stage23_scalar(x_i64, cfg);
end
end

function [y, dbg, arch] = ef4_arch_stage23_scalar(x_i64, cfg)
ra = cfg.routeA_arch;
x_eff = x_i64(:);
arch = struct();
arch.path = 'stage1_baseline_ef4';

if isfield(ra, 'lookahead') && isfield(ra.lookahead, 'enable') && ra.lookahead.enable
    alpha = getfield_default(ra.lookahead, 'alpha', 0.25);
    xd = double(x_eff);
    xd2 = xd + alpha * [0; diff(xd)];
    xd2 = max(min(xd2, 2^15-1), -2^15);
    x_eff = int64(round(xd2));
    arch.lookahead = struct('enabled', true, 'alpha', alpha, 'mode', getfield_default(ra.lookahead, 'mode', 'first_diff'));
else
    arch.lookahead = struct('enabled', false);
end

if isfield(ra, 'bus_split') && isfield(ra.bus_split, 'enable') && ra.bus_split.enable
    lsb_bits = round(getfield_default(ra.bus_split, 'lsb_bits', 6));
    lsb_bits = min(max(lsb_bits, 1), 12);
    msb_core = lower(string(getfield_default(ra.bus_split, 'msb_core', 'ef4')));
    lsb_core = lower(string(getfield_default(ra.bus_split, 'lsb_core', 'ef4')));
    lsb_w = getfield_default(ra.bus_split, 'lsb_weight', 0.25);

    x_msb = bitshift(x_eff, -lsb_bits);
    x_msb_aligned = bitshift(x_msb, lsb_bits);
    x_lsb = x_eff - x_msb_aligned;

    [y_msb, d_msb] = run_dsm_core_by_name(x_msb_aligned, msb_core, cfg);
    [y_lsb, d_lsb] = run_dsm_core_by_name(x_lsb, lsb_core, cfg);

    y = sign_pm1(double(y_msb) + lsb_w * double(y_lsb));
    dbg = merge_dbg(d_msb, d_lsb);

    arch.path = 'stage2_bus_split';
    if isfield(ra, 'lookahead') && isfield(ra.lookahead, 'enable') && ra.lookahead.enable
        arch.path = 'stage3_bus_split_lookahead';
    end
    arch.bus_split = struct('lsb_bits', lsb_bits, 'msb_core', char(msb_core), 'lsb_core', char(lsb_core), 'lsb_weight', lsb_w);
    arch.branch = struct('msb_dbg', d_msb, 'lsb_dbg', d_lsb);
else
    [y, dbg] = ef4_iir_fixed_model(x_eff, cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    if isfield(ra, 'lookahead') && isfield(ra.lookahead, 'enable') && ra.lookahead.enable
        arch.path = 'stage3_lookahead_only';
    end
end
end

function var = mash_variant_name(cfg)
var = "mash22";
if isfield(cfg, 'mash') && isstruct(cfg.mash) && isfield(cfg.mash, 'variant') && ~isempty(cfg.mash.variant)
    var = lower(string(cfg.mash.variant));
end
if ~(var == "mash11" || var == "mash111" || var == "mash22")
    var = "mash22";
end
end

function name = mash_display_name(var)
v = lower(string(var));
if v == "mash11"
    name = 'MASH1-1';
elseif v == "mash111"
    name = 'MASH1-1-1';
else
    name = 'MASH2-2';
end
end

function tf = is_mash_multibit(cfg)
tf = true;
if isfield(cfg, 'mash') && isstruct(cfg.mash) && isfield(cfg.mash, 'output_mode') && ~isempty(cfg.mash.output_mode)
    mode = lower(string(cfg.mash.output_mode));
    if mode == "pm1" || mode == "1bit" || mode == "sign"
        tf = false;
    end
end
end

function mode = mash_rf_output_mode(cfg)
% Backward-compatible default is PM1 RF drive.
mode = "pm1";
if isfield(cfg, 'mash') && isstruct(cfg.mash) && isfield(cfg.mash, 'rf_output_mode') && ~isempty(cfg.mash.rf_output_mode)
    mode = lower(string(cfg.mash.rf_output_mode));
end
if ~(mode == "pm1" || mode == "1bit" || mode == "sign" || mode == "multibit" || mode == "raw" || mode == "match_bb")
    mode = "pm1";
end
if mode == "1bit" || mode == "sign"
    mode = "pm1";
elseif mode == "raw" || mode == "match_bb"
    mode = "multibit";
end
end

function [y_mash, dbg] = mash_fixed_model(x_i64, cfg)
v = mash_variant_name(cfg);
dcfg = resolve_mash_dither_cfg(cfg, v, numel(x_i64));
switch v
    case "mash11"
        [y_mash, dbg] = mash11_fixed_model(x_i64, cfg.m22.acc_w, cfg.m22.saturate, dcfg);
    case "mash111"
        [y_mash, dbg] = mash111_fixed_model(x_i64, cfg.m22.acc_w, cfg.m22.saturate, dcfg);
    otherwise
        [y_mash, dbg] = mash22_fixed_model(x_i64, cfg.m22.acc_w, cfg.m22.saturate, cfg.m22.b1, cfg.m22.b2);
end
end

function dcfg = resolve_mash_dither_cfg(cfg, variant, N)
dcfg = struct('enable', false, 'seq_i64', int64([]), 'amp_lsb', 0, 'pdf', "none");

if ~(variant == "mash11" || variant == "mash111")
    return;
end
if ~(isfield(cfg, 'mash') && isstruct(cfg.mash) && isfield(cfg.mash, 'dither') && isstruct(cfg.mash.dither))
    return;
end

ds = cfg.mash.dither;
if ~getfield_default(ds, 'enable', false)
    return;
end

var_list = getfield_default(ds, 'variants', {'mash11', 'mash111'});
if ischar(var_list) || isstring(var_list)
    var_list = cellstr(var_list);
end
allow = false;
if iscell(var_list)
    for i = 1:numel(var_list)
        if strcmpi(string(var_list{i}), string(variant))
            allow = true;
            break;
        end
    end
end
if ~allow
    return;
end

amp_lsb = round(getfield_default(ds, 'amp_lsb', 1));
if amp_lsb < 1
    return;
end
pdf = lower(string(getfield_default(ds, 'pdf', 'tpdf')));
if ~(pdf == "tpdf" || pdf == "uniform")
    pdf = "tpdf";
end

if pdf == "uniform"
    d = randi([-amp_lsb, amp_lsb], N, 1);
else
    u1 = randi([-amp_lsb, amp_lsb], N, 1);
    u2 = randi([-amp_lsb, amp_lsb], N, 1);
    d = round(0.5 * (u1 + u2));
end

dcfg.enable = true;
dcfg.seq_i64 = int64(d(:));
dcfg.amp_lsb = amp_lsb;
dcfg.pdf = pdf;
end

function [y_pm, dbg] = run_dsm_core_by_name(x_i64, core_name, cfg)
core = lower(string(core_name));
switch core
    case "ef4"
        [y_pm, dbg] = ef4_iir_fixed_model(x_i64, cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    case "ef2"
        [y_pm, dbg] = ef2_fixed_model(x_i64, cfg.ef2.acc_w, cfg.ef2.saturate, cfg.ef2.b1, cfg.ef2.b2);
    case "mash11"
        cfg_loc = cfg;
        if ~isfield(cfg_loc, 'mash') || ~isstruct(cfg_loc.mash)
            cfg_loc.mash = struct();
        end
        cfg_loc.mash.variant = 'mash11';
        [y_raw, dbg] = mash_fixed_model(x_i64, cfg_loc);
        if is_mash_multibit(cfg_loc)
            y_pm = double(y_raw);
        else
            y_pm = sign_pm1(y_raw);
        end
    case "mash111"
        cfg_loc = cfg;
        if ~isfield(cfg_loc, 'mash') || ~isstruct(cfg_loc.mash)
            cfg_loc.mash = struct();
        end
        cfg_loc.mash.variant = 'mash111';
        [y_raw, dbg] = mash_fixed_model(x_i64, cfg_loc);
        if is_mash_multibit(cfg_loc)
            y_pm = double(y_raw);
        else
            y_pm = sign_pm1(y_raw);
        end
    case "mash22"
        cfg_loc = cfg;
        if ~isfield(cfg_loc, 'mash') || ~isstruct(cfg_loc.mash)
            cfg_loc.mash = struct();
        end
        cfg_loc.mash.variant = 'mash22';
        [y_raw, dbg] = mash_fixed_model(x_i64, cfg_loc);
        if is_mash_multibit(cfg_loc)
            y_pm = double(y_raw);
        else
            y_pm = sign_pm1(y_raw);
        end
    case "mash"
        [y_raw, dbg] = mash_fixed_model(x_i64, cfg);
        if is_mash_multibit(cfg)
            y_pm = double(y_raw);
        else
            y_pm = sign_pm1(y_raw);
        end
    otherwise
        error('Unknown routeA_arch core: %s', core_name);
end
end

function [y_pm, dbg] = ef2_fixed_model(x_i64, acc_w, saturate, b1, b2)
N = numel(x_i64);
y_pm = zeros(N,1);
e1 = int64(0);
e2 = int64(0);
acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);
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

    e0 = y - q;
    e2 = e1;
    e1 = e0;
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_pm, dbg] = ef4_iir_fixed_model(x_i64, acc_w, saturate, coeff_shift, num_q, den_q)
N = numel(x_i64);
y_pm = zeros(N,1);

e1 = int64(0); e2 = int64(0); e3 = int64(0); e4 = int64(0);
h1 = int64(0); h2 = int64(0); h3 = int64(0); h4 = int64(0);

acc_max = int64(2^(acc_w-1) - 1);
acc_min = int64(-2^(acc_w-1));
acc_rng = int64(2^acc_w);
fs = int64(2^15 - 1);

ov = int64(0);
sat_hi = int64(0);
sat_lo = int64(0);
vpk = 0;

for n = 1:N
    acc_num = num_q(1)*e1 + num_q(2)*e2 + num_q(3)*e3 + num_q(4)*e4 ...
            - den_q(1)*h1 - den_q(2)*h2 - den_q(3)*h3 - den_q(4)*h4;
    h0 = round_shift_int64(acc_num, coeff_shift);
    h0 = wrap_to_width(h0, acc_w);

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
    vpk = max(vpk, abs(double(y)));
end
dbg = struct('ov_count', ov, 'sat_hi', sat_hi, 'sat_lo', sat_lo, 'vpk', vpk);
end

function [y_mash, dbg] = mash11_fixed_model(x_i64, acc_w, saturate, dither_cfg)
if nargin < 4 || ~isstruct(dither_cfg)
    dither_cfg = struct('enable', false, 'seq_i64', int64([]));
end

d1_seq = int64([]);
if getfield_default(dither_cfg, 'enable', false)
    d1_seq = int64(getfield_default(dither_cfg, 'seq_i64', int64([])));
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

dbg = struct( ...
    'ov_count', d1.ov_count + d2.ov_count, ...
    'sat_hi', d1.sat_hi + d2.sat_hi, ...
    'sat_lo', d1.sat_lo + d2.sat_lo, ...
    'vpk1', d1.vpk, ...
    'vpk2', d2.vpk, ...
    'dither_enable', logical(getfield_default(dither_cfg, 'enable', false)), ...
    'dither_amp_lsb', getfield_default(dither_cfg, 'amp_lsb', 0), ...
    'dither_pdf', char(string(getfield_default(dither_cfg, 'pdf', "none"))));
end

function [y_mash, dbg] = mash111_fixed_model(x_i64, acc_w, saturate, dither_cfg)
if nargin < 4 || ~isstruct(dither_cfg)
    dither_cfg = struct('enable', false, 'seq_i64', int64([]));
end

d1_seq = int64([]);
if getfield_default(dither_cfg, 'enable', false)
    d1_seq = int64(getfield_default(dither_cfg, 'seq_i64', int64([])));
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
    d1_y2 = y2_pm(n) - y2_prev;
    d2_y3 = y3_pm(n) - 2*y3_prev1 + y3_prev2;
    y_mash(n) = y1_pm(n) + d1_y2 + d2_y3;
    y2_prev = y2_pm(n);
    y3_prev2 = y3_prev1;
    y3_prev1 = y3_pm(n);
end

dbg = struct( ...
    'ov_count', d1.ov_count + d2.ov_count + d3.ov_count, ...
    'sat_hi', d1.sat_hi + d2.sat_hi + d3.sat_hi, ...
    'sat_lo', d1.sat_lo + d2.sat_lo + d3.sat_lo, ...
    'vpk1', d1.vpk, ...
    'vpk2', d2.vpk, ...
    'vpk3', d3.vpk, ...
    'dither_enable', logical(getfield_default(dither_cfg, 'enable', false)), ...
    'dither_amp_lsb', getfield_default(dither_cfg, 'amp_lsb', 0), ...
    'dither_pdf', char(string(getfield_default(dither_cfg, 'pdf', "none"))));
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

y2_prev1 = 0;
y2_prev2 = 0;

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

    if y1_int >= 0
        q1 = fs;
        y1_pm = 1;
    else
        q1 = -fs;
        y1_pm = -1;
    end
    e10 = y1_int - q1;
    e12 = e11;
    e11 = e10;
    vpk1 = max(vpk1, abs(double(y1_int)));

    y2_raw = e10 + b1*e21 + b2*e22;
    if (y2_raw > acc_max) || (y2_raw < acc_min), ov = ov + 1; end
    y2_int = sat_or_wrap(y2_raw, acc_w, saturate, acc_rng, acc_min, acc_max);
    if y2_int == acc_max && y2_raw > acc_max, sat_hi = sat_hi + 1; end
    if y2_int == acc_min && y2_raw < acc_min, sat_lo = sat_lo + 1; end

    if y2_int >= 0
        q2 = fs;
        y2_pm = 1;
    else
        q2 = -fs;
        y2_pm = -1;
    end
    e20 = y2_int - q2;
    e22 = e21;
    e21 = e20;
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
    y = v;
    return;
end
half = int64(2^(sh-1));
if v >= 0
    y = bitshift(v + half, -sh);
else
    y = bitshift(v - half, -sh);
end
end

function y = wrap_to_width(v, w)
v = int64(v);
acc_min = int64(-2^(w-1));
modv = int64(2^w);
y = mod(v - acc_min, modv) + acc_min;
end

function met = eval_if_metrics_dual(y_rf, yI_pm, yQ_pm, x_ref_osr, Fs_dsm, Fs_bb, osr, fc_hz, bw_hz, cfg, y_rf_rm_obs)
if nargin < 11
    y_rf_rm_obs = [];
end
domain = lower(string(getfield_default(cfg.metrics, 'domain', 'dual')));
do_rf = any(strcmp(domain, ["rf", "dual"]));
do_bb = any(strcmp(domain, ["bb", "dual"]));

met = struct();
if do_rf
    met.rf = eval_if_metrics_from_rf_core(y_rf, x_ref_osr, Fs_dsm, Fs_bb, osr, fc_hz, bw_hz, cfg);
    if strcmpi(cfg.rf_mode, 'rtl_fs4') && ...
            isfield(cfg.metrics, 'rf_waveform_in_rtl_fs4') && ...
            ~cfg.metrics.rf_waveform_in_rtl_fs4
        met.rf.SNDR_dB = NaN;
        met.rf.EVM_percent = NaN;
        met.rf.AlignMode = 'n/a(rtl_fs4_tdm)';
    end
end
if do_bb
    met.bb = eval_if_metrics_from_bb_iq_core(yI_pm, yQ_pm, x_ref_osr, Fs_dsm, Fs_bb, osr, bw_hz, cfg);
end
if isfield(cfg, 'rf_final') && isfield(cfg.rf_final, 'enable') && cfg.rf_final.enable
    met.rf_final_digital = eval_if_metrics_rf_final_core(y_rf, yI_pm, yQ_pm, x_ref_osr, Fs_dsm, Fs_bb, osr, fc_hz, bw_hz, cfg, 'digital', y_rf_rm_obs);
    met.rf_final_analog = eval_if_metrics_rf_final_core(y_rf, yI_pm, yQ_pm, x_ref_osr, Fs_dsm, Fs_bb, osr, fc_hz, bw_hz, cfg, 'analog', y_rf_rm_obs);
    % Backward-compatible alias.
    met.rf_final = met.rf_final_analog;
end

% Stage-4 multi-lane: BB_core direct-domain metric can be misleading due
% lane-interleaved internal observation point. Optionally proxy BB_core
% from RF_Dig reconstructed metric for comparable staged reporting.
if do_bb && isfield(met, 'rf_final_digital')
    ml_en = false;
    bb_proxy = false;
    if isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable ...
            && isfield(cfg.routeA_arch, 'multi_lane') && isfield(cfg.routeA_arch.multi_lane, 'enable') ...
            && cfg.routeA_arch.multi_lane.enable
        ml_en = true;
        bb_proxy = logical(getfield_default(cfg.routeA_arch.multi_lane, 'bb_proxy_from_rf_dig', false));
    end
    if ml_en && bb_proxy
        met.bb = met.rf_final_digital;
        met.bb.AlignMode = ['proxy_rf_dig:' met.rf_final_digital.AlignMode];
        met.bb.proxy_source = 'rf_final_digital';
    end
end

src_primary = pick_metric_source(met, getfield_default(cfg.metrics, 'primary', 'bb'));
src_aclr = pick_metric_source(met, getfield_default(cfg.metrics, 'aclr_domain', 'rf'));
if isempty(src_primary) || isempty(src_aclr)
    error('No metric source available. Check cfg.metrics.domain.');
end

m_main = met.(src_primary);
m_aclr = met.(src_aclr);
met.SNDR_dB = m_main.SNDR_dB;
met.EVM_percent = m_main.EVM_percent;
met.N_recon = m_main.N_recon;
met.AlignMode = sprintf('%s:%s', src_primary, m_main.AlignMode);
met.Fs_eval = m_main.Fs_eval;
met.decim_eval = m_main.decim_eval;

met.ACLR_L_dBc = m_aclr.ACLR_L_dBc;
met.ACLR_R_dBc = m_aclr.ACLR_R_dBc;
met.ACLR_avg_dBc = m_aclr.ACLR_avg_dBc;
met.P_main = m_aclr.P_main;
met.P_adj_l = m_aclr.P_adj_l;
met.P_adj_r = m_aclr.P_adj_r;
met.source_primary = src_primary;
met.source_aclr = src_aclr;

if isfield(met, 'bb')
    met.SNDR_bb_dB = met.bb.SNDR_dB;
    met.EVM_bb_percent = met.bb.EVM_percent;
end
if isfield(met, 'rf')
    met.SNDR_rf_dB = met.rf.SNDR_dB;
    met.EVM_rf_percent = met.rf.EVM_percent;
end
if isfield(met, 'rf_final_analog')
    met.SNDR_rf_final_dB = met.rf_final_analog.SNDR_dB;
    met.EVM_rf_final_percent = met.rf_final_analog.EVM_percent;
end
end

function src = pick_metric_source(met, preferred)
preferred = lower(string(preferred));
pref_char = char(preferred);
if isfield(met, pref_char)
    src = pref_char;
    return;
end
if isfield(met, 'bb')
    src = 'bb';
    return;
end
if isfield(met, 'rf')
    src = 'rf';
    return;
end
src = '';
end

function v = getfield_default(s, f, dflt)
if isstruct(s) && isfield(s, f) && ~isempty(s.(f))
    v = s.(f);
else
    v = dflt;
end
end

function y = ext_bits_to_pm1(x)
if isempty(x)
    y = [];
    return;
end
x = double(x(:));
ux = unique(x(~isnan(x)));
if isempty(ux)
    y = [];
    return;
end
if all(ismember(ux, [0, 1]))
    y = 2*x - 1;
else
    y = sign(x);
    y(y == 0) = 1;
end
y = double(y(:));
end

function a = normalize_alg_enable(a)
if ~isstruct(a)
    a = struct();
end
if ~isfield(a, 'ef2'), a.ef2 = false; end
if ~isfield(a, 'ef4'), a.ef4 = true; end
if ~isfield(a, 'mash22'), a.mash22 = false; end
a.ef2 = logical(a.ef2);
a.ef4 = logical(a.ef4);
a.mash22 = logical(a.mash22);
end

function y_bb = rf_ddc_downconvert(x_rf, fc_hz, Fs_hz, use_analytic)
x_rf = double(x_rf(:));
n = (0:numel(x_rf)-1).';
if use_analytic && exist('hilbert', 'file') == 2
    x_ana = hilbert(x_rf);
    y_bb = x_ana .* exp(-1j * 2*pi * fc_hz/Fs_hz * n);
else
    i_bb = x_rf .* cos(2*pi * fc_hz/Fs_hz * n);
    q_bb = -x_rf .* sin(2*pi * fc_hz/Fs_hz * n);
    y_bb = 2 * (i_bb + 1j*q_bb);
end
end

function met = eval_if_metrics_from_rf_core(y_rf, x_ref_osr, Fs_dsm, ~, osr, fc_hz, bw_hz, cfg)
met = struct();
y_rf = double(y_rf(:));

[aclr_l, aclr_r, pmain, padj_l, padj_r] = aclr_from_psd(y_rf, Fs_dsm, bw_hz, fc_hz, cfg.aclr_adj_offset_hz, cfg.psd);
met.ACLR_L_dBc = aclr_l;
met.ACLR_R_dBc = aclr_r;
met.ACLR_avg_dBc = mean([aclr_l, aclr_r], 'omitnan');
met.P_main = pmain;
met.P_adj_l = padj_l;
met.P_adj_r = padj_r;

Fs_work = Fs_dsm;
osr_work = osr;
if strcmpi(cfg.rf_mode, 'rtl_fs4') && isfield(cfg, 'rf_eval') && ...
        isfield(cfg.rf_eval, 'rtl_fs4_reconstruct') && cfg.rf_eval.rtl_fs4_reconstruct
    [y_rf_baseband, x_ref, Fs_work, osr_work, rec_meta] = rtl_fs4_reconstruct_baseband(y_rf, x_ref_osr, Fs_dsm, osr, bw_hz, cfg.rf_eval);
    min_score = getfield_default(cfg.rf_eval, 'rtl_fs4_reconstruct_min_score', 0.55);
    if ~isfield(rec_meta, 'score') || rec_meta.score < min_score
        if isfield(cfg, 'rf_eval') && isfield(cfg.rf_eval, 'preselect_bpf') && cfg.rf_eval.preselect_bpf
            y_rf_eval = rf_if_preselect_bandpass(y_rf, Fs_dsm, fc_hz, bw_hz, cfg.rf_eval);
        else
            y_rf_eval = y_rf;
        end
        y_rf_baseband = rf_ddc_downconvert(y_rf_eval, fc_hz, Fs_dsm, getfield_default(cfg.rf_eval, 'use_analytic_ddc', true));
        x_ref = x_ref_osr(:);
        L = min(numel(y_rf_baseband), numel(x_ref));
        y_rf_baseband = y_rf_baseband(1:L);
        x_ref = x_ref(1:L);
        Fs_work = Fs_dsm;
        osr_work = osr;
    end
else
    if isfield(cfg, 'rf_eval') && isfield(cfg.rf_eval, 'preselect_bpf') && cfg.rf_eval.preselect_bpf
        y_rf_eval = rf_if_preselect_bandpass(y_rf, Fs_dsm, fc_hz, bw_hz, cfg.rf_eval);
    else
        y_rf_eval = y_rf;
    end
    y_rf_baseband = rf_ddc_downconvert(y_rf_eval, fc_hz, Fs_dsm, getfield_default(cfg.rf_eval, 'use_analytic_ddc', true));
    x_ref = x_ref_osr(:);
    L = min(numel(y_rf_baseband), numel(x_ref));
    y_rf_baseband = y_rf_baseband(1:L);
    x_ref = x_ref(1:L);
end

decim_eval = choose_eval_decim(Fs_work, bw_hz, osr_work, cfg.metrics.min_eval_fs_over_bw);
Fs_eval = Fs_work / decim_eval;
rec_stop_att = getfield_default(cfg.rf_eval, 'stop_att', cfg.rec_stop_att);
rec_zero_phase = getfield_default(cfg.rf_eval, 'zero_phase_reconstruct', false);
recCfg = struct('OSR', decim_eval, 'Fs_dsm', Fs_work, 'Fs_bb', Fs_eval, ...
    'BWch', bw_hz, 'StopAtt', rec_stop_att, 'UseFastFir', true, 'ZeroPhase', rec_zero_phase);
[y_bb, x_bb] = lp_reconstruct_and_decimate(y_rf_baseband, x_ref, recCfg);
n_settle_eval = max(64, round(cfg.n_settle_osr * (osr_work / decim_eval)));
[y_bb, x_bb] = lp_discard_settle_pair(y_bb, x_bb, n_settle_eval);
ofdm = eval_ofdm_metrics_cp_sync(y_bb, x_bb, Fs_eval, bw_hz, cfg);
if ofdm.valid
    m = ofdm_to_metric(ofdm);
else
    m = best_sndr_evm_with_variants(y_bb, x_bb);
end
met.SNDR_dB = m.SNDR_dB;
met.EVM_percent = m.EVM_rms_percent;
met.N_recon = m.N_used;
met.AlignMode = m.mode;
met.CorrPeak = m.corr_peak;
met.Fs_eval = Fs_eval;
met.decim_eval = decim_eval;
met.ofdm = ofdm;
end

function met = eval_if_metrics_rf_final_core(y_rf_in, yI_pm, yQ_pm, x_ref_osr, Fs_dsm, ~, osr, fc_hz, bw_hz, cfg, rf_kind, y_rf_rm_obs)
% RF_Final path:
% 1) Build RF from actual chain convention
% 2) Apply RF-front-end model (BPF + optional nonidealities)
% 3) DDC/reconstruct + LPF/decimation + EVM/SNDR/ACLR
met = struct();
if nargin < 12
    y_rf_rm_obs = [];
end
if nargin < 11 || isempty(rf_kind)
    rf_kind = 'analog';
end
rf_kind = lower(string(rf_kind));
is_digital = strcmp(rf_kind, "digital");
y_bb_tx = double(yI_pm(:)) + 1j*double(yQ_pm(:));
x_ref = x_ref_osr(:);
use_input_rf = false;
if strcmpi(cfg.rf_mode, 'rtl_fs4')
    use_input_rf = getfield_default(cfg.rf_final, 'rtl_fs4_use_bittrue_rf', true);
elseif strcmpi(cfg.rf_mode, 'rtl_fs4_rate_matched')
    use_input_rf = true;
end

if use_input_rf
    L = min([numel(y_bb_tx), numel(x_ref), numel(y_rf_in)]);
    y_bb_tx = y_bb_tx(1:L);
    x_ref = x_ref(1:L);
    x_rf_passband = double(y_rf_in(1:L));
else
    L = min(numel(y_bb_tx), numel(x_ref));
    y_bb_tx = y_bb_tx(1:L);
    x_ref = x_ref(1:L);
    n = (0:L-1).';
    x_rf_passband = real(y_bb_tx .* exp(1j * 2*pi*fc_hz/Fs_dsm * n));
end

rf_cfg = cfg.rf_final;
if is_digital
    if getfield_default(rf_cfg, 'digital_preselect_bpf', true)
        bpf_cfg = struct( ...
            'bpf_pass_bw_scale', getfield_default(rf_cfg, 'bpf_pass_bw_scale', 1.20), ...
            'bpf_guard_hz', getfield_default(rf_cfg, 'bpf_guard_hz', 3e6), ...
            'bpf_order', getfield_default(rf_cfg, 'bpf_order', 768), ...
            'bpf_zero_phase', getfield_default(rf_cfg, 'bpf_zero_phase', true));
        x_rf_bpf = rf_if_preselect_bandpass(x_rf_passband, Fs_dsm, fc_hz, bw_hz, bpf_cfg);
    else
        x_rf_bpf = x_rf_passband;
    end
    x_rf_fe = x_rf_bpf;
else
    if isfield(rf_cfg, 'bpf_enable') && rf_cfg.bpf_enable
        bpf_cfg = struct( ...
            'bpf_pass_bw_scale', getfield_default(rf_cfg, 'bpf_pass_bw_scale', 1.20), ...
            'bpf_guard_hz', getfield_default(rf_cfg, 'bpf_guard_hz', 3e6), ...
            'bpf_order', getfield_default(rf_cfg, 'bpf_order', 768), ...
            'bpf_zero_phase', getfield_default(rf_cfg, 'bpf_zero_phase', true));
        x_rf_bpf = rf_if_preselect_bandpass(x_rf_passband, Fs_dsm, fc_hz, bw_hz, bpf_cfg);
    else
        x_rf_bpf = x_rf_passband;
    end
    x_rf_fe = apply_rf_frontend_nonideal(x_rf_bpf, rf_cfg);
end

[aclr_l, aclr_r, pmain, padj_l, padj_r] = aclr_from_psd(x_rf_fe, Fs_dsm, bw_hz, fc_hz, cfg.aclr_adj_offset_hz, cfg.psd);
met.ACLR_L_dBc = aclr_l;
met.ACLR_R_dBc = aclr_r;
met.ACLR_avg_dBc = mean([aclr_l, aclr_r], 'omitnan');
met.P_main = pmain;
met.P_adj_l = padj_l;
met.P_adj_r = padj_r;

if strcmpi(cfg.rf_mode, 'rtl_fs4')
    % Important: fs4 demux is bit-true only on the raw TDM stream.
    % If RF frontend filtering/nonlinearity is already applied, prefer DDC path.
    if is_digital
        use_fs4_demux = getfield_default(rf_cfg, 'rtl_fs4_reconstruct_digital', true);
    else
        use_fs4_demux = getfield_default(rf_cfg, 'rtl_fs4_reconstruct_analog', false);
    end
    if use_fs4_demux
        rf_eval_cfg = cfg.rf_eval;
        if isfield(rf_cfg, 'rtl_fs4_reconstruct_impl')
            rf_eval_cfg.rtl_fs4_reconstruct_impl = rf_cfg.rtl_fs4_reconstruct_impl;
        end
        if isfield(rf_cfg, 'rtl_fs4_q_advance')
            rf_eval_cfg.rtl_fs4_q_advance = rf_cfg.rtl_fs4_q_advance;
        end
        if isfield(rf_cfg, 'rtl_fs4_autoselect')
            rf_eval_cfg.rtl_fs4_autoselect = rf_cfg.rtl_fs4_autoselect;
        end
        if isfield(rf_cfg, 'rtl_fs4_phase_offset')
            rf_eval_cfg.rtl_fs4_phase_offset = rf_cfg.rtl_fs4_phase_offset;
        end
        if isfield(rf_cfg, 'rtl_fs4_q_sign')
            rf_eval_cfg.rtl_fs4_q_sign = rf_cfg.rtl_fs4_q_sign;
        end
        if isfield(rf_cfg, 'rtl_fs4_q_shift')
            rf_eval_cfg.rtl_fs4_q_shift = rf_cfg.rtl_fs4_q_shift;
        end
        if isfield(rf_cfg, 'rtl_fs4_lock_fallback_autoselect')
            rf_eval_cfg.rtl_fs4_lock_fallback_autoselect = rf_cfg.rtl_fs4_lock_fallback_autoselect;
        end
        if isfield(rf_cfg, 'rtl_fs4_q_shift_list')
            rf_eval_cfg.rtl_fs4_q_shift_list = rf_cfg.rtl_fs4_q_shift_list;
        end
        if isfield(rf_cfg, 'rtl_fs4_q_sign_list')
            rf_eval_cfg.rtl_fs4_q_sign_list = rf_cfg.rtl_fs4_q_sign_list;
        end
        if getfield_default(rf_cfg, 'rtl_fs4_demux_pre_frontend', true)
            x_for_demux = x_rf_passband;
        else
            x_for_demux = x_rf_fe;
        end
        score_ref_mode = lower(string(getfield_default(rf_cfg, 'rtl_fs4_score_ref', 'x_ref')));
        if score_ref_mode == "y_lane"
            score_ref_in = y_bb_tx;
        else
            score_ref_in = x_ref;
        end
        [y_mix, x_ref_work, Fs_work, osr_work, rec_meta] = rtl_fs4_reconstruct_baseband(x_for_demux, x_ref, Fs_dsm, osr, bw_hz, rf_eval_cfg, score_ref_in);
        min_score = getfield_default(rf_cfg, 'rtl_fs4_reconstruct_min_score', getfield_default(cfg.rf_eval, 'rtl_fs4_reconstruct_min_score', 0.55));
        if ~isfield(rec_meta, 'score') || rec_meta.score < min_score
            % Fallback to direct DDC when fs4 demux confidence is low.
            y_mix = rf_ddc_downconvert(x_rf_fe, fc_hz, Fs_dsm, getfield_default(rf_cfg, 'use_analytic_ddc', true));
            x_ref_work = x_ref;
            Fs_work = Fs_dsm;
            osr_work = osr;
            rec_meta = struct('mode', sprintf('fallback_ddc(score=%.4f)', getfield_default(rec_meta, 'score', NaN)));
        end
    else
        y_mix = rf_ddc_downconvert(x_rf_fe, fc_hz, Fs_dsm, getfield_default(rf_cfg, 'use_analytic_ddc', true));
        x_ref_work = x_ref;
        Fs_work = Fs_dsm;
        osr_work = osr;
        rec_meta = struct('mode', 'ddc_rtl_fs4');
    end
else
    y_mix = rf_ddc_downconvert(x_rf_fe, fc_hz, Fs_dsm, getfield_default(rf_cfg, 'use_analytic_ddc', true));
    x_ref_work = x_ref;
    Fs_work = Fs_dsm;
    osr_work = osr;
    rec_meta = struct('mode', 'ddc_iq');
end

decim_eval = choose_eval_decim(Fs_work, bw_hz, osr_work, cfg.metrics.min_eval_fs_over_bw);
Fs_eval = Fs_work / decim_eval;
rec_stop_att = getfield_default(rf_cfg, 'stop_att', cfg.rec_stop_att);
rec_zero_phase = getfield_default(rf_cfg, 'zero_phase_reconstruct', false);
recCfg = struct('OSR', decim_eval, 'Fs_dsm', Fs_work, 'Fs_bb', Fs_eval, ...
    'BWch', bw_hz, 'StopAtt', rec_stop_att, 'UseFastFir', true, 'ZeroPhase', rec_zero_phase);
n_settle_eval = max(64, round(cfg.n_settle_osr * (osr_work / decim_eval)));

% A/B: causal chain vs zero-phase chain.
[y_bb_c, x_bb_c] = lp_reconstruct_and_decimate(y_mix, x_ref_work, recCfg);
[y_bb_c, x_bb_c] = lp_discard_settle_pair(y_bb_c, x_bb_c, n_settle_eval);
ofdm_c = eval_ofdm_metrics_cp_sync(y_bb_c, x_bb_c, Fs_eval, bw_hz, cfg);
if ofdm_c.valid
    m_c = ofdm_to_metric(ofdm_c);
else
    m_c = best_sndr_evm_with_variants(y_bb_c, x_bb_c);
end

m_z = struct('SNDR_dB', NaN, 'EVM_rms_percent', NaN, 'N_used', 0, 'mode', 'n/a');
y_bb_z = [];
x_bb_z = [];
ofdm_z = struct('valid', false);
if getfield_default(rf_cfg, 'enable_ab', true)
    [y_bb_z, x_bb_z] = lp_reconstruct_and_decimate_zerophase(y_mix, x_ref_work, recCfg);
    [y_bb_z, x_bb_z] = lp_discard_settle_pair(y_bb_z, x_bb_z, n_settle_eval);
    ofdm_z = eval_ofdm_metrics_cp_sync(y_bb_z, x_bb_z, Fs_eval, bw_hz, cfg);
    if ofdm_z.valid
        m_z = ofdm_to_metric(ofdm_z);
    else
        m_z = best_sndr_evm_with_variants(y_bb_z, x_bb_z);
    end
end

pick_mode = lower(string(getfield_default(rf_cfg, 'eval_pick', 'best_evm')));
use_zero = false;
switch pick_mode
    case "causal"
        use_zero = false;
    case "zero_phase"
        use_zero = true;
    otherwise
        if getfield_default(rf_cfg, 'enable_ab', true) && isfinite(m_z.EVM_rms_percent) && (m_z.EVM_rms_percent < m_c.EVM_rms_percent)
            use_zero = true;
        end
end

if use_zero
    m_sel = m_z;
    y_bb_sel = y_bb_z;
    x_bb_sel = x_bb_z;
    ofdm_sel = ofdm_z;
    chain_tag = 'zero_phase';
else
    m_sel = m_c;
    y_bb_sel = y_bb_c;
    x_bb_sel = x_bb_c;
    ofdm_sel = ofdm_c;
    chain_tag = 'causal';
end

met.SNDR_dB = m_sel.SNDR_dB;
met.EVM_percent = m_sel.EVM_rms_percent;
met.N_recon = m_sel.N_used;
met.AlignMode = sprintf('%s:%s', chain_tag, m_sel.mode);
met.Fs_eval = Fs_eval;
met.decim_eval = decim_eval;
met.reconstruct_mode = getfield_default(rec_meta, 'mode', 'n/a');
met.kind = char(rf_kind);
met.CorrPeak = m_sel.corr_peak;
met.ofdm = ofdm_sel;
met.ab = struct( ...
    'causal', struct('SNDR_dB', m_c.SNDR_dB, 'EVM_percent', m_c.EVM_rms_percent, 'mode', m_c.mode, 'ofdm_valid', ofdm_c.valid), ...
    'zero_phase', struct('SNDR_dB', m_z.SNDR_dB, 'EVM_percent', m_z.EVM_rms_percent, 'mode', m_z.mode, 'ofdm_valid', ofdm_z.valid), ...
    'selected', chain_tag);

% Stage1-only fallback: if strict bittrue_halfrate path is low-confidence,
% fallback to a rate-matched observation path for interpretable RF OFDM metrics.
is_stage1 = true;
if isfield(cfg, 'routeA_arch') && isfield(cfg.routeA_arch, 'enable') && cfg.routeA_arch.enable
    is_stage1 = false;
end
impl_now = lower(string(getfield_default(rf_cfg, 'rtl_fs4_reconstruct_impl', getfield_default(cfg.rf_eval, 'rtl_fs4_reconstruct_impl', ''))));
fb_enable = getfield_default(rf_cfg, 'stage1_halfrate_fallback_enable', true);
fb_on_score = getfield_default(rf_cfg, 'stage1_halfrate_fallback_on_low_score', true);
fb_on_ofdm = getfield_default(rf_cfg, 'stage1_halfrate_fallback_on_ofdm_invalid', true);
fb_score_min = getfield_default(rf_cfg, 'stage1_halfrate_fallback_score_min', getfield_default(cfg.rf_eval, 'rtl_fs4_reconstruct_min_score', 0.55));
score_now = getfield_default(rec_meta, 'score', NaN);
low_score = fb_on_score && isfinite(score_now) && (score_now < fb_score_min);
ofdm_invalid = fb_on_ofdm && ~logical(getfield_default(ofdm_sel, 'valid', false));
fb_scope = lower(string(getfield_default(rf_cfg, 'halfrate_fallback_scope', 'stage1')));
switch fb_scope
    case "all"
        fb_scope_ok = true;
    case "none"
        fb_scope_ok = false;
    otherwise
        fb_scope_ok = is_stage1;
end
need_fb = fb_enable && fb_scope_ok && strcmpi(cfg.rf_mode, 'rtl_fs4') && ...
    (impl_now == "bittrue_halfrate") && (low_score || ofdm_invalid);

if need_fb
    reason = {};
    if low_score
        reason{end+1} = sprintf('score<%.2f', fb_score_min); %#ok<AGROW>
    end
    if ofdm_invalid
        reason{end+1} = 'DigOFDM=0'; %#ok<AGROW>
    end
    reason_txt = strjoin(reason, '+');

    if ~isempty(y_rf_rm_obs)
        y_rf_rm = y_rf_rm_obs(:);
    else
        use_mash_multibit_rm = false;
        if isfield(cfg, 'alg_enable') && isfield(cfg.alg_enable, 'mash22') && cfg.alg_enable.mash22 ...
                && is_mash_multibit(cfg) && mash_rf_output_mode(cfg) == "multibit"
            use_mash_multibit_rm = true;
        end
        if use_mash_multibit_rm
            yI_rm = double(yI_pm(1:2:end));
            yQ_rm = double(yQ_pm(1:2:end));
        else
            yI_rm = sign_pm1(yI_pm(1:2:end));
            yQ_rm = sign_pm1(yQ_pm(1:2:end));
        end
        y_rf_rm = duc_fs4_rate_matched_pm1(yI_rm, yQ_rm);
    end

    cfg_fb = cfg;
    cfg_fb.rf_mode = 'rtl_fs4_rate_matched';
    if isfield(cfg_fb, 'rf_final')
        cfg_fb.rf_final.stage1_halfrate_fallback_enable = false;
    end
    met_pre = met;
    met = eval_if_metrics_rf_final_core(y_rf_rm, yI_pm, yQ_pm, x_ref_osr, Fs_dsm, [], osr, fc_hz, bw_hz, cfg_fb, rf_kind, []);
    met.fallback_used = true;
    met.fallback_reason = reason_txt;
    met.fallback_source = 'rtl_fs4_rate_matched';
    met.fallback_origin = struct( ...
        'reconstruct_mode', getfield_default(rec_meta, 'mode', 'n/a'), ...
        'score', score_now, ...
        'ofdm_valid', logical(getfield_default(ofdm_sel, 'valid', false)), ...
        'SNDR_dB', met_pre.SNDR_dB, ...
        'EVM_percent', met_pre.EVM_percent);
    return;
end
met.fallback_used = false;
met.fallback_reason = 'none';
met.fallback_source = 'none';

if getfield_default(rf_cfg, 'save_obs', true)
    maxn = round(getfield_default(rf_cfg, 'obs_max_len', 32768));
    maxn = max(1024, maxn);
    i1 = min(numel(y_bb_tx), maxn);
    i2 = min(numel(x_rf_passband), maxn);
    i3 = min(numel(x_rf_bpf), maxn);
    i4 = min(numel(y_bb_sel), maxn);
    i5 = min(numel(x_bb_sel), maxn);
    met.obs = struct();
    met.obs.y_lane = y_bb_tx(1:i1);
    met.obs.x_rf_passband = x_rf_passband(1:i2);
    met.obs.x_rf_bpf = x_rf_bpf(1:i3);
    met.obs.x_bb_rec = y_bb_sel(1:i4);
    met.obs.x_bb_ref = x_bb_sel(1:i5);
end
end

function y = apply_rf_frontend_nonideal(y_in, rf_cfg)
y = double(y_in(:));

% Optional serializer timing impairment model (lane skew + random jitter).
% Disabled by default, so legacy flows are unaffected.
ser = getfield_default(rf_cfg, 'serializer_timing', struct());
if isstruct(ser) && getfield_default(ser, 'enable', false)
    y = apply_serializer_timing_impairment(y, ser);
end

g = 10^(getfield_default(rf_cfg, 'tx_gain_db', 0.0) / 20);
y = g * y;

alpha3 = getfield_default(rf_cfg, 'pa_alpha3', 0.0);
if abs(alpha3) > 0
    y = y + alpha3 * (y.^3);
end

snr_db = getfield_default(rf_cfg, 'awgn_snr_db', inf);
if isfinite(snr_db)
    ps = mean(y.^2);
    if ps > 0
        pn = ps / (10^(snr_db/10));
        y = y + sqrt(max(pn, eps)) * randn(size(y));
    end
end
end

function y = apply_serializer_timing_impairment(y_in, ser_cfg)
y_in = double(y_in(:));
N = numel(y_in);
if N < 8
    y = y_in;
    return;
end

lanes = round(getfield_default(ser_cfg, 'lanes', 1));
lanes = max(1, lanes);

fs_eq = getfield_default(ser_cfg, 'fs_eq_hz', 1.0);
if ~isfinite(fs_eq) || fs_eq <= 0
    fs_eq = 1.0;
end

lane_skew_ps = getfield_default(ser_cfg, 'lane_skew_ps', 0.0);
lane_skew_vec_ps = resolve_lane_skew_vector(lane_skew_ps, lanes);
lane_shift_samp = lane_skew_vec_ps * 1e-12 * fs_eq; % expressed in UI/sample units

n = (0:N-1).';
y_acc = zeros(N, 1);
for li = 1:lanes
    s = zeros(N, 1);
    idx = li:lanes:N;
    if isempty(idx)
        continue;
    end
    s(idx) = y_in(idx);

    d = lane_shift_samp(li);
    if abs(d) > 0
        s = interp1(n, s, n - d, 'linear', 0);
    end
    y_acc = y_acc + s;
end

jitter_rms_ps = getfield_default(ser_cfg, 'jitter_rms_ps', 0.0);
if isfinite(jitter_rms_ps) && jitter_rms_ps > 0
    dj = (jitter_rms_ps * 1e-12 * fs_eq) .* randn(N, 1);
    y = interp1(n, y_acc, n - dj, 'linear', 0);
else
    y = y_acc;
end

if getfield_default(ser_cfg, 'hard_clip', false)
    y = max(min(y, 1.0), -1.0);
end
end

function v = resolve_lane_skew_vector(skew_ps, lanes)
if isscalar(skew_ps)
    s = double(skew_ps);
    if lanes <= 1 || abs(s) <= 0
        v = zeros(lanes, 1);
    else
        % Scalar is interpreted as full-span skew across lanes.
        v = linspace(-0.5, 0.5, lanes).' * s;
    end
else
    v = double(skew_ps(:));
    if isempty(v)
        v = zeros(lanes, 1);
    elseif numel(v) < lanes
        v = [v; repmat(v(end), lanes - numel(v), 1)];
    elseif numel(v) > lanes
        v = v(1:lanes);
    end
end
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
L = L - mod(L, 4); % keep full fs/4 periods
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

% Strict fs/4 demux to half-rate complex baseband (Fs/2).
% This is the preferred Stage-1 path to keep RF evaluation and CP-sync
% on a unified, physically consistent sampling domain.
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

ord = getfield_default(rf_eval_cfg, 'iq_interp_order', 192);
ord = max(32, round(ord));
if mod(ord, 2) ~= 0
    ord = ord + 1;
end
pbw_scale = getfield_default(rf_eval_cfg, 'iq_interp_pass_bw_scale', 1.20);
fc_lp = min(0.49*Fs_dsm, max(1.0, pbw_scale * (bw_hz/2)));
Wn = fc_lp / (Fs_dsm/2);
Wn = min(max(Wn, 1e-4), 0.9999);
h = fir1(ord, Wn, blackman(ord+1));

use_zero_phase = getfield_default(rf_eval_cfg, 'zero_phase_reconstruct', false) && (exist('filtfilt', 'file') == 2);
if use_zero_phase
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

if recon_impl == "bittrue_lock"
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
                        best.q_sign = qs;
                        best.q_shift = qsh;
                        best.phase = ph0;
                        best.mode = 'rtl_fs4_sparse_fallback';
                        y_bb_raw = y_c;
                        x_ref_f = x_c;
                    end
                end
            end
        end
    end
else
    for ph0 = phase_list(:).'
        for qs = q_sign_list(:).'
            for qsh = q_shift_list(:).'
                [y_c, x_c, c] = rtl_fs4_reconstruct_once(y_rf, x_ref_f_full, score_ref_f, filt_op, ph0, qs, qsh);
                if c > best.score
                    best.score = c;
                    best.q_sign = qs;
                    best.q_shift = qsh;
                    best.phase = ph0;
                    best.mode = 'rtl_fs4_sparse_interp';
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

Ih = zeros(2*M, 1);
Qh = zeros(2*M, 1);
Ih(1:2:end) = i0;
Ih(2:2:end) = i2;
Qh(1:2:end) = q1;
Qh(2:2:end) = q3;
Qh = sign(q_sign) * circshift(Qh, round(q_shift));

y_h = Ih + 1j*Qh;
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

function y_bp = rf_if_preselect_bandpass(x, Fs, fc_hz, bw_hz, rf_eval_cfg)
x = x(:);
nyq = Fs/2;
pass_bw = rf_eval_cfg.bpf_pass_bw_scale * bw_hz;
fpass1 = max(1, fc_hz - pass_bw/2);
fpass2 = min(nyq*0.999, fc_hz + pass_bw/2);
fstop1 = max(1, fpass1 - rf_eval_cfg.bpf_guard_hz);
fstop2 = min(nyq*0.9995, fpass2 + rf_eval_cfg.bpf_guard_hz);

if (fstop1 <= 0) || (fstop2 >= nyq) || (fpass1 >= fpass2) || (fstop1 >= fpass1) || (fpass2 >= fstop2)
    y_bp = x;
    return;
end

[b, ~] = cached_bandpass_fir(Fs, fpass1, fpass2, fstop1, fstop2, rf_eval_cfg.bpf_order);
use_zero_phase = getfield_default(rf_eval_cfg, 'bpf_zero_phase', false);
if use_zero_phase && exist('filtfilt', 'file') == 2
    y_bp = filtfilt(b, 1, double(x));
else
    y_bp = filter(b, 1, x);
end
end

function [b, gd] = cached_bandpass_fir(Fs, fpass1, fpass2, fstop1, fstop2, ord_req)
persistent bpCache
if isempty(bpCache)
    bpCache = containers.Map('KeyType', 'char', 'ValueType', 'any');
end
key = sprintf('Fs=%.9g;Fp1=%.9g;Fp2=%.9g;Fs1=%.9g;Fs2=%.9g;N=%d', Fs, fpass1, fpass2, fstop1, fstop2, ord_req);
if isKey(bpCache, key)
    v = bpCache(key);
    b = v{1};
    gd = v{2};
    return;
end

N = round(ord_req);
if mod(N,2) ~= 0
    N = N + 1;
end
Wn = [fpass1 fpass2] / (Fs/2);
Wn(1) = max(Wn(1), 1e-6);
Wn(2) = min(Wn(2), 0.999999);
if Wn(1) >= Wn(2)
    b = 1;
    gd = 0;
    bpCache(key) = {b, gd};
    return;
end
b = fir1(N, Wn, 'bandpass', blackman(N+1));
gd = floor((numel(b)-1)/2);
bpCache(key) = {b, gd};
end

function met = eval_if_metrics_from_bb_iq_core(yI_pm, yQ_pm, x_ref_osr, Fs_dsm, ~, osr, bw_hz, cfg)
met = struct();
y_bb_raw = double(yI_pm(:)) + 1j*double(yQ_pm(:));

[aclr_l, aclr_r, pmain, padj_l, padj_r] = aclr_from_psd(y_bb_raw, Fs_dsm, bw_hz, 0, cfg.aclr_adj_offset_hz, cfg.psd);
met.ACLR_L_dBc = aclr_l;
met.ACLR_R_dBc = aclr_r;
met.ACLR_avg_dBc = mean([aclr_l, aclr_r], 'omitnan');
met.P_main = pmain;
met.P_adj_l = padj_l;
met.P_adj_r = padj_r;

x_ref = x_ref_osr(:);
L = min(numel(y_bb_raw), numel(x_ref));
y_bb_raw = y_bb_raw(1:L);
x_ref = x_ref(1:L);

decim_eval = choose_eval_decim(Fs_dsm, bw_hz, osr, cfg.metrics.min_eval_fs_over_bw);
Fs_eval = Fs_dsm / decim_eval;
recCfg = struct('OSR', decim_eval, 'Fs_dsm', Fs_dsm, 'Fs_bb', Fs_eval, ...
    'BWch', bw_hz, 'StopAtt', cfg.rec_stop_att, 'UseFastFir', true);
[y_bb, x_bb] = lp_reconstruct_and_decimate(y_bb_raw, x_ref, recCfg);
n_settle_eval = max(64, round(cfg.n_settle_osr * (osr / decim_eval)));
[y_bb, x_bb] = lp_discard_settle_pair(y_bb, x_bb, n_settle_eval);
m = best_sndr_evm_with_variants(y_bb, x_bb);
met.SNDR_dB = m.SNDR_dB;
met.EVM_percent = m.EVM_rms_percent;
met.N_recon = m.N_used;
met.AlignMode = m.mode;
met.Fs_eval = Fs_eval;
met.decim_eval = decim_eval;
end

function m_best = best_sndr_evm_with_variants(y, x_ref)
cands = {
    y,                  'y'
    -y,                 '-y'
    1j*y,               'j*y'
    -1j*y,              '-j*y'
    conj(y),            'conj(y)'
    -conj(y),           '-conj(y)'
    1j*conj(y),         'j*conj(y)'
    -1j*conj(y),        '-j*conj(y)'
};
m_best = struct('SNDR_dB', -Inf, 'EVM_rms_percent', Inf, 'N_used', 0, 'mode', 'none', 'corr_peak', NaN);
for k = 1:size(cands, 1)
    yk = cands{k, 1};
    mode = cands{k, 2};
    al = lp_align_and_ls_gain(yk, x_ref);
    mk = lp_calc_sndr_evm(al.y_aligned, al.x_aligned);
    cpk = abs((al.y_aligned' * al.x_aligned) / (norm(al.y_aligned) * norm(al.x_aligned) + eps));
    if mk.SNDR_dB > m_best.SNDR_dB
        m_best.SNDR_dB = mk.SNDR_dB;
        m_best.EVM_rms_percent = mk.EVM_rms_percent;
        m_best.N_used = numel(al.x_aligned);
        m_best.mode = mode;
        m_best.corr_peak = cpk;
    end
end
end

function m = ofdm_to_metric(ofdm)
m = struct();
m.SNDR_dB = ofdm.SNDR_dB;
m.EVM_rms_percent = ofdm.EVM_percent;
m.N_used = ofdm.N_used;
m.mode = ['ofdm_cp:' ofdm.mode];
m.corr_peak = ofdm.CorrPeak;
end

function rep = eval_ofdm_metrics_cp_sync(y_in, x_in, Fs_in, bw_hz, cfg)
rep = struct('valid', false, 'SNDR_dB', NaN, 'EVM_percent', NaN, ...
    'CorrPeak', NaN, 'N_used', 0, 'mode', 'n/a');
if ~(isfield(cfg, 'metrics') && getfield_default(cfg.metrics, 'rf_ofdm_eval_enable', true))
    return;
end
if ~isfield(cfg, 'Nfft') || ~isfield(cfg, 'Ncp') || ~isfield(cfg, 'Fs_bb')
    return;
end

Nfft = round(cfg.Nfft);
Ncp = round(cfg.Ncp);
if Nfft <= 0 || Ncp < 0
    return;
end
symLen = Nfft + Ncp;

Fs_bb = cfg.Fs_bb;
ratio = Fs_in / Fs_bb;
D = round(ratio);
if D < 1 || abs(ratio - D) > 1e-6
    rep.mode = sprintf('skip_nonint_decim(ratio=%.6f)', ratio);
    return;
end

y = y_in(:);
x = x_in(:);
if D > 1
    recCfg = struct('OSR', D, 'Fs_dsm', Fs_in, 'Fs_bb', Fs_bb, ...
        'BWch', bw_hz, 'StopAtt', getfield_default(cfg, 'rec_stop_att', 80), ...
        'UseFastFir', true, 'ZeroPhase', true);
    [y, x] = lp_reconstruct_and_decimate(y, x, recCfg);
end

L = min(numel(y), numel(x));
y = y(1:L);
x = x(1:L);
if L < 3*symLen
    rep.mode = sprintf('too_short(L=%d)', L);
    return;
end

cp_syms = round(getfield_default(cfg.metrics, 'rf_ofdm_cp_search_syms', 24));
cp_syms = max(4, cp_syms);
[st_x, cp_x] = ofdm_cp_find_start(x, Nfft, Ncp, cp_syms);
min_syms = round(getfield_default(cfg.metrics, 'rf_ofdm_min_syms', 8));
min_corr = getfield_default(cfg.metrics, 'rf_ofdm_min_corr', 0.80);

cands = {
    y,            'y'
    -y,           '-y'
    1j*y,         'j*y'
    -1j*y,        '-j*y'
    conj(y),      'conj(y)'
    -conj(y),     '-conj(y)'
    1j*conj(y),   'j*conj(y)'
    -1j*conj(y),  '-j*conj(y)'
};

best = struct('SNDR_dB', -Inf, 'EVM_percent', Inf, 'CorrPeak', NaN, ...
    'N_used', 0, 'mode', 'no_candidate', 'cp', NaN, 'st_y', 1, 'nSym', 0, 'nSc', 0, 'cand', 'none');

for kk = 1:size(cands, 1)
    yk = cands{kk, 1};
    cand_name = cands{kk, 2};
    [st_y, cp_y] = ofdm_cp_find_start(yk, Nfft, Ncp, cp_syms);
    [Yf, Xf, nSym] = ofdm_fft_extract(yk, x, st_y, st_x, Nfft, Ncp);
    if nSym < max(2, min_syms)
        continue;
    end
    p = mean(abs(Xf).^2, 2);
    if isempty(p) || max(p) <= 0
        continue;
    end
    thr_db = getfield_default(cfg.metrics, 'rf_ofdm_pow_thr_db', -35);
    thr = max(p) * 10^(thr_db/10);
    use = p > thr;
    if nnz(use) < 16
        continue;
    end

    Xuse = Xf(use, :);
    Yuse = Yf(use, :);
    H = sum(Yuse .* conj(Xuse), 2) ./ (sum(abs(Xuse).^2, 2) + eps);
    Yeq = bsxfun(@rdivide, Yuse, (H + eps));
    E = Yeq - Xuse;

    sigP = sum(abs(Xuse(:)).^2);
    errP = sum(abs(E(:)).^2);
    sndr = 10*log10((sigP + eps) / (errP + eps));
    evm = sqrt(errP / (sigP + eps)) * 100;
    corr_pk = abs((Yeq(:)' * Xuse(:)) / (norm(Yeq(:)) * norm(Xuse(:)) + eps));
    if sndr > best.SNDR_dB
        best.SNDR_dB = sndr;
        best.EVM_percent = evm;
        best.CorrPeak = corr_pk;
        best.N_used = numel(Xuse);
        best.cp = cp_y;
        best.st_y = st_y;
        best.nSym = nSym;
        best.nSc = nnz(use);
        best.cand = cand_name;
    end
end

if ~isfinite(best.SNDR_dB)
    rep.mode = 'no_valid_candidate';
    return;
end

rep.SNDR_dB = best.SNDR_dB;
rep.EVM_percent = best.EVM_percent;
rep.CorrPeak = best.CorrPeak;
rep.N_used = best.N_used;
rep.mode = sprintf('D=%d,cand=%s,stY=%d,stX=%d,sym=%d,sc=%d,cp=%.3g/%.3g', ...
    D, best.cand, best.st_y, st_x, best.nSym, best.nSc, best.cp, cp_x);
rep.valid = (best.CorrPeak >= min_corr);
if ~rep.valid
    rep.mode = [rep.mode, sprintf(',lowCorr(%.3f<%.3f)', best.CorrPeak, min_corr)];
end
end

function [start_idx, score_best] = ofdm_cp_find_start(x, Nfft, Ncp, nSymUse)
x = x(:);
symLen = Nfft + Ncp;
max_start = min(symLen, numel(x) - (Nfft + Ncp) + 1);
if max_start < 1
    start_idx = 1;
    score_best = NaN;
    return;
end

score = zeros(max_start, 1);
for s = 1:max_start
    pos = s;
    cnt = 0;
    acc = 0;
    while (pos + Nfft + Ncp - 1) <= numel(x) && cnt < nSymUse
        a = x(pos : pos + Ncp - 1);
        b = x(pos + Nfft : pos + Nfft + Ncp - 1);
        acc = acc + abs(sum(conj(a) .* b));
        cnt = cnt + 1;
        pos = pos + symLen;
    end
    if cnt > 0
        score(s) = acc / cnt;
    end
end
[score_best, start_idx] = max(score);
end

function [Yf, Xf, nSym] = ofdm_fft_extract(y, x, st_y, st_x, Nfft, Ncp)
symLen = Nfft + Ncp;
L1 = numel(y) - st_y + 1;
L2 = numel(x) - st_x + 1;
nSym = floor(min(L1, L2) / symLen);
if nSym <= 0
    Yf = zeros(Nfft, 0);
    Xf = zeros(Nfft, 0);
    nSym = 0;
    return;
end

y_seg = y(st_y : st_y + nSym*symLen - 1);
x_seg = x(st_x : st_x + nSym*symLen - 1);
y_mat = reshape(y_seg, symLen, nSym);
x_mat = reshape(x_seg, symLen, nSym);
y_no_cp = y_mat(Ncp+1:end, :);
x_no_cp = x_mat(Ncp+1:end, :);
Yf = fft(y_no_cp, Nfft, 1);
Xf = fft(x_no_cp, Nfft, 1);
end

function decim = choose_eval_decim(Fs_dsm, bw_hz, osr_max, min_eval_fs_over_bw)
Fs_eval_min = min_eval_fs_over_bw * bw_hz;
decim_max = floor(Fs_dsm / Fs_eval_min);
decim_max = max(1, decim_max);
decim = min(osr_max, decim_max);
decim = 2^floor(log2(double(decim)));
decim = max(1, decim);
end

function [y_bb, x_bb] = lp_reconstruct_and_decimate_zerophase(y_dsm, x_ref, cfg)
% Zero-phase reconstruction for A/B debugging (removes group-delay ambiguity).
OSR = cfg.OSR;
Fnyq_bb = cfg.Fs_bb/2;
Fpass = min(0.98*(cfg.BWch/2), 0.95*Fnyq_bb);
Fstop = 0.995*Fnyq_bb;
if Fstop <= Fpass
    Fpass = 0.85*Fnyq_bb;
    Fstop = 0.95*Fnyq_bb;
end
trans_bw = max(Fstop - Fpass, cfg.Fs_dsm/4096);
N = ceil(8*cfg.Fs_dsm/trans_bw);
N = min(max(N, 63), 1023);
if mod(N, 2) ~= 0
    N = N + 1;
end
Wn = ((Fpass + Fstop)/2) / (cfg.Fs_dsm/2);
Wn = min(max(Wn, 1e-5), 0.9999);
b = fir1(N, Wn, blackman(N+1));

if exist('filtfilt', 'file') == 2
    y_f = filtfilt(b, 1, double(y_dsm(:)));
    x_f = filtfilt(b, 1, double(x_ref(:)));
else
    y1 = filter(b, 1, double(y_dsm(:)));
    x1 = filter(b, 1, double(x_ref(:)));
    gd = floor((numel(b)-1)/2);
    y_f = y1(gd+1:end);
    x_f = x1(gd+1:end);
end
y_bb = y_f(1:OSR:end);
x_bb = x_f(1:OSR:end);
end

function rep = run_duc_consistency_test(cfg)
rep = struct('corr_abs', NaN, 'evm_percent', NaN, 'sndr_dB', NaN, ...
    'best_mode', 'n/a', 'pass', false);
if ~strcmpi(cfg.rf_mode, 'rtl_fs4')
    rep.best_mode = 'skip(non_bittrue_mode)';
    rep.pass = true;
    return;
end
if ~(isfield(cfg, 'rf_final') && isfield(cfg.rf_final, 'duc_consistency_test'))
    return;
end
tcfg = cfg.rf_final.duc_consistency_test;
N = round(getfield_default(tcfg, 'N', 8192));
N = max(2048, N);
f0 = getfield_default(tcfg, 'f0_hz', cfg.Fs_bb/16);
n = (0:N-1).';

x = exp(1j*2*pi*f0/cfg.Fs_dsm_main * n);
y_rf = real(x .* exp(1j*2*pi*cfg.fc_hz/cfg.Fs_dsm_main * n));
y_mix = 2 * y_rf .* exp(-1j*2*pi*cfg.fc_hz/cfg.Fs_dsm_main * n);

recCfg = struct('OSR', 1, 'Fs_dsm', cfg.Fs_dsm_main, 'Fs_bb', cfg.Fs_dsm_main, ...
    'BWch', max(2*f0, cfg.Fs_bb/8), 'StopAtt', 80, 'UseFastFir', true);
[y_rec, x_ref] = lp_reconstruct_and_decimate_zerophase(y_mix, x, recCfg);
[y_rec, x_ref] = lp_discard_settle_pair(y_rec, x_ref, 128);
m = best_sndr_evm_with_variants(y_rec, x_ref);

L = min(numel(y_rec), numel(x_ref));
if L > 0
    c = (y_rec(1:L)' * x_ref(1:L)) / (norm(y_rec(1:L)) * norm(x_ref(1:L)) + eps);
    rep.corr_abs = abs(c);
end
rep.evm_percent = m.EVM_rms_percent;
rep.sndr_dB = m.SNDR_dB;
rep.best_mode = m.mode;
rep.pass = (rep.corr_abs > 0.90) && (m.EVM_rms_percent < 20);
end

function [aclr_l, aclr_r, pmain, padj_l, padj_r] = aclr_from_psd(x, Fs, bw_hz, fc_hz, adj_offset_hz, psd_cfg)
[Pxx, f] = pwelch(x(:), hamming(min(psd_cfg.win_len, numel(x))), ...
    floor(min(psd_cfg.win_len, numel(x))/2), psd_cfg.nfft, Fs, 'centered');
df = mean(diff(f));

adj = max(adj_offset_hz, bw_hz);
pmain = band_power(Pxx, f, fc_hz - bw_hz/2, fc_hz + bw_hz/2, df);
padj_l = band_power(Pxx, f, (fc_hz - adj) - bw_hz/2, (fc_hz - adj) + bw_hz/2, df);
padj_r = band_power(Pxx, f, (fc_hz + adj) - bw_hz/2, (fc_hz + adj) + bw_hz/2, df);

aclr_l = 10*log10((padj_l + eps) / (pmain + eps));
aclr_r = 10*log10((padj_r + eps) / (pmain + eps));
end

function P = band_power(Pxx, f, f1, f2, df)
idx = (f >= f1) & (f <= f2);
if ~any(idx)
    P = 0;
else
    P = sum(Pxx(idx)) * df;
end
end

function [Pdb, f] = calc_psd_db(x, Fs, nfft, win_len)
Nw = min(win_len, numel(x));
if Nw < 64
    Nw = min(64, numel(x));
end
[P, f] = pwelch(x(:), hamming(Nw), floor(Nw/2), nfft, Fs, 'centered');
Pdb = 10*log10(P + eps);
end

function print_metrics(name, met, dbg)
extra = '';
if isfield(met, 'SNDR_bb_dB') || isfield(met, 'SNDR_rf_dB')
    sn_bb = NaN; sn_rf = NaN; ev_bb = NaN; ev_rf = NaN;
    ac_bb = NaN; ac_rf = NaN;
    if isfield(met, 'SNDR_bb_dB'), sn_bb = met.SNDR_bb_dB; end
    if isfield(met, 'SNDR_rf_dB'), sn_rf = met.SNDR_rf_dB; end
    if isfield(met, 'EVM_bb_percent'), ev_bb = met.EVM_bb_percent; end
    if isfield(met, 'EVM_rf_percent'), ev_rf = met.EVM_rf_percent; end
    if isfield(met, 'bb') && isfield(met.bb, 'ACLR_avg_dBc'), ac_bb = met.bb.ACLR_avg_dBc; end
    if isfield(met, 'rf') && isfield(met.rf, 'ACLR_avg_dBc'), ac_rf = met.rf.ACLR_avg_dBc; end
    extra = sprintf(' | bb/rf ACLR=%.2f/%.2f dBc | bb/rf SNDR=%.2f/%.2f dB | bb/rf EVM=%.2f/%.2f %%', ...
        ac_bb, ac_rf, sn_bb, sn_rf, ev_bb, ev_rf);
end
if isfield(met, 'rf_final_digital')
    extra = [extra, sprintf(' | RF_Dig ACLR=%.2f dBc | SNDR=%.2f dB | EVM=%.2f %%', ...
        met.rf_final_digital.ACLR_avg_dBc, met.rf_final_digital.SNDR_dB, met.rf_final_digital.EVM_percent)];
    if isfield(met.rf_final_digital, 'CorrPeak')
        extra = [extra, sprintf(' | CorrDig=%.3f', met.rf_final_digital.CorrPeak)];
    end
    if isfield(met.rf_final_digital, 'reconstruct_mode')
        extra = [extra, sprintf(' | DigMode=%s', met.rf_final_digital.reconstruct_mode)];
    end
    if isfield(met.rf_final_digital, 'ofdm')
        extra = [extra, sprintf(' | DigOFDM=%d', logical(getfield_default(met.rf_final_digital.ofdm, 'valid', false)))];
    end
    if isfield(met.rf_final_digital, 'fallback_used')
        if met.rf_final_digital.fallback_used
            extra = [extra, sprintf(' | DigFB=1(%s)', getfield_default(met.rf_final_digital, 'fallback_reason', 'n/a'))];
        else
            extra = [extra, ' | DigFB=0'];
        end
    end
end
if isfield(met, 'rf_final_analog')
    extra = [extra, sprintf(' | RF_Ana ACLR=%.2f dBc | SNDR=%.2f dB | EVM=%.2f %%', ...
        met.rf_final_analog.ACLR_avg_dBc, met.rf_final_analog.SNDR_dB, met.rf_final_analog.EVM_percent)];
    if isfield(met.rf_final_analog, 'CorrPeak')
        extra = [extra, sprintf(' | CorrAna=%.3f', met.rf_final_analog.CorrPeak)];
    end
    if isfield(met.rf_final_analog, 'reconstruct_mode')
        extra = [extra, sprintf(' | AnaMode=%s', met.rf_final_analog.reconstruct_mode)];
    end
    if isfield(met.rf_final_analog, 'ofdm')
        extra = [extra, sprintf(' | AnaOFDM=%d', logical(getfield_default(met.rf_final_analog.ofdm, 'valid', false)))];
    end
    if isfield(met.rf_final_analog, 'fallback_used')
        if met.rf_final_analog.fallback_used
            extra = [extra, sprintf(' | AnaFB=1(%s)', getfield_default(met.rf_final_analog, 'fallback_reason', 'n/a'))];
        else
            extra = [extra, ' | AnaFB=0'];
        end
    end
    if isfield(met.rf_final_analog, 'ab')
        extra = [extra, sprintf(' | AB(c/z)=%.2f/%.2f %%', ...
            met.rf_final_analog.ab.causal.EVM_percent, met.rf_final_analog.ab.zero_phase.EVM_percent)];
    end
elseif isfield(met, 'rf_final')
    extra = [extra, sprintf(' | RF_Final ACLR=%.2f dBc | SNDR=%.2f dB | EVM=%.2f %%', ...
        met.rf_final.ACLR_avg_dBc, met.rf_final.SNDR_dB, met.rf_final.EVM_percent)];
end

fprintf('%s | ACLR L/R=%.2f/%.2f dBc (%s) | SNDR=%.2f dB | EVM=%.2f %% (%s) | mode=%s | FsEval=%.2f MHz%s | ov=%d sat=%d/%d\n', ...
    name, met.ACLR_L_dBc, met.ACLR_R_dBc, getfield_default(met, 'source_aclr', 'n/a'), ...
    met.SNDR_dB, met.EVM_percent, getfield_default(met, 'source_primary', 'n/a'), ...
    met.AlignMode, ...
    met.Fs_eval/1e6, ...
    extra, ...
    dbg.ov_count, dbg.sat_hi, dbg.sat_lo);
end

function sweep = run_stability_sweep(x_bb_ref, bw_ref_hz, cfg)
fprintf('\nRunning amplitude sweep for stability boundary...\n');
    [x_osr, ~] = osr_interpolate(x_bb_ref, cfg.osr_main, cfg.Fs_bb, bw_ref_hz, true);
x_osr = x_osr / max(rms(x_osr), eps);

A_list = cfg.sweep.A_list(:).';
ov_ef4 = zeros(size(A_list));
ov_m22 = zeros(size(A_list));

L = min(cfg.sweep.max_len, numel(x_osr));
x_unit = x_osr(1:L);

for i = 1:numel(A_list)
    A = A_list(i);
    [i_i16, q_i16] = quantize_iq_q15(A * x_unit, cfg.input_clip);

    [~, d4i] = ef4_iir_fixed_model(int64(i_i16), cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    [~, d4q] = ef4_iir_fixed_model(int64(q_i16), cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    [~, d22i] = mash22_fixed_model(int64(i_i16), cfg.m22.acc_w, cfg.m22.saturate, cfg.m22.b1, cfg.m22.b2);
    [~, d22q] = mash22_fixed_model(int64(q_i16), cfg.m22.acc_w, cfg.m22.saturate, cfg.m22.b1, cfg.m22.b2);

    ov_ef4(i) = double(d4i.ov_count + d4q.ov_count);
    ov_m22(i) = double(d22i.ov_count + d22q.ov_count);
end

sweep = struct();
sweep.A_list = A_list;
sweep.ov_ef4 = ov_ef4;
sweep.ov_m22 = ov_m22;
sweep.bw_ref_hz = bw_ref_hz;
end

function tradeoff = run_osr_tradeoff(x_bb_ref, bw_ref_hz, cfg)
fprintf('Running OSR16 vs OSR32 tradeoff...\n');
osr_list = cfg.tradeoff.osr_list;
n = numel(osr_list);

aclr_avg = zeros(1, n);
evm = zeros(1, n);
sndr = zeros(1, n);
ov = zeros(1, n);
fs_dsm = zeros(1, n);

for i = 1:n
    osr = osr_list(i);
    Fs_dsm = cfg.Fs_bb * osr;
    fs_dsm(i) = Fs_dsm;
    if is_fs4_mode(cfg.rf_mode)
        fc_test = Fs_dsm / 4;
    else
        fc_test = cfg.tradeoff.fc_hz;
    end
    if fc_test >= Fs_dsm/2
        error('Tradeoff fc %.3f MHz invalid for OSR=%d (Fs/2=%.3f MHz).', ...
            fc_test/1e6, osr, Fs_dsm/2/1e6);
    end

    [x_osr, ~] = osr_interpolate(x_bb_ref, osr, cfg.Fs_bb, bw_ref_hz, true);
    x_osr = x_osr / max(rms(x_osr), eps);
    x_ref_osr = cfg.input_backoff * x_osr;
    [i_i16, q_i16, x_ref_clip] = quantize_iq_q15(x_ref_osr, cfg.input_clip);

    [yI4, d4i] = ef4_iir_fixed_model(int64(i_i16), cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    [yQ4, d4q] = ef4_iir_fixed_model(int64(q_i16), cfg.ef4.acc_w, cfg.ef4.saturate, cfg.ef4.coeff_shift, cfg.ef4.num_q, cfg.ef4.den_q);
    yrf4 = synth_rf_from_iq_pm1(yI4, yQ4, fc_test, Fs_dsm, cfg.rf_mode);

    met = eval_if_metrics_dual(yrf4, yI4, yQ4, x_ref_clip, Fs_dsm, cfg.Fs_bb, osr, fc_test, bw_ref_hz, cfg);

    aclr_avg(i) = met.ACLR_avg_dBc;
    evm(i) = met.EVM_percent;
    sndr(i) = met.SNDR_dB;
    ov(i) = double(d4i.ov_count + d4q.ov_count);
end

tradeoff = struct();
tradeoff.osr_list = osr_list;
if is_fs4_mode(cfg.rf_mode)
    tradeoff.fc_hz = NaN;
else
    tradeoff.fc_hz = cfg.tradeoff.fc_hz;
end
tradeoff.fs_dsm_hz = fs_dsm;
tradeoff.aclr_avg_dBc = aclr_avg;
tradeoff.evm_percent = evm;
tradeoff.sndr_dB = sndr;
tradeoff.ov_count = ov;
tradeoff.rf_mode = cfg.rf_mode;
end

function plot_fig_1_baseband(results, out_fig)
fig = figure('Name', 'Fig1 Baseband Occupied BW', 'Color', 'w');
hold on; grid on;
for k = 1:numel(results)
    plot(results(k).psd.f_bb/1e6, results(k).psd.P_bb_dB, 'LineWidth', 1.2);
end
xlabel('Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('Fig1: Baseband Occupied Bandwidth');
leg = cell(1, numel(results));
for k = 1:numel(results)
    leg{k} = sprintf('BW target %.1f MHz (eff %.3f MHz)', ...
        results(k).bw_target_hz/1e6, results(k).bw_effective_hz/1e6);
end
legend(leg, 'Location', 'best');
saveas(fig, fullfile(out_fig, 'fig1_baseband_bw.png'));
end

function plot_fig_2_if(results, out_fig)
fig = figure('Name', 'Fig2 IF Spectrum', 'Color', 'w');
hold on; grid on;
for k = 1:numel(results)
    plot(results(k).psd.f_if/1e6, results(k).psd.P_if_in_dB, 'LineWidth', 1.2);
end
xlabel('Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title('Fig2: Upconverted IF Spectrum (Input Before DSM)');
leg = cell(1, numel(results));
for k = 1:numel(results)
    leg{k} = sprintf('BW %.3f MHz', results(k).bw_effective_hz/1e6);
end
legend(leg, 'Location', 'best');
saveas(fig, fullfile(out_fig, 'fig2_if_spectrum.png'));
end

function plot_fig_3_ef4_vs_ef2(results, out_fig)
fig = figure('Name', 'Fig3 EF4 vs EF2 PSD', 'Color', 'w');
for k = 1:numel(results)
    subplot(numel(results), 1, k);
    plot(results(k).psd.f_if/1e6, results(k).psd.P_ef4_dB, 'LineWidth', 1.2); hold on;
    plot(results(k).psd.f_if/1e6, results(k).psd.P_ef2_dB, 'LineWidth', 1.2);
    grid on;
    ylabel('PSD (dB/Hz)');
    title(sprintf('BW %.3f MHz: EF4-IIR vs EF2 (after DUC)', results(k).bw_effective_hz/1e6));
    legend('EF4-IIR', 'EF2', 'Location', 'best');
    if k == numel(results)
        xlabel('Frequency (MHz)');
    end
end
saveas(fig, fullfile(out_fig, 'fig3_ef4_vs_ef2_psd.png'));
end

function plot_fig_4_ef4_vs_mash22(results, out_fig)
k = numel(results);
r = results(k);

fig = figure('Name', 'Fig4 EF4 vs MASH22', 'Color', 'w');
subplot(2,1,1);
plot(r.psd.f_if/1e6, r.psd.P_ef4_dB, 'LineWidth', 1.2); hold on;
plot(r.psd.f_if/1e6, r.psd.P_m22_dB, 'LineWidth', 1.2);
grid on;
xlabel('Frequency (MHz)');
ylabel('PSD (dB/Hz)');
title(sprintf('Fig4a: PSD (BW %.3f MHz, after DUC)', r.bw_effective_hz/1e6));
legend('EF4-IIR', 'MASH2-2', 'Location', 'best');

subplot(2,1,2);
vals_aclr = [r.metrics.ef4.ACLR_avg_dBc, r.metrics.mash22.ACLR_avg_dBc];
vals_evm = [r.metrics.ef4.EVM_percent, r.metrics.mash22.EVM_percent];
yyaxis left;
bar([1 2], vals_aclr, 0.35);
ylabel('ACLR avg (dBc)');
yyaxis right;
bar([1.35 2.35], vals_evm, 0.35);
ylabel('EVM (%)');
set(gca, 'XTick', [1.175, 2.175], 'XTickLabel', {'EF4-IIR', 'MASH2-2'});
grid on;
title('Fig4b: ACLR and EVM');
saveas(fig, fullfile(out_fig, 'fig4_ef4_vs_mash22.png'));
end

function plot_fig_5_stability(sweep, out_fig)
fig = figure('Name', 'Fig5 Stability Sweep', 'Color', 'w');
plot(sweep.A_list, sweep.ov_ef4, '-o', 'LineWidth', 1.2); hold on;
plot(sweep.A_list, sweep.ov_m22, '-s', 'LineWidth', 1.2);
grid on;
xlabel('Input scale A');
ylabel('Overflow count (I+Q)');
title(sprintf('Fig5: Stability Boundary (BW %.3f MHz)', sweep.bw_ref_hz/1e6));
legend('EF4-IIR', 'MASH2-2', 'Location', 'northwest');
saveas(fig, fullfile(out_fig, 'fig5_stability_boundary.png'));
end

function plot_fig_6_osr_tradeoff(tradeoff, out_fig)
fig = figure('Name', 'Fig6 OSR Tradeoff', 'Color', 'w');
yyaxis left;
plot(tradeoff.osr_list, tradeoff.aclr_avg_dBc, '-o', 'LineWidth', 1.2); hold on;
ylabel('ACLR avg (dBc)');
yyaxis right;
plot(tradeoff.osr_list, tradeoff.evm_percent, '-s', 'LineWidth', 1.2);
ylabel('EVM (%)');
grid on;
xlabel('OSR');
if strcmpi(tradeoff.rf_mode, 'rtl_fs4')
    title('Fig6: OSR tradeoff (fc=Fs/4, EF4)');
else
    title(sprintf('Fig6: OSR tradeoff (fc=%.1f MHz, EF4)', tradeoff.fc_hz/1e6));
end
saveas(fig, fullfile(out_fig, 'fig6_osr16_vs_osr32_tradeoff.png'));
end

function y = fit_depth(x, depth)
x = x(:);
if numel(x) >= depth
    y = x(1:depth);
else
    y = [x; zeros(depth - numel(x), 1, 'like', x)];
end
end

function write_coe_int16_hex(filename, x_int16)
fid = fopen(filename, 'w');
if fid < 0
    error('Cannot open file: %s', filename);
end
fprintf(fid, 'memory_initialization_radix=16;\n');
fprintf(fid, 'memory_initialization_vector=\n');
u = typecast(int16(x_int16(:)), 'uint16');
for i = 1:numel(u)
    if i < numel(u)
        fprintf(fid, '%04X,\n', u(i));
    else
        fprintf(fid, '%04X;\n', u(i));
    end
end
fclose(fid);
end
