% *Demo* analysis script for the Walkway paper.
% "High-throughput gait acquisition system for freely moving mice"

% 2021-11-15. Leonardo Molina.
% 2023-04-03. Last modified.

%% Option 1a: Preprocess part 1.
[config, paths] = setup();
[bouts, files, sessions] = preprocess(config, paths);

%% Option 1b: Preprocess part 2.
% Prepare structures for new data.
append = {'regularityIndex', 'swingCount', 'stanceCount', 'strideCount', 'swingDuration', 'stanceDuration', 'distance', 'speed', 'snr'};
for name = append
    [bouts.(name{1})] = deal([]);
    [files.(name{1})] = deal([]);
end

% Append data to each file.
nFiles = numel(files);
for fid = 1:nFiles
    file = files(fid);
    fprintf('[%04d:%04d] "%s"\n', fid, nFiles, file.uid);
    getter = @() config.getter(file.path);
    files(fid) = appendData(file, config, getter);
end

% Append data to each bout.
nBouts = numel(bouts);
for bid = 1:nBouts
    bout = bouts(bid);
    fprintf('[%04d:%04d] "%s"\n', bid, nBouts, bout.uid);
    file = files(bout.fid);
    getter = @() getBout(@() config.getter(file.path), bout);
    bouts(bid) = appendData(bouts(bid), config, getter);
end

% Save.
save('preprocess-backup-20221122.mat', 'bouts', 'files', 'sessions', 'config');

%% Option 2: Load preprocessed data.
[~, paths] = setup();
d = load('preprocess-backup-20221122.mat');
bouts = d.bouts;
files = d.files;
config = d.config;
sessions = d.sessions;
nSessions = numel(sessions);

%% Setup.
config.minSNR = 5;
% Setup masks.
freeMask = [bouts.free]';
singleMask = [bouts.single]';
swingCount = cat(1, bouts.swingCount);
stanceCount = cat(1, bouts.stanceCount);
strideCount = cat(1, bouts.strideCount);
% Criteria for stats: A bout consisting of 2 full strides; mouse was not chased or chasing.
aloneMask = ismember([bouts.label], 'a')';
distanceMask = [bouts.distance]' >= 15;
analysisMask = strideCount >= 2 & aloneMask & distanceMask;

% Criteria for calculating regularity index.
interlimbCriteria = all(stanceCount >= 2, 2) & distanceMask;
% Calculate trigger intervals.
boutTime = [files([bouts.fid]).recordingDate]';
boutInterval = seconds(diff(boutTime));
boutInterval(end + 1) = boutInterval(end);
groups = 1:3;
comparisons = 1:3;
nGroups = numel(groups);
ids = 1:3;
nIds = numel(ids);
extract = @(structure, fieldname) cat(2, structure.(fieldname));

%% Additional mask applicable to sources.
sourceFreeMask = [files.free]';
sourceLengthMask = [files.frameCount]' >= config.minBoutDuration * config.acquisitionRate;

%% Print some usability counts.
disp(strjoin([
    "Video files:"
    sprintf("  Total: %i", numel(files))
    sprintf("  Valid: %i", sum(sourceLengthMask))
    sprintf("  Free: %i", sum(sourceFreeMask))
    sprintf("  Free & long: %i", sum(sourceFreeMask & sourceLengthMask))
    sprintf("  Forced: %i", sum(~sourceFreeMask))
    sprintf("  Forced & long: %i", sum(~sourceFreeMask & sourceLengthMask))
    ], '\n'));
disp(strjoin([
    "Bouts:"
    sprintf("  Total: %i", numel(bouts))
    sprintf("  Free: %i", sum(freeMask))
    sprintf("    single: %i", sum(freeMask & singleMask))
    sprintf("    single & criteria: %i", sum(freeMask & singleMask & analysisMask))
    sprintf("    group: %i", sum(freeMask & ~singleMask))
    sprintf("    group & criteria: %i", sum(freeMask & ~singleMask & analysisMask))
    sprintf("  Forced: %i", sum(~freeMask))
    sprintf("    single: %i", sum(~freeMask & singleMask))
    sprintf("    single & criteria: %i", sum(~freeMask & singleMask & analysisMask))
    sprintf("    group: %i", sum(~freeMask & ~singleMask))
    sprintf("    group & criteria: %i", sum(~freeMask & ~singleMask & analysisMask))
    ], '\n'));

