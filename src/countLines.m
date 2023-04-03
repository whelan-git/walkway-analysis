% counts = countLines(paths)
% Count lines in text files fast.
% 
% For a list of files, in Windows, defaults to using the command line, otherwise
% defaults to reading file contents.
% 
% It is much faster to pass a list of paths at once than to call the function
% for each path.
% 
%   Fast:
%     counts = countLines(paths)
%   Slow:
%     counts = zeros(size(paths));
%     for i = 1:numel(paths)
%         counts(i) = countLines(paths{i});
%     end

% 2022-11-04. Leonardo Molina.
% 2022-11-04. Last modified.
function counts = countLines(paths)
    if iscell(paths) && ispc
        % Create process builder.
        builder = java.lang.ProcessBuilder({''});
        builder.directory(java.io.File(pwd));
        builder.redirectErrorStream(true);
        % Avoid collisions with other environment variables.
        symbols = ['a':'z' 'A':'Z' '0':'9'];
        varName = ['paths' symbols(randi(numel(symbols), [1 10]))];
        % Prepare list of paths.
        listString = strjoin(paths, ',');
        % Long variables can only be passed as environment variable.
        environment = builder.environment();
        environment.put(varName, listString);
        % Define command.
        command = ['Foreach ($filename in ($env:' varName ' -split '','')) {$count = 0; switch -File $filename {default {++$count}}; echo $count}'];
        % Add command to builder.
        builder.command({'powershell.exe', command});
        % Run command.
        process = builder.start();
        % Retrieve output.
        inputStream = process.getInputStream();
        scanner = java.util.Scanner(inputStream).useDelimiter('\A');
        output = strtrim(char(scanner.next()));
        process.destroy()
        % Convert
        counts = str2double(strsplit(output));
    else
        if ~iscell(paths)
            paths = {paths};
        end
        counts = NaN(size(paths));
        for p = 1:numel(paths)
            f = fopen(paths{p}, 'rt');
            data = textscan(f, '%s', 'Delimiter', '\n');
            fclose(f);
            counts(p) = numel(data{1});
        end
    end
    counts = reshape(counts, size(paths));
end