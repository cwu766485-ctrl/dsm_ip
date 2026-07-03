% run_p0_eval_from_xsim.m
% Evaluate P0 metrics from dsm_ip xsim outputs.
%
% It reuses the existing evaluator:
%   plot_nominal_ofdm16qam_osr32_compare_v1(...)
%
% Required xsim dumps in verif/out_xsim_p0:
%   sim_bits_01.txt
%   sim_bits_01_ef1.txt
%   sim_bits_01_dsm2.txt
%   sim_bits_01_ef2.txt
%   sim_yout_signed_mash11_mb.txt
%
% Note:
%   Our TB currently emits sim_bits_01_lp1.txt / sim_bits_01_lp2.txt.
%   This script normalizes filenames by copying to the evaluator-expected names.

function out = run_p0_eval_from_xsim()
  here = fileparts(mfilename('fullpath'));    % .../matlab/scripts
  repo = fullfile(here, '..', '..');    % repo root

  xsim_dir = fullfile(repo, 'verif', 'out_xsim_p0');
  out_dir  = fullfile(repo, 'matlab', 'out');
  if exist(out_dir, 'dir') ~= 7
    mkdir(out_dir);
  end

  % Normalize file names for the legacy evaluator.
  map_copy(fullfile(xsim_dir, 'sim_bits_01_lp1.txt'), fullfile(xsim_dir, 'sim_bits_01.txt'));
  map_copy(fullfile(xsim_dir, 'sim_bits_01_lp2.txt'), fullfile(xsim_dir, 'sim_bits_01_dsm2.txt'));

  coe_i = fullfile(repo, 'matlab', 'cartesian_dsm', 'DSM_2nd', 'lp', 'core', 'coe', ...
    'I_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
  coe_q = fullfile(repo, 'matlab', 'cartesian_dsm', 'DSM_2nd', 'lp', 'core', 'coe', ...
    'Q_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.coe');
  meta_file = fullfile(repo, 'matlab', 'cartesian_dsm', 'DSM_2nd', 'lp', 'core', ...
    'stage1_meta_M16_Nfft64_Ncp16_Nsym500_OSR32_W16_DEPTH65536.mat');
  if exist(meta_file, 'file') ~= 2
    % Build minimal meta required by plot_nominal_ofdm16qam_osr32_compare_v1.
    meta.active_bins = [-26:-1 1:26];
    meta.OSR = 32;
    meta.Fs_dsm = 100e6;
    meta.Fs_bb = meta.Fs_dsm / meta.OSR;
    meta.Delta_f = meta.Fs_bb / 64;
    meta_file = fullfile(out_dir, 'p0_meta_fallback.mat');
    save(meta_file, 'meta');
  end
  out_prefix = fullfile(out_dir, 'p0_nominal_ofdm16qam_osr32_compare');

  out = plot_nominal_ofdm16qam_osr32_compare_v1(coe_i, coe_q, meta_file, xsim_dir, out_prefix);
end

function map_copy(src, dst)
  if exist(src, 'file') ~= 2
    error('Required source dump missing: %s', src);
  end
  copyfile(src, dst);
end
