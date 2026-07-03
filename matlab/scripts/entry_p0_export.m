% entry_p0_export.m
% Thin entrypoint for non-interactive MATLAB (-batch) use.

cd(fileparts(mfilename('fullpath')));  % scripts/
cd('..');                               % matlab/
path_setup;
export_p0_rom_mem;

