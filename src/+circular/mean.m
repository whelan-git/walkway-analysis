% 2022-07-08. Leonardo Molina.
% 2022-07-11. Last modified.
function r = mean(angles, dim, weights)
    if nargin < 2
        dim = find(size(angles) ~=1, 1);
    end
    if nargin < 3
        weights = ones(size(angles));
    end
    r = atan2(sum(sin(angles) .* weights, dim), sum(cos(angles) .* weights, dim));
end