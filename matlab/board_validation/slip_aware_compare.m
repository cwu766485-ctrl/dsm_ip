function S = slip_aware_compare(capture_bits_file, ref_bits_file, varargin)
% slip_aware_compare
% Greedy local re-synchronization compare allowing insert/delete slips.
%
% Optional name/value:
%   'CapRange'    : [start end] on capture bits
%   'RefStart'    : 1-based reference start index (cyclic)
%   'RefLength'   : number of reference bits to compare
%   'Lookahead'   : lookahead window, default 96

p = inputParser;
addParameter(p, 'CapRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'RefStart', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'RefLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Lookahead', 96, @(x) isnumeric(x) && isscalar(x) && x >= 8);
parse(p, varargin{:});
opt = p.Results;

cap = read_01_lines(capture_bits_file);
ref = read_01_lines(ref_bits_file);

if ~isempty(opt.CapRange)
    cap = cap(opt.CapRange(1):opt.CapRange(2));
end

if isempty(opt.RefLength)
    ref_len = numel(cap);
else
    ref_len = opt.RefLength;
end
ref = cyclic_take(ref, opt.RefStart, ref_len);

i = 1;
j = 1;
hits = 0;
subs = 0;
skip_cap = 0;
skip_ref = 0;
actions = zeros(0, 1);

while i <= numel(cap) && j <= numel(ref)
    if cap(i) == ref(j)
        hits = hits + 1;
        actions(end+1, 1) = 0; %#ok<AGROW>
        i = i + 1;
        j = j + 1;
        continue;
    end

    s_sub = lookahead_matches(cap, ref, i + 1, j + 1, opt.Lookahead);
    s_cap = lookahead_matches(cap, ref, i + 2, j + 1, opt.Lookahead);
    s_ref = lookahead_matches(cap, ref, i + 1, j + 2, opt.Lookahead);
    [~, act] = max([s_sub, s_cap, s_ref]);

    if act == 2
        skip_cap = skip_cap + 1;
        actions(end+1, 1) = 1; %#ok<AGROW>
        i = i + 1;
    elseif act == 3
        skip_ref = skip_ref + 1;
        actions(end+1, 1) = 2; %#ok<AGROW>
        j = j + 1;
    else
        subs = subs + 1;
        actions(end+1, 1) = 3; %#ok<AGROW>
        i = i + 1;
        j = j + 1;
    end
end

compared = hits + subs;
identity = hits / max(1, compared);

fprintf('%s\n', repmat('=', 1, 78));
fprintf('Slip-aware compare\n');
fprintf('  capture bits file : %s\n', capture_bits_file);
fprintf('  ref bits file     : %s\n', ref_bits_file);
fprintf('  compared          : %d\n', compared);
fprintf('  hits              : %d\n', hits);
fprintf('  substitutions     : %d\n', subs);
fprintf('  skip capture      : %d\n', skip_cap);
fprintf('  skip reference    : %d\n', skip_ref);
fprintf('  identity          : %.6f\n', identity);

S = struct();
S.compared = compared;
S.hits = hits;
S.substitutions = subs;
S.skip_capture = skip_cap;
S.skip_reference = skip_ref;
S.identity = identity;
S.actions = actions;
end

function s = lookahead_matches(a, b, ia, ib, W)
if ia > numel(a) || ib > numel(b)
    s = -1;
    return;
end
n = min([W, numel(a) - ia + 1, numel(b) - ib + 1]);
if n <= 0
    s = -1;
    return;
end
s = sum(a(ia:ia+n-1) == b(ib:ib+n-1));
end

function bits = cyclic_take(bits_ref, start_idx, len)
idx = mod(start_idx - 1 + (0:len-1), numel(bits_ref)) + 1;
bits = bits_ref(idx(:));
end

function bits = read_01_lines(file)
fid = fopen(file, 'r');
assert(fid >= 0, 'Cannot open %s', file);
c = onCleanup(@() fclose(fid));

bits = false(0, 1);
while true
    t = fgetl(fid);
    if ~ischar(t)
        break;
    end
    s = strtrim(t);
    if isempty(s)
        continue;
    end
    parts = split(s);
    x = str2double(parts{1});
    if ~isnan(x)
        bits(end+1, 1) = x ~= 0; %#ok<AGROW>
    end
end
end