freeFid = unique([bouts(freeMask).fid]);
fprintf("FreeMask:\n");
fprintf("  Number of files: %i\n", numel(freeFid));
fprintf("  Bout duration: %.2fmin\n", sum(diff([bouts(freeMask).epoch])) / config.acquisitionRate / 60);
fprintf("  File duration: %.2fmin\n", sum([files(freeFid).frameCount]) / config.acquisitionRate / 60);
fprintf("  Disk usage (see batch-filesize.py):\n");

fid = fopen("W:\Walkway\Walkway paper\output\log-size-avi.csv", 'r');
data = textscan(fid, '%s%d', 'Delimiter', ',', 'HeaderLines', 1);
fclose(fid);
[~, k1] = intersect(data{1}, {files(freeFid).uid});
nBytes1 = data{2}(k1);

fid = fopen("W:\Walkway\Walkway paper\output\log-size-mp4.csv", 'r');
data = textscan(fid, '%s%d', 'Delimiter', ',', 'HeaderLines', 1);
fclose(fid);
[~, k1] = intersect(data{1}, {files(freeFid).uid});
nBytes2 = data{2}(k1);
fprintf("    avi:%.2fGB\n", sum(nBytes1) / 1e9);
fprintf("    mp4:%.2fGB\n", sum(nBytes2) / 1e9);

%% Average count of usable bouts of locomotion per animal for each type.
% single vs mixed / free vs forced / sex:male vs female
boutMask = analysisMask;
fileMask = sourceLengthMask;

boutMales = [
    extractData(sessions, groups, ids, bouts, boutMask, 'M', 'forced', 'single', true), ...
    extractData(sessions, groups, ids, bouts, boutMask, 'M', 'free', 'single', true), ...
    extractData(sessions, groups, ids, bouts, boutMask, 'M', 'free', 'group', true)
    ];

boutFemales = [
    extractData(sessions, groups, ids, bouts, boutMask, 'F', 'forced', 'single', true), ...
    extractData(sessions, groups, ids, bouts, boutMask, 'F', 'free', 'single', true), ...
    extractData(sessions, groups, ids, bouts, boutMask, 'F', 'free', 'group', true)
    ];

fileMales = [
    extractData(sessions, groups, ids, files, sourceLengthMask, 'M', 'forced', 'single', false), ...
    extractData(sessions, groups, ids, files, sourceLengthMask, 'M', 'free', 'single', false), ...
    extractData(sessions, groups, ids, files, sourceLengthMask, 'M', 'free', 'group', false)
    ];

fileFemales = [
    extractData(sessions, groups, ids, files, sourceLengthMask, 'F', 'forced', 'single', false), ...
    extractData(sessions, groups, ids, files, sourceLengthMask, 'F', 'free', 'single', false), ...
    extractData(sessions, groups, ids, files, sourceLengthMask, 'F', 'free', 'group', false)
    ];

variableLabels = {'forced&single', 'free&single', 'free&group'};
compareLabels = {'Males', 'Females'};

%% Average per mouse per hour.
sem = @(x) std(x, 'omitnan') / sqrt(sum(~isnan(x)));
average = @(x) mean(x, 'omitnan');
pattern = @(text, x) fprintf('  %s: %g (SEM=%g)\n', text, average(x), sem(x));

fprintf('File counts:\n');
pattern('  Forced single male', fileMales(1).count);
pattern('  Forced single female', fileFemales(1).count);
pattern('  Free single male', fileMales(2).count);
pattern('  Free single female', fileFemales(2).count);
pattern('  Free group male', fileMales(3).count);
pattern('  Free group female', fileFemales(3).count);

fprintf('Bout counts:\n');
pattern('  Forced single male', boutMales(1).count);
pattern('  Forced single female', boutFemales(1).count);
pattern('  Free single male', boutMales(2).count);
pattern('  Free single female', boutFemales(2).count);
pattern('  Free group male', boutMales(3).count);
pattern('  Free group female', boutFemales(3).count);

figure('name', 'files');
barWithErrors('count', variableLabels(1:3), compareLabels, extract(fileMales(1:3), 'count'), extract(fileFemales(1:3), 'count'));

