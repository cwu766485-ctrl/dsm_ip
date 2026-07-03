cd(fileparts(mfilename('fullpath'))); % scripts/
cd('..');                             % matlab/
path_setup;
eval_profile_seven_metrics_from_xsim('profile', 'p1_64');
