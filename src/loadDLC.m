% Read csv and format table.

% 2022-07-13. Leonardo Molina.
% 2022-11-03. Last modified.
function data = loadDLC(path, map, nColumns, nHeaderLines)
    if nargin < 4
        nHeaderLines = 3;
    end
    if nargin < 3
        nColumns = max([map{:, 1}]);
    end
    
    % Read csv and format table.
    f = fopen(path, 'rt');
    data = textscan(f, repmat('%f', 1, nColumns), 'Delimiter', ',', 'HeaderLines', nHeaderLines);
    fclose(f);
    data = [data{:}];
    data = array2table(data(:, [map{:, 1}]), 'VariableNames', map(:, 2));
end