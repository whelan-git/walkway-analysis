% [epochs3, k] = intersectEpochs(epochs1, epochs2)
% Intersect epochs1 and epochs2 and return a map from epochs3 to epochs1.
% 
% Example:
%   epochs1 = [0 10; 50 70; 80 95]';
%   epochs2 = [1 2; 8 52; 71 79; 95 100]';
%   [epochs3, k] = intersectEpochs(epochs1, epochs2)

% 2022-08-25. Leonardo Molina.
% 2022-09-23. Last modified.
function [epochs, ids] = intersectEpochs(epochs1, epochs2)
    % Sort epochs by time.
    [~, k] = sort(epochs1(1:2:end));
    starts1 = epochs1(2 * k - 1);
    ends1 = epochs1(2 * k + 0);
    [~, k] = sort(epochs2(1:2:end));
    starts2 = epochs2(2 * k - 1);
    ends2 = epochs2(2 * k + 0);
    
    epochs = zeros(2, 0);
    ids = zeros(1, 0);
    for i = 1:numel(starts1)
        for j = 1:numel(ends2)
            mx = max(starts1(i), starts2(j));
            mn = min(ends1(i), ends2(j));
            if mx <= mn
                epochs = cat(2, epochs, [mx; mn]);
                ids = cat(2, ids, i);
            end
        end
    end
end