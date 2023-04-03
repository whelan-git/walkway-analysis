% 2022-07-14. Leonardo Molina.
% 2022-07-14. Last modified.
function mask = epochsToMask(epochs, nSamples)
    mask = false(nSamples, 1);
    n = numel(epochs);
    for e = 1:2:n - 1
        a = epochs(e);
        b = epochs(e + 1);
        mask(a:b) = true;
    end
end