figure('name', 'bouts');
barWithErrors('count', variableLabels(1:3), compareLabels, extract(boutMales(1:3), 'count'), extract(boutFemales(1:3), 'count'));

%% Save data for stats.
r = @(varargin) repelem(varargin, nIds * nGroups, 1);
f = [r('Forced', 'Single', 'Male'); r('Free', 'Single', 'Male'); r('Free', 'Group', 'Male'); r('Forced', 'Single', 'Female'); r('Free', 'Single', 'Female'); r('Free', 'Group', 'Female')];
metrics = {'count', 'regularityIndex', 'speed', 'swingDuration', 'stanceDuration'};
data = cell(size(f, 1), numel(metrics));
for i = 1:numel(metrics)
    metric = metrics{i};
    data(:, i) = num2cell([boutMales(1).(metric); boutMales(2).(metric); boutMales(3).(metric); boutFemales(1).(metric); boutFemales(2).(metric); boutFemales(3).(metric)]);
end
filename = 'output.csv';
fid = fopen(filename, 'w');
data = [f, data]';
fprintf(fid, ['HandlingType,GroupType,Sex,', strjoin(metrics, ','), '\n']);
fprintf(fid, '%s,%s,%s,%g,%g,%g,%g,%g\n', data{:});
fclose(fid);

%% Regularity index.
figure();
x1 = extract(boutMales(comparisons), 'regularityIndex');
x2 = extract(boutFemales(comparisons), 'regularityIndex');
barWithErrors('index', variableLabels(comparisons), compareLabels, x1, x2);
title('Regularity index (bouts)');

figure();
x1 = extract(fileMales(comparisons), 'regularityIndex'); 
x2 = extract(fileFemales(comparisons), 'regularityIndex');
barWithErrors('index', variableLabels(comparisons), compareLabels, x1, x2);
title('Regularity index (files)');

%% Swing and stance.
figure();
subplot(1, 2, 1);
barWithErrors('duration (s)', variableLabels(comparisons), compareLabels, extract(boutMales(comparisons), 'swingDuration'), extract(boutFemales(comparisons), 'swingDuration'));
title('Swing duration (bouts)');
subplot(1, 2, 2);
barWithErrors('duration (s)', variableLabels(comparisons), compareLabels, extract(boutMales(comparisons), 'stanceDuration'), extract(boutFemales(comparisons), 'stanceDuration'));
title('Stance duration (bouts)');

figure();
subplot(1, 2, 1);
barWithErrors('duration (s)', variableLabels(comparisons), compareLabels, extract(fileMales(comparisons), 'swingDuration'), extract(fileFemales(comparisons), 'swingDuration'));
title('Swing duration (files)');
subplot(1, 2, 2);
barWithErrors('duration (s)', variableLabels(comparisons), compareLabels, extract(fileMales(comparisons), 'stanceDuration'), extract(fileFemales(comparisons), 'stanceDuration'));
title('Stance duration (files)');

%% Speed.
figure();
barWithErrors('speed (cm/s)', variableLabels(comparisons), compareLabels, extract(boutMales(comparisons), 'speed'), extract(boutFemales(comparisons), 'speed'));
title('Speed (bouts)');

figure();
barWithErrors('speed (cm/s)', variableLabels(comparisons), compareLabels, extract(fileMales(comparisons), 'speed'), extract(fileFemales(comparisons), 'speed'));
title('Speed (files)');

%% Compare bouts vs full videos (included forced).
figure();
subplot(1, 3, 1);
barWithErrors('count/hour', variableLabels, compareLabels, extract(boutMales, 'count'), extract(boutFemales, 'count'));
title('Bout counts');
subplot(1, 3, 2);
barWithErrors('duration (s)', variableLabels, compareLabels, extract(boutMales, 'duration') / config.acquisitionRate, extract(boutFemales, 'duration') / config.acquisitionRate);
title('Bout duration');
subplot(1, 3, 3);
barWithErrors('count', variableLabels, compareLabels, extract(boutMales, 'strideCount'), extract(boutFemales, 'strideCount'));
title('Stride count');

