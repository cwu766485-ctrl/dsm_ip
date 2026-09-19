function Summary = run_tid32_thermo5_profile_bandwidth_sweep(varargin)
%RUN_TID32_THERMO5_PROFILE_BANDWIDTH_SWEEP Four-branch full-chain sweep.
% Delegates to the common frontend/profile flow so that interpolation, DPD,
% DPA/BPF, DDC, seeds, and acceptance policy cannot diverge by level count.
Summary = run_tid32_thermo3_profile_bandwidth_sweep( ...
    'thermo_levels', 5, 'thermo5_step', 7168, varargin{:});
end
