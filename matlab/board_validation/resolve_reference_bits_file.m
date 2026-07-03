function path_out = resolve_reference_bits_file(repo_root, file_name, required)
% resolve_reference_bits_file
% Locate a preserved reference bitstream in either the handover package
% layout or the original Vivado xsim dump layout.

if nargin < 3
    required = true;
end

candidates = { ...
    fullfile(repo_root, 'fpga', 'vivado', 'cartesian_dsm', 'reference_bits', file_name), ...
    fullfile(repo_root, 'fpga', 'vivado', 'cartesian_dsm', 'cartesian_dsm.sim', 'sim_1', 'behav', 'xsim', file_name) ...
};

for k = 1:numel(candidates)
    if isfile(candidates{k})
        path_out = candidates{k};
        return;
    end
end

if required
    error('Reference bit file not found: %s', file_name);
end

path_out = '';
end