figure();
subplot(1, 3, 1);
barWithErrors('count/hour', variableLabels, compareLabels, extract(fileMales, 'count'), extract(fileFemales, 'count'));
title('Video counts');
subplot(1, 3, 2);
barWithErrors('duration (s)', variableLabels, compareLabels, extract(fileMales, 'duration') / config.acquisitionRate, extract(fileFemales, 'duration') / config.acquisitionRate);
title('Video duration');
subplot(1, 3, 3);
barWithErrors('count', variableLabels, compareLabels, extract(fileMales, 'strideCount'), extract(fileFemales, 'strideCount'));
title('Stride count');

%% Crossings over time (singly tested mice).
periods = 0:5:30;
nPeriods = numel(periods) - 1;
habituation = zeros(nIds * nGroups, nPeriods, 2);
onlyFirstDay = true;
recordingDates = [files([bouts.fid]).recordingDate]';
for sex = {'M', 'F'}
    for group = groups
        for id = ids
            k = [bouts.id]' == id & [bouts.group]' == group & ismember({bouts.sex}, sex)' & analysisMask & freeMask & singleMask;
            d = recordingDates(k);
            fprintf('%s%02i%02i nDays:%i\n', sex{:}, group, id, size(unique([d.Year d.Month d.Day], 'rows'), 1));
            if onlyFirstDay
                k(k) = d.Year == d(1).Year & d.Month == d(1).Month & d.Day == d(1).Day;
            end
            j = (group - 1) * nIds + id;
            habituation(j, :, ismember({'M', 'F'}, sex)) = histcounts([bouts(k).offset] / config.acquisitionRate / 60, periods);
        end
    end
end

