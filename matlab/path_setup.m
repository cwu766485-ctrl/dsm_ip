% path_setup.m
% Add the standalone dsm_ip MATLAB paths for IP comparison and the Cartesian
% DSM workspace.
%
% Usage:
%   cd matlab
%   path_setup

function path_setup()
  here = fileparts(mfilename('fullpath'));
  repo = fullfile(here, '..'); % matlab/.. = repo root

  addpath(genpath(fullfile(repo, 'matlab', 'scripts')));
  addpath(genpath(fullfile(repo, 'matlab', 'models')));
  addpath(genpath(fullfile(repo, 'matlab', 'dpd')));
  addpath(genpath(fullfile(repo, 'matlab', 'bittrue')));
  addpath(genpath(fullfile(repo, 'matlab', 'board_validation')));
  addpath(genpath(fullfile(repo, 'matlab', 'cartesian_dsm', 'dsm_singlebit')));
  addpath(genpath(fullfile(repo, 'matlab', 'cartesian_dsm', 'dsm_multibit')));
  addpath(genpath(fullfile(repo, 'matlab', 'cartesian_dsm', 'DSM_2nd', 'lp')));
end
