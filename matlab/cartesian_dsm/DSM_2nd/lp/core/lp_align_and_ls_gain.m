function al = lp_align_and_ls_gain(y, x)
% lp_align_and_ls_gain Align by cross-correlation and solve LS gain
y = y(:);
x = x(:);
L = min(numel(x), numel(y));
x = x(1:L);
y = y(1:L);
maxLag = min(2000, floor(L/4));
[c,lags] = xcorr(y, x, maxLag, 'coeff');
[~,im] = max(abs(c));
lag = lags(im);
if lag > 0
    y2 = y(1+lag:end);
    x2 = x(1:end-lag);
elseif lag < 0
    y2 = y(1:end+lag);
    x2 = x(1-lag:end);
else
    y2 = y;
    x2 = x;
end
L2 = min(numel(x2), numel(y2));
x2 = x2(1:L2);
y2 = y2(1:L2);
g = (y2' * x2) / (y2' * y2 + eps);
al = struct();
al.x_aligned = x2;
al.y_aligned = g * y2;
end
