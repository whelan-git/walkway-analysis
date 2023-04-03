% 2022-07-12. Leonardo Molina.
% 2022-07-12. Last modified.
function [swingEpochs, stanceEpochs] = splitEpochs(swingStarts, epochs)
    n = numel(epochs);
    isOdd = mod(n, 2);
    range1 = 1:n -  isOdd;
    range2 = 2:n - ~isOdd;
    if swingStarts
        swingEpochs = epochs(range1);
        stanceEpochs = epochs(range2);
    else
        swingEpochs = epochs(range2);
        stanceEpochs = epochs(range1);
    end
end