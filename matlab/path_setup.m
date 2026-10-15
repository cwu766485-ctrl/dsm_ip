% Add only the MATLAB sources retained by the single-lane DSM study branch.
% Usage: cd matlab; path_setup

function path_setup()
  here = fileparts(mfilename('fullpath'));
  repo = fullfile(here, '..');
  addpath(fullfile(repo, 'matlab', 'scripts'));
  addpath(fullfile(repo, 'matlab', 'bittrue'));
  addpath(fullfile(repo, 'matlab', 'cartesian_dsm', 'dsm_singlebit'));
  addpath(fullfile(repo, 'matlab', 'cartesian_dsm', 'dsm_multibit'));
end
