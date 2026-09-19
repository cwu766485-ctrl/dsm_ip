function result = run_tid_pipelined_scalar_contract(varargin)
%RUN_TID_PIPELINED_SCALAR_CONTRACT Compare L-channel TIDSM against scalar EFM.
%
% The contract permits fixed pipeline latency but requires all non-transient
% one-bit outputs to equal the scalar first-order EFM after one constant lag.

cfg.channels = 32;
cfg.words = 256;
cfg.w = 16;
cfg.seed = 20260915;
cfg.max_lag = 4096;
for k = 1:2:numel(varargin)
    cfg.(varargin{k}) = varargin{k+1};
end

rng(cfg.seed);
n = cfg.channels * cfg.words;
x = int64(randi([-12000,12000], n, 1));
state = [];
y_tid = false(n,1);
for first = 1:cfg.channels:n
    [raw, state] = tid_pipelined_first_order_step(x(first:first+cfg.channels-1), ...
        zeros(cfg.channels,1,'int64'), state, cfg.w);
    for lane = 1:cfg.channels
        y_tid(first+lane-1) = raw(2*lane-1);
        if mod(lane-1,2) ~= 0
            y_tid(first+lane-1) = ~y_tid(first+lane-1);
        end
    end
end

y_scalar = false(n,1);
v = int64(0);
mod_w = int64(2)^cfg.w;
mod_v = int64(2)^(cfg.w+1);
for k = 1:n
    u = mod(x(k) + int64(2)^(cfg.w-1), mod_w);
    v = mod(u + mod(v, mod_w), mod_v);
    y_scalar(k) = v >= mod_w;
end

best_mismatch = inf;
best_lag = NaN;
for lag = -cfg.max_lag:cfg.max_lag
    if lag >= 0
        a = y_tid(1+lag:end);
        b = y_scalar(1:numel(a));
    else
        b = y_scalar(1-lag:end);
        a = y_tid(1:numel(b));
    end
    mismatch = nnz(a ~= b);
    if mismatch < best_mismatch
        best_mismatch = mismatch;
        best_lag = lag;
    end
end
result = table(n, best_lag, best_mismatch, ...
    'VariableNames', {'Samples','BestLag_samples','Mismatches'});
disp(result);
end
