function paths = path_setup()
% path_setup
% Add the retained LP DSM MATLAB source folder to the MATLAB path.

root = fileparts(mfilename('fullpath'));
subdirs = { ...
    fullfile(root, 'core')};

for k = 1:numel(subdirs)
    if exist(subdirs{k}, 'dir') == 7
        addpath(subdirs{k});
    end
end

if nargout > 0
    paths = struct('root', root, 'core', subdirs{1});
else
    fprintf('LP path setup complete: %s\n', root);
end
