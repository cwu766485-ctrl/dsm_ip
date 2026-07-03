function S = banded_bit_alignment(cap_bits_file, ref_bits_file, varargin)
% banded_bit_alignment
% Banded global alignment between a captured 0/1 stream and a reference
% 0/1 stream. Supports substitutions and insert/delete slips.
%
% Name/value options:
%   'CapRange'    : [start end] capture slice
%   'RefStart'    : 1-based cyclic start in reference
%   'RefLength'   : number of reference bits to compare
%   'Band'        : max |j-i| offset, default 64

p = inputParser;
addParameter(p, 'CapRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'RefStart', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'RefLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Band', 64, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});
opt = p.Results;

cap = read_01_lines(cap_bits_file);
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

n = numel(cap);
m = numel(ref);
B = opt.Band;
W = 2 * B + 1;
INF = int32(1e9);

dp = repmat(INF, n + 1, W);
pr = zeros(n + 1, W, 'int8');  % 1=diag, 2=up(skip cap), 3=left(skip ref)

for i = 0:n
    dmin = max(-B, -i);
    dmax = min(B, m - i);
    for d = dmin:dmax
        j = i + d;
        col = d + B + 1;
        if i == 0 && j == 0
            dp(i+1, col) = 0;
            continue;
        end

        best = INF;
        best_pr = int8(0);

        if i > 0 && j > 0
            col_prev = col;
            cand = dp(i, col_prev) + int32(cap(i) ~= ref(j));
            if cand < best
                best = cand;
                best_pr = 1;
            end
        end

        if i > 0 && (d + 1) <= B
            col_prev = col + 1;
            if col_prev <= W
                cand = dp(i, col_prev) + 1;
                if cand < best
                    best = cand;
                    best_pr = 2;
                end
            end
        end

        if j > 0 && (d - 1) >= -B
            col_prev = col - 1;
            if col_prev >= 1
                cand = dp(i+1, col_prev) + 1;
                if cand < best
                    best = cand;
                    best_pr = 3;
                end
            end
        end

        dp(i+1, col) = best;
        pr(i+1, col) = best_pr;
    end
end

end_d = m - n;
assert(abs(end_d) <= B, 'End offset %d exceeds band %d', end_d, B);
col = end_d + B + 1;
cost = double(dp(n+1, col));

i = n;
j = m;
matches = 0;
subs = 0;
skip_cap = 0;
skip_ref = 0;
while i > 0 || j > 0
    d = j - i;
    col = d + B + 1;
    act = pr(i+1, col);
    if act == 1
        if cap(i) == ref(j)
            matches = matches + 1;
        else
            subs = subs + 1;
        end
        i = i - 1;
        j = j - 1;
    elseif act == 2
        skip_cap = skip_cap + 1;
        i = i - 1;
    elseif act == 3
        skip_ref = skip_ref + 1;
        j = j - 1;
    else
        error('Traceback failed at i=%d j=%d', i, j);
    end
end

identity = matches / max(1, matches + subs);

fprintf('%s\n', repmat('=', 1, 78));
fprintf('Banded bit alignment\n');
fprintf('  capture bits file : %s\n', cap_bits_file);
fprintf('  ref bits file     : %s\n', ref_bits_file);
fprintf('  band              : %d\n', B);
fprintf('  cost              : %d\n', cost);
fprintf('  matches           : %d\n', matches);
fprintf('  substitutions     : %d\n', subs);
fprintf('  skip capture      : %d\n', skip_cap);
fprintf('  skip reference    : %d\n', skip_ref);
fprintf('  identity          : %.6f\n', identity);

S = struct();
S.band = B;
S.cost = cost;
S.matches = matches;
S.substitutions = subs;
S.skip_capture = skip_cap;
S.skip_reference = skip_ref;
S.identity = identity;
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
