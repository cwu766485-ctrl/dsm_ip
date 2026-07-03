function [S, T] = alignment_error_profile(cap_bits_file, ref_bits_file, varargin)
% alignment_error_profile
% Banded alignment with traceback event profiling.

p = inputParser;
addParameter(p, 'CapRange', [], @(x) isempty(x) || (isnumeric(x) && numel(x) == 2));
addParameter(p, 'RefStart', 1, @(x) isnumeric(x) && isscalar(x));
addParameter(p, 'RefLength', [], @(x) isempty(x) || (isnumeric(x) && isscalar(x)));
addParameter(p, 'Band', 64, @(x) isnumeric(x) && isscalar(x) && x >= 1);
parse(p, varargin{:});
opt = p.Results;

cap = read_01_lines(cap_bits_file);
ref = read_01_lines(ref_bits_file);
cap0 = cap;
ref0 = ref;

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
pr = zeros(n + 1, W, 'int8');

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
            cand = dp(i, col) + int32(cap(i) ~= ref(j));
            if cand < best
                best = cand;
                best_pr = 1;
            end
        end

        if i > 0 && (d + 1) <= B
            cand = dp(i, col + 1) + 1;
            if cand < best
                best = cand;
                best_pr = 2;
            end
        end

        if j > 0 && (d - 1) >= -B
            cand = dp(i+1, col - 1) + 1;
            if cand < best
                best = cand;
                best_pr = 3;
            end
        end

        dp(i+1, col) = best;
        pr(i+1, col) = best_pr;
    end
end

end_d = m - n;
col = end_d + B + 1;

ops = repmat(' ', n + m, 1);
cap_idx = zeros(n + m, 1);
ref_idx = zeros(n + m, 1);
t = 0;
i = n;
j = m;
while i > 0 || j > 0
    d = j - i;
    col = d + B + 1;
    act = pr(i+1, col);
    t = t + 1;
    if act == 1
        if cap(i) == ref(j)
            ops(t) = 'M';
        else
            ops(t) = 'S';
        end
        cap_idx(t) = i;
        ref_idx(t) = j;
        i = i - 1;
        j = j - 1;
    elseif act == 2
        ops(t) = 'C';
        cap_idx(t) = i;
        ref_idx(t) = j;
        i = i - 1;
    elseif act == 3
        ops(t) = 'R';
        cap_idx(t) = i;
        ref_idx(t) = j;
        j = j - 1;
    else
        error('Traceback failed at i=%d j=%d', i, j);
    end
end

ops = flipud(ops(1:t));
cap_idx = flipud(cap_idx(1:t));
ref_idx = flipud(ref_idx(1:t));

evt_op = {};
evt_len = [];
evt_cap_start = [];
evt_cap_end = [];
evt_ref_start = [];
evt_ref_end = [];

k = 1;
while k <= t
    op = ops(k);
    s = k;
    while k <= t && ops(k) == op
        k = k + 1;
    end
    e = k - 1;
    evt_op{end+1, 1} = op; %#ok<AGROW>
    evt_len(end+1, 1) = e - s + 1; %#ok<AGROW>
    nz_cap = cap_idx(s:e);
    nz_cap = nz_cap(nz_cap > 0);
    nz_ref = ref_idx(s:e);
    nz_ref = nz_ref(nz_ref > 0);
    evt_cap_start(end+1, 1) = first_or_zero(nz_cap); %#ok<AGROW>
    evt_cap_end(end+1, 1) = last_or_zero(nz_cap); %#ok<AGROW>
    evt_ref_start(end+1, 1) = first_or_zero(nz_ref); %#ok<AGROW>
    evt_ref_end(end+1, 1) = last_or_zero(nz_ref); %#ok<AGROW>
end

T = table(evt_op, evt_len, evt_cap_start, evt_cap_end, evt_ref_start, evt_ref_end);

S = struct();
S.cap_bits_file = cap_bits_file;
S.ref_bits_file = ref_bits_file;
S.cap_range = opt.CapRange;
S.ref_start = opt.RefStart;
S.ref_length = ref_len;
S.band = B;
S.total_ops = t;
S.matches = sum(ops == 'M');
S.substitutions = sum(ops == 'S');
S.skip_capture = sum(ops == 'C');
S.skip_reference = sum(ops == 'R');
S.cost = S.substitutions + S.skip_capture + S.skip_reference;
S.identity = S.matches / max(1, S.matches + S.substitutions);
S.event_table = T;

writetable(T, 'alignment_error_profile_events.csv');
fprintf('%s\n', repmat('=', 1, 78));
fprintf('Alignment error profile\n');
fprintf('  matches           : %d\n', S.matches);
fprintf('  substitutions     : %d\n', S.substitutions);
fprintf('  skip capture      : %d\n', S.skip_capture);
fprintf('  skip reference    : %d\n', S.skip_reference);
fprintf('  event count       : %d\n', height(T));
fprintf('  mismatch events   : %d\n', sum(T.evt_op ~= "M"));
fprintf('  long gap events   : %d\n', sum((T.evt_op == "C" | T.evt_op == "R") & T.evt_len >= 2));

% Silence "unused" warnings for local raw vectors kept for later inspection.
if false
    disp(cap0); disp(ref0);
end
end

function x = first_or_zero(v)
if isempty(v)
    x = 0;
else
    x = v(1);
end
end

function x = last_or_zero(v)
if isempty(v)
    x = 0;
else
    x = v(end);
end
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
