cd(fileparts(mfilename('fullpath'))); % scripts/
cd('..');                             % matlab/
path_setup;
export_p1_rom_mem('profile', 'p1_256');
