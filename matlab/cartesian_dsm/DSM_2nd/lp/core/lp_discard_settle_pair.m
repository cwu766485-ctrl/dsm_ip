function [y2, x2] = lp_discard_settle_pair(y, x, Nsettle)
% lp_discard_settle_pair Drop initial transient while keeping equal length
y = y(:);
x = x(:);
L = min(numel(y), numel(x));
y = y(1:L);
x = x(1:L);
if nargin < 3 || isempty(Nsettle)
    Nsettle = 0;
end
Nsettle = max(0, floor(double(Nsettle)));
if L <= 1
    y2 = y;
    x2 = x;
    return;
end
Nsettle = min(Nsettle, L-1);
y2 = y(1+Nsettle:end);
x2 = x(1+Nsettle:end);
end
