% compareData1: [1, 2, 3, 4; 1, 2, 3, 4]
% compareData2: [1, 2, 3, 4; 1, 2, 3, 4; 1, 2, 3, 4]
% ==> bar plot with 4x2 bars

% 2022-10-01. Leonardo Molina.
% 2022-11-29. Last modified.
function barWithErrors(yLabel, variableLabels, compareLabels, varargin)
    compareData = varargin;
    nComparisons = numel(compareData);
    nVariables = size(compareData{1}, 2);
    av = zeros(nComparisons, nVariables);
    se = zeros(nComparisons, nVariables);
    for i = 1:nComparisons
        % Column mean and standard deviation for each comparison.
        data = compareData{i};
        av(i, :) = mean(data, 'omitnan');
        se(i, :) = std(data, 'omitnan') ./ sqrt(sum(~isnan(data)));
    end
    h = bar(av', 'EdgeColor', 'none');
    xticklabels(variableLabels);
    hold('all');
    for i = 1:nComparisons
        set(h(i), 'DisplayName', compareLabels{i});
        errorbar(h(i).XEndPoints, av(i, :), se(i, :), 'Color', 'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
    end
    ylabel(yLabel);
    xtickangle(45);
    legend('show');
    grid('on');
    grid('minor');
end