figure()
av1 = mean(habituation(:, :, 1));
se1 = std(habituation(:, :, 1)) / sqrt(nGroups * nIds);
av2 = mean(habituation(:, :, 2));
se2 = std(habituation(:, :, 2)) / sqrt(nGroups * nIds);
h = bar([av1; av2]');
xticklabels(arrayfun(@(i, j) sprintf('%02i-%02i', i, j), periods(1:end - 1), periods(2:end), 'UniformOutput', false));
hold('all');
errorbar([h.XEndPoints], [av1, av2], [se1, se2], 'Color', 'k', 'LineStyle', 'none', 'HandleVisibility', 'off');
set(h(1), 'DisplayName', 'Males');
set(h(2), 'DisplayName', 'Females');
legend('show');
title('Habituation');
ylabel('count');
xlabel('Time range (min)');
xtickangle(45);
grid('on');
grid('minor');

%% Lenght of time required to collect 50% of data in a 30min session (singly tested mice).
target = 70;
time = zeros(nIds, nGroups, 2);
recordingDates = [files([bouts.fid]).recordingDate]';
boutDurations = diff([bouts.epoch])' / config.acquisitionRate;
for sex = {'M', 'F'}
    for group = groups
        for id = ids
            k = [bouts.id]' == id & [bouts.group]' == group & ismember({bouts.sex}, sex)' & analysisMask & freeMask & singleMask;
            dates = recordingDates(k);
            durations = seconds(boutDurations(k));
            [~, p] = unique([dates.Year, dates.Month, dates.Day], 'rows');
            p = cat(1, p, numel(dates) + 1);
            nDays = numel(p) - 1;
            % Duration on a day.
            acrossDays = 0;
            for d = 1:nDays
                a = p(d);
                b = p(d + 1) - 1;
                delta = seconds(dates(a:b) - dates(a) + durations(a:b));
                acrossDays = acrossDays + prctile(delta, target);
            end
            j = (group - 1) * nIds + id;
            time(j, :, ismember({'M', 'F'}, sex)) = acrossDays / nDays;
        end
    end
end

m = pad(sprintf('%.2f', mean(time(:, :, 1) / 60, 'all')), 6, 'left');
f = pad(sprintf('%.2f', mean(time(:, :, 2) / 60, 'all')), 6, 'left');
fprintf('%smin to acquire %.2f%%of the data from a single session (male mice).\n', m, target);
fprintf('%smin to acquire %.2f%%of the data from a single session (female mice).\n', f, target);

%% Choose a bout and plot phases.
% k = find(string({bouts.uid}).contains('20220126105939218949'));
% k = find(string({bouts.uid}).contains('20220128172928869897'));
% k = find(string({bouts.uid}).contains('20220127145456993156'));
k = find(string({bouts.uid}).contains('20220124110455895920'));

k = k(1);
bout = bouts(k);
file = files(bout.fid);
[CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = getBout(@() config.getter(file.path), bout);
clf()
plotPhases(CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY, config.minStrideDuration, config.maxStrideDuration, config.minPhaseProminenceSD, config.acquisitionRate);

%% Choose a full video file and plot phases.
k = string({files.uid}).contains('0126105939218949');
file = files(k);
[CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = config.getter(file.path);

% Plot swing and stance.
figure(9);
plotPhases(CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY, config.minStrideDuration, config.maxStrideDuration, config.minPhaseProminenceSD, config.acquisitionRate);
axs = findall(gcf, 'Type', 'Axes');
linkaxes(axs, 'xy');

%% Helper functions.
function [CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = getBout(getter, bout)
    [CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = getter();
    range = bout.epoch(1):bout.epoch(2);
    CX = CX(range);
    CY = CY(range);
    CA = CA(range);
	FLX = FLX(range);
	FLY = FLY(range);
	FRX = FRX(range);
	FRY = FRY(range);
	BLX = BLX(range);
	BLY = BLY(range);
	BRX = BRX(range);
	BRY = BRY(range);
end

function output = extractData(sessions, groups, ids, data, mask, sex, free, single, isBout)
    nIds = numel(ids);
    nGroups = numel(groups);
    % Everything defaults to NaN.
    count = NaN(nIds, nGroups);
    duration = NaN(nIds, nGroups);
    strideCount = NaN(nIds, nGroups);
    regularityIndex = NaN(nIds, nGroups);
    speed = NaN(nIds, nGroups);
    swingDuration = NaN(nIds, nGroups);
    stanceDuration = NaN(nIds, nGroups);
    free = free == "free";
    single = single == "single";
    isBout = nargin > 7 & isBout;
    for group = groups
        for id = ids
            % Select bouts matching requirements from all sessions recorded.
            caseMask = mask(:)' & [data.sex] == sex & [data.group] == group & [data.free] == free & [data.single] == single;
            if single || isBout
                idMask = [data.id] == id;
            else
                idMask = [data.id] == 0 & cellfun(@(ids) ismember(id, ids), {data.ids});
            end
            caseMask = caseMask & idMask;
            
            % Total duration (hours) for these unique sessions.
            if any(caseMask)
                % Unique sessions involved in this mask.
                k = ismember({sessions.name}, {data(caseMask).session});
                delta = seconds(diff([sessions(k).epoch]));
                delta(delta < 1800) = 1800;
                sessionDuration = sum(delta) / 3600;
                
                % Number of videos per mouse, per hour.
                count(id, group) = sum(caseMask) / sessionDuration;
                
                % Bout duration per mouse, per hour.
                if isBout
                    duration(id, group) = sum(diff([data(caseMask).epoch]));
                else
                    duration(id, group) = sum([data(caseMask).frameCount]);
                end
                duration(id, group) = duration(id, group) / sessionDuration;
                
                % Return session-average of the stride count.
                strideCount(id, group) = mean([data(caseMask).strideCount]);
                % Return session-average of the regularity index in videos per mouse.
                regularityIndex(id, group) = mean([data(caseMask).regularityIndex]);
                % Return session-average speed per mouse.
                speed(id, group) = mean([data(caseMask).speed]);
                % Return session-average swing and stance per mouse.
                swingDuration(id, group) = mean([data(caseMask).swingDuration]);
                stanceDuration(id, group) = mean([data(caseMask).stanceDuration]);
            end
        end
    end
    output = struct();
    output.count = count(:);
    output.duration = duration(:);
    output.strideCount = strideCount(:);
    output.regularityIndex = regularityIndex(:);
    output.speed = speed(:);
    output.swingDuration = swingDuration(:);
    output.stanceDuration = stanceDuration(:);
end

function data = appendData(data, config, getTracking)
    fcn = @(x, y, angle) getPhases(x, y, angle, config.minStrideDuration * config.acquisitionRate, config.maxStrideDuration * config.acquisitionRate, config.minPhaseProminenceSD);

    [CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = getTracking();
    [cx1, k] = min(CX);
    cy1 = CY(k);
    [cx2, k] = max(CX);
    cy2 = CY(k);
    distance = sqrt((cx2 - cx1) ^ 2 + (cy2 - cy1) ^ 2);

    nSamples = numel(CX);

    % Get phases.
    FLP = fcn(FLX - CX, FLY - CY, CA); % L
    FRP = fcn(FRX - CX, FRY - CY, CA); % R
    BLP = fcn(BLX - CX, BLY - CY, CA); % l
    BRP = fcn(BRX - CX, BRY - CY, CA); % r
    
    % Get swing and stance periods.
    swingCount = zeros(1, 4);
    stanceCount = zeros(1, 4);
    [FLW, FLC] = flagToEpochs(FLP);
    swingCount(1) = size(FLW, 2);
    stanceCount(1) = size(FLC, 2);
    [FRW, FRC] = flagToEpochs(FRP);
    swingCount(2) = size(FRW, 2);
    stanceCount(2) = size(FRC, 2);
    [BLW, BLC] = flagToEpochs(BLP);
    swingCount(3) = size(BLW, 2);
    stanceCount(3) = size(BLC, 2);
    [BRW, BRC] = flagToEpochs(BRP);
    swingCount(4) = size(BRW, 2);
    stanceCount(4) = size(BRC, 2);
    
    % Count full strides.
    strideCount = min(swingCount, swingCount);
    strideCount = min(strideCount, [], 2);

    % Velocity (cm / s).
    speed = mean(sqrt(diff(CX) .^ 2 + diff(CY) .^ 2)) * config.acquisitionRate;
    
    % Swing and stance duration.
    swingDuration = [mean(diff(FLW)), mean(diff(FRW)), mean(diff(BLW)), mean(diff(BRW))] / config.acquisitionRate;
    stanceDuration = [mean(diff(FLC)), mean(diff(FRC)), mean(diff(BLC)), mean(diff(BRC))] / config.acquisitionRate;
    
    % Normal step sequence patterns (NSSPs). Koopmans et al 2005 @ Cheng et al 1997.
    sequences = {
	    'LrlR' 'RLrl' 'lRLr' 'rlRL' % Ca
	    'LRlr' 'RlrL' 'lrLR' 'rLRl' % Cb
	    'LlRr' 'RrLl' 'lRrL' 'rLlR' % Aa
	    'LrRl' 'RlLr' 'lLrR' 'rRlL' % Ab
	    'LlrR' 'RLlr' 'lrRL' 'rRLl' % Ra
	    'LRrl' 'RrlL' 'lLRr' 'rlLR' % Rb
    };
    columns = 'LRlr';
    
    nSequences = size(sequences, 1);
    repeat = @(epoch, letter) repmat(letter, 1, size(epoch, 2));
    
    % Regularity index.
    % Find footfall order.
    footfallTicks = [FLC(1, :), FRC(1, :), BLC(1, :), BRC(1, :)];
    if numel(unique(footfallTicks)) >= 4
        steps = [repeat(FLC, 'L'), repeat(FRC, 'R'), repeat(BLC, 'l'), repeat(BRC, 'r')];
        % Sort by time.
        [~, o] = sort(footfallTicks);
        steps = steps(o);
        counts = 0;
        column = columns == steps(1);
        for s = 1:nSequences
            counts = counts + string(steps).count(sequences{s, column});
        end
        regularityIndex = counts * 4 / numel(steps) * 100;
    else
        regularityIndex = NaN;
    end
    
    data.regularityIndex = regularityIndex;
    data.swingCount = swingCount;
    data.stanceCount = stanceCount;
    data.strideCount = strideCount;
    data.swingDuration = swingDuration;
    data.stanceDuration = stanceDuration;
    data.distance = distance;
    data.speed = speed;
    
    % Distance from center.
    FLM = sqrt((FLX - CX) .^ 2 + (FLY - CY) .^ 2);
    FRM = sqrt((FRX - CX) .^ 2 + (FRY - CY) .^ 2);
    BLM = sqrt((BLX - CX) .^ 2 + (BLY - CY) .^ 2);
    BRM = sqrt((BRX - CX) .^ 2 + (BRY - CY) .^ 2);
    
    % Check signal-to-noise ratio.
    if nSamples > 1
        data.snr = db2mag([snr(FLM, config.acquisitionRate), ...
                                 snr(FRM, config.acquisitionRate), ...
                                 snr(BLM, config.acquisitionRate), ...
                                 snr(BRM, config.acquisitionRate)]);
    else
        data.snr = NaN;
    end
end