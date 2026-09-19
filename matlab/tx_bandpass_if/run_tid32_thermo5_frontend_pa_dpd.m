function [Results, Coefficients, Detail] = run_tid32_thermo5_frontend_pa_dpd(varargin)
%RUN_TID32_THERMO5_FRONTEND_PA_DPD Full five-level frontend/DPA experiment.
% Reuses the qualified ingress, two x2 interpolators, Q2.14 memory-DPD,
% BPF/DDC and OFDM receiver.  Only the thermometric TID/PA branch count is
% changed to four; this prevents model drift from duplicated implementation.
[Results, Coefficients, Detail] = run_tid32_thermo3_frontend_pa_dpd( ...
    'thermo_levels', 5, 'thermo5_step', 7168, varargin{:});
end
