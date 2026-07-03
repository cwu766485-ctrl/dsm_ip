function repo = lp_find_repo_root(start_dir)
% lp_find_repo_root
% Robustly locate repository root after folder reshuffles.

if nargin < 1 || isempty(start_dir)
    start_dir = fileparts(mfilename('fullpath'));
end

repo = start_dir;
while true
    if exist(fullfile(repo, '.git'), 'dir') == 7 || ...
       (exist(fullfile(repo, 'matlab'), 'dir') == 7 && exist(fullfile(repo, 'fpga'), 'dir') == 7)
        return;
    end

    parent = fileparts(repo);
    if strcmp(parent, repo)
        error('lp_find_repo_root:NotFound', 'Could not locate repository root from %s.', start_dir);
    end
    repo = parent;
end
