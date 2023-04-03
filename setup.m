% User/Lab specific configuration file.
% Notation:
%   <body part><body position><metric>
%   Append 'p' to the body part for projected metrics.
%   
%   Body parts: nose | butt | heel | toes | center
%   Position in body:
%     F: front
%     B: back
%   Metric:
%     X: x-coord
%     Y: y-coord
%     K: confidence
%     A: angle
%     V: speed
%     P: phase
%     E: epoch
%     M: magnitude / distance
%   
%   Example:
%     "x-coordinate of the front-right heel" ==> heelFRX

% 2022-07-11. Leonardo Molina.
% 2023-04-03. Last modified.
function [configuration, paths] = setup()
    % Add function dependencies.
    root = fileparts(mfilename('fullpath'));
    addpath(root);
    addpath(fullfile(root, 'src'));
    
    % Initialize configuration structure.
    configuration = struct();

    % Folder containing DLC and annotation files.
    configuration.dataFolder = 'data/HALO/Walkway/dlc';
    configuration.annotationsFile = 'data/HALO/Walkway/annotations.csv';
    
    % Acquisition and playback rate.
    configuration.acquisitionRate = 170;
    
    % Centimeters per pixel conversion.
    configuration.resolution = 40 / 1440;
    
    % Moving window to calculate mouse heading direction.
    configuration.angleMovingWindow = 1.0;
    
    % Peak detection parameters.
    configuration.minStrideDuration = 0.10;
    configuration.maxStrideDuration = 0.75;
    configuration.minPhaseProminenceSD = 0.25;
    
    % Preprocess parameters.
    configuration.minSpeed = 10.0;
    configuration.maxSpeed = 100.0;
    configuration.durationSD = 1.5;
    configuration.minBoutDuration = 0.25;
    configuration.correlationThreshold = 0.95;
    configuration.speedWindowDuration = 0.25;
    
    % Sort files by date.
    first = @(x) x{1};
    regex = @(varargin) first(regexp(varargin{:}, 'tokens', 'once'));
    files = dir(fullfile(configuration.dataFolder, '**', '*.csv'));
    fileTime = cellfun(@(filename) regex(filename, '-[TC](\d{20})'), {files.name}', 'UniformOutput', false);
    [fileTime, k] = sort(fileTime);
    files = files(k);
    paths = fullfile({files.folder}, {files.name});
    nPaths = numel(paths);

    % Number of header lines in DLC file.
    configuration.nHeaderLines = 3;
    % Function returning tracking data ([CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY]) given a DLC filename.
    configuration.getter = @(path) loadData(path, configuration.nHeaderLines, configuration.resolution, configuration.angleMovingWindow, configuration.acquisitionRate);
    
    % Get annotations within videos with the identity of each mouse for epoch ranges.
    cuts = cell(nPaths, 1);
    ids = cell(nPaths, 1);
    labels = cell(nPaths, 1);
    if ~isempty(configuration.annotationsFile)
        fid = fopen(configuration.annotationsFile, 'r');
        data = textscan(fid, '%s%s%s%s', 'Delimiter', ',');
        fclose(fid);
        annotationTime = cellfun(@(filename) regex(filename, '-[TC](\d{20})'), data{1}, 'UniformOutput', false);
        [~, k2] = ismember(fileTime, annotationTime);
        k1 = k2 > 0;
        k3 = k2(k1);
        cuts(k1) = cellfun(@str2array, data{2}(k3), 'UniformOutput', false);
        ids(k1) = cellfun(@str2array, data{3}(k3), 'UniformOutput', false);
        labels(k1) = cellfun(@strsplit, data{4}(k3), 'UniformOutput', false);
    end
    
    configuration.annotations = struct('cuts', cuts, 'ids', ids, 'labels', labels);
end

% Turn an text array into a numeric array.
function array = str2array(text)
    value = strip(text);
    if isempty(value)
        array = [];
    else
        array = str2double(strsplit(value, ' '));
    end
end

% Load body and paw midpoints, and full body orientation.
function [CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = loadData(path, nHeaderLines, scale, angleMovingWindow, acquisitionRate)
    % Total number of columns in DLC file.
    nColumns = 37;

    columnMap = {
        02, 'noseX'
        03, 'noseY'
        04, 'noseK'
        05, 'buttX'
        06, 'buttY'
        07, 'buttK'
        08, 'heelFRX'
        09, 'heelFRY'
        10, 'heelFRK'
        11, 'toesFRX'
        12, 'toesFRY'
        13, 'toesFRK'
        14, 'heelFLX'
        15, 'heelFLY'
        16, 'heelFLK'
        17, 'toesFLX'
        18, 'toesFLY'
        19, 'toesFLK'
        20, 'heelBRX'
        21, 'heelBRY'
        22, 'heelBRK'
        23, 'toesBRX'
        24, 'toesBRY'
        25, 'toesBRK'
        26, 'heelBLX'
        27, 'heelBLY'
        28, 'heelBLK'
        29, 'toesBLX'
        30, 'toesBLY'
        31, 'toesBLK'
        32, 'centerLX'
        33, 'centerLY'
        34, 'centerLK'
        35, 'centerRX'
        36, 'centerRY'
        37, 'centerRK'
    };
    
    data = loadDLC(path, columnMap, nColumns, nHeaderLines);
    data(:, :) = num2cell(table2array(data) * scale);

    % Body midpoints.
    CX = (data.centerLX + data.centerRX) / 2;
    CY = (data.centerLY + data.centerRY) / 2;

    % For a freely moving animal, angle of motion is given by its center of mass.
    if numel(CY) >= 2
        angles = atan2(diff(CY), diff(CX));
        confidence = min(data.centerLK, data.centerRK);
        movingWindow = round(angleMovingWindow * acquisitionRate);
        CA = circular.movmean(movingWindow, angles, confidence);
        CA = [CA; CA(end)];
    else
        CA = 0;
    end

    FLX = (data.heelFLX + data.toesFLX) / 2;
    FLY = (data.heelFLY + data.toesFLY) / 2;
    FRX = (data.heelFRX + data.toesFRX) / 2;
    FRY = (data.heelFRY + data.toesFRY) / 2;
    BLX = (data.heelBLX + data.toesBLX) / 2;
    BLY = (data.heelBLY + data.toesBLY) / 2;
    BRX = (data.heelBRX + data.toesBRX) / 2;
    BRY = (data.heelBRY + data.toesBRY) / 2;
end