% [epochs2, ids] = blendEpochs(epochs1)
% Blend overlapping epochs and return a map from epochs1 to epochs2.
% 
% Example:
%   epochs1 = [0 10; 20 30; 25 40; 30 40; 50 60]';
%   [epochs2, ids] = blendEpochs(epochs1)

% 2022-09-23. Leonardo Molina.
% 2022-09-23. Last modified.
function [epochs, ids] = blendEpochs(epochs)
    % Sort epochs by time.
    [~, k] = sort(epochs(1:2:end));
    starts = epochs(2 * k - 1);
    ends = epochs(2 * k + 0);
    n = numel(starts);
    
    keep = false(n, 1);
    i = 1;
    while i <= n
        k = i;
        for j = i + 1:n
            if ends(i) >= starts(j)
                k = j;
            else
                break;
            end
        end
        keep(i) = true;
        epochs(:, i) = [starts(i); max(ends(i), ends(k))];
        i = k + 1;
    end
    epochs = epochs(:, keep);
    ids = cumsum(keep);
end