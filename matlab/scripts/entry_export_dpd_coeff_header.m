% entry_export_dpd_coeff_header
% Export the default DPD calibration scenario to a Vitis C header.

path_setup;
header_path = export_dpd_coeff_header('scenario_index', 1);
assert(exist(header_path, 'file') == 2);
