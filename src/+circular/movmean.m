% 2022-07-08. Leonardo Molina.
% 2022-07-14. Last modified.
function r = movmean(window, angles, weights)
    % Define moving window.
    even = @(k) round(k) + (mod(round(k), 2) ~= 0);
    body = even(window) / 2;
    template = -body:body;
    n = numel(angles);
    % Circular median filter.
    total = sum(weights);
    if total > 0
        weights = weights / total;
    end
    % Apply moving filter; edges use as many neighbors as available.
    r = NaN(size(angles));
    for i = 1:n
        k = i + template;
        k = k(k > 0 & k <= n);
        r(i) = circular.mean(angles(k), 1, weights(k));
    end
    r = mod(r + 2 * pi, 2 * pi);
end