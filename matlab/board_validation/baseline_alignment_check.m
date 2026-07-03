function T = baseline_alignment_check()
% baseline_alignment_check
% Compare the DSM000 stable segment against the true RTL reference and
% several wrong/random references under the same banded alignment rules.

cap = 'data/board_validation/cartesian_dsm/DSM000_recovered_bits_01.txt';
true_ref = 'fpga/vivado/cartesian_dsm/cartesian_dsm.sim/sim_1/behav/xsim/sim_rf_bits_01.txt';
wrong_refs = {
    'fpga/vivado/cartesian_dsm/cartesian_dsm.sim/sim_1/behav/xsim/sim_bits_01.txt', ...
    'fpga/vivado/cartesian_dsm/cartesian_dsm.sim/sim_1/behav/xsim/sim_rf_bits_01_ef4.txt'
};

cap_range = [14721 39808];
ref_start = 55;
ref_len = 25088;
band = 64;

labels = {};
identity = [];
subs = [];
skip_cap = [];
skip_ref = [];
matches = [];
cost = [];
cost_rate = [];
coverage = [];
match_over_cap = [];

S = banded_bit_alignment(cap, true_ref, ...
    'CapRange', cap_range, 'RefStart', ref_start, ...
    'RefLength', ref_len, 'Band', band);
labels{end+1, 1} = 'true_ref'; %#ok<AGROW>
identity(end+1, 1) = S.identity; %#ok<AGROW>
subs(end+1, 1) = S.substitutions; %#ok<AGROW>
skip_cap(end+1, 1) = S.skip_capture; %#ok<AGROW>
skip_ref(end+1, 1) = S.skip_reference; %#ok<AGROW>
matches(end+1, 1) = S.matches; %#ok<AGROW>
cost(end+1, 1) = S.cost; %#ok<AGROW>
cost_rate(end+1, 1) = S.cost / ref_len; %#ok<AGROW>
coverage(end+1, 1) = (S.matches + S.substitutions) / ref_len; %#ok<AGROW>
match_over_cap(end+1, 1) = S.matches / ref_len; %#ok<AGROW>

for k = 1:numel(wrong_refs)
    S = banded_bit_alignment(cap, wrong_refs{k}, ...
        'CapRange', cap_range, 'RefStart', 1, ...
        'RefLength', ref_len, 'Band', band);
    [~, name, ext] = fileparts(wrong_refs{k});
    labels{end+1, 1} = [name ext]; %#ok<AGROW>
    identity(end+1, 1) = S.identity; %#ok<AGROW>
    subs(end+1, 1) = S.substitutions; %#ok<AGROW>
    skip_cap(end+1, 1) = S.skip_capture; %#ok<AGROW>
    skip_ref(end+1, 1) = S.skip_reference; %#ok<AGROW>
    matches(end+1, 1) = S.matches; %#ok<AGROW>
    cost(end+1, 1) = S.cost; %#ok<AGROW>
    cost_rate(end+1, 1) = S.cost / ref_len; %#ok<AGROW>
    coverage(end+1, 1) = (S.matches + S.substitutions) / ref_len; %#ok<AGROW>
    match_over_cap(end+1, 1) = S.matches / ref_len; %#ok<AGROW>
end

ref_bits = read_01_lines(true_ref);
rng(1);
perm_bits = ref_bits(randperm(numel(ref_bits)));
rand_bits = rand(numel(ref_bits), 1) > 0.5;
tmp_perm = 'tmp_perm_rf_bits_01.txt';
tmp_rand = 'tmp_rand_rf_bits_01.txt';
write_01_lines(tmp_perm, perm_bits);
write_01_lines(tmp_rand, rand_bits);

cleanup = onCleanup(@() cleanup_tmp({tmp_perm, tmp_rand}));

S = banded_bit_alignment(cap, tmp_perm, ...
    'CapRange', cap_range, 'RefStart', 1, ...
    'RefLength', ref_len, 'Band', band);
labels{end+1, 1} = 'perm_true_ref'; %#ok<AGROW>
identity(end+1, 1) = S.identity; %#ok<AGROW>
subs(end+1, 1) = S.substitutions; %#ok<AGROW>
skip_cap(end+1, 1) = S.skip_capture; %#ok<AGROW>
skip_ref(end+1, 1) = S.skip_reference; %#ok<AGROW>
matches(end+1, 1) = S.matches; %#ok<AGROW>
cost(end+1, 1) = S.cost; %#ok<AGROW>
cost_rate(end+1, 1) = S.cost / ref_len; %#ok<AGROW>
coverage(end+1, 1) = (S.matches + S.substitutions) / ref_len; %#ok<AGROW>
match_over_cap(end+1, 1) = S.matches / ref_len; %#ok<AGROW>

S = banded_bit_alignment(cap, tmp_rand, ...
    'CapRange', cap_range, 'RefStart', 1, ...
    'RefLength', ref_len, 'Band', band);
labels{end+1, 1} = 'rand_bernoulli'; %#ok<AGROW>
identity(end+1, 1) = S.identity; %#ok<AGROW>
subs(end+1, 1) = S.substitutions; %#ok<AGROW>
skip_cap(end+1, 1) = S.skip_capture; %#ok<AGROW>
skip_ref(end+1, 1) = S.skip_reference; %#ok<AGROW>
matches(end+1, 1) = S.matches; %#ok<AGROW>
cost(end+1, 1) = S.cost; %#ok<AGROW>
cost_rate(end+1, 1) = S.cost / ref_len; %#ok<AGROW>
coverage(end+1, 1) = (S.matches + S.substitutions) / ref_len; %#ok<AGROW>
match_over_cap(end+1, 1) = S.matches / ref_len; %#ok<AGROW>

T = table(labels, identity, matches, subs, skip_cap, skip_ref, ...
    cost, cost_rate, coverage, match_over_cap);
writetable(T, 'baseline_alignment_check.csv');
disp(T);
end

function cleanup_tmp(files)
for k = 1:numel(files)
    if exist(files{k}, 'file')
        delete(files{k});
    end
end
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

function write_01_lines(file, bits)
fid = fopen(file, 'w');
assert(fid >= 0, 'Cannot open %s for write', file);
c = onCleanup(@() fclose(fid));
fprintf(fid, '%d\n', bits);
end
