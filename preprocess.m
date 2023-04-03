% Gait data for individual bouts of locomotion; there can be more than one per file.
% edit('setup');
% [config, paths] = setup();
% [bouts, files, sessions] = preprocess(config, paths);
% 
% Units: cm, s
% 
% Data structure specification:
%   prefix: F|M + group id (2 digit) + [mouse id (2 digit); if tested individually]
%   sex: F or M
%   single: Individually tested
%   free: Freely moving
%   group: Numeric id of group
%   session: Name shared by all video files in a single session (day*prefix).
%   offset: Start time of a file in terms of frames relative to the first video of the session.
%   uid: Timestamp corresponding to date and time a video was captured.
%   id: Numeric id of the mouse if tested individually or 0 if tested as a group.
%   ids: List of unique ids when id == 0, if there is an annotation made.
%   bids: Index of bouts resulting from a given video.
%   recordingDate: datetime obtained from the uid.
%   inferenceDate: datetime obtained from file attributes of the DLC output file.
%   frameCount: number of frames obtained from the DLC output.
%   epochs: valid behavioral epochs detected in the DLC output.
%   epoch: epoch in epochs used to generate a given bout.
%   label: behavioral label for a bout. a:alone, c:chase.

% 2022-07-12. Leonardo Molina.
% 2022-11-14. Last modified.
function [bouts, files, sessions] = preprocess(config, paths)
    % Fields shared among files and bouts.
    sharedFields = {'uid', 'prefix', 'id', 'sex', 'single', 'free', 'group', 'session', 'offset', };
    
    % Prepare data structures.
    fileFields = [sharedFields, {'path', 'frameCount', 'inferenceDate', 'recordingDate', 'ids', 'bids', 'epochs'}];
    bouts = struct();
    
    % Get DLC files.
    nFiles = numel(paths);
    files = cell2struct(cell(numel(fileFields), nFiles), fileFields');
    
    % Helper functions.
    first = @(x) x{1};
    regex = @(varargin) first(regexp(varargin{:}, 'tokens', 'once'));

    fprintf('Initializing... ');
    % Get frame counts from each DLC file.
    frameCounts = countLines(paths) - config.nHeaderLines;
    paths = reshape(paths, 1, []);
    filenames = cellfun(@(path) regex(path, '.*[\\/](.*?)DLC_'), paths, 'UniformOutput', false);
    uid = cellfun(@(filename) regex(filename,'-[TC](\d{20})'), filenames, 'UniformOutput', false);
    % Get inference date from file creation.
    inferenceDate = datetime(cellfun(@(path) dir(path).datenum, paths), 'ConvertFrom', 'datenum');
    inferenceDate.Format = 'yyyy-MM-dd HH:mm:ss';
    % Get session name from filenames and convert into proper date type.
    d = cellfun(@(uid) str2double({uid(1:4) uid(5:6) uid(7:8) uid(9:10) uid(11:12) uid(13:14) uid(15:20)}), uid, 'UniformOutput', false);
    d = cat(1, d{:});
    d = [d(:, 1:5), d(:, 6) + d(:, 7) / 1e6];
    recordingDate = datetime(d);
    recordingDate.Format = 'yyyy-MM-dd HH:mm:ss.SSSSSS';
    % Read prefixes (e.g. F0101 or F0100).
    prefix = cellfun(@(filename) regex(filename, '^([FM]\d{2,4})-'), filenames, 'UniformOutput', false);
    % Complete prefixes (e.g. F01 becomes F0100).
    prefix = cellfun(@(prefix) sprintf('%s%.*s', prefix, numel(prefix) - 5, '00'), prefix, 'UniformOutput', false);
    % Get ids from prefixes.
    id = cellfun(@(prefix) str2double(prefix(4:5)), prefix);
    sex = cellfun(@(prefix) prefix(1), prefix);
    % Mouse was singly tested when id was set to zero.
    single = id ~= 0;
    % Mouse was freely moving if 'T'.
    free = string(filenames).contains("-T");
    group = cellfun(@(prefix) str2double(prefix(2:3)), prefix);

    % Session parameters.
    sessionNames = arrayfun(@(i) sprintf('%04i%02i%02i%s', recordingDate(i).Year, recordingDate(i).Month, recordingDate(i).Day, prefix{i}), 1:nFiles, 'UniformOutput', false)';
    uSessionNames = unique(sessionNames);
    sessions = struct();
    offsets = zeros(size(paths));
    for u = 1:numel(uSessionNames)
        % All data from the same session.
        session = uSessionNames{u};
        k = ismember(sessionNames, session);
        dates = recordingDate(k);
        frameCount = frameCounts(k);
        % Get min and max time values.
        mn = min(dates);
        [mx, f] = max(dates);
        mx = mx + seconds(frameCount(f) / config.acquisitionRate);
        % Duration for each session.
        sessions(u).name = session;
        sessions(u).epoch = [mn; mx];
        % Frame offset.
        sessionOffsets = dates - min(dates);
        sessionOffsets = round(seconds(sessionOffsets) * config.acquisitionRate);
        offsets(k) = sessionOffsets;
    end

    % Populate file structures.
    [files.prefix] = deal(prefix{:});
    [files.sex] = dealVector(sex);
    [files.single] = dealVector(single);
    [files.free] = dealVector(free);
    [files.group] = dealVector(group);
    [files.session] = deal(sessionNames{:});
    [files.offset] = dealVector(offsets);
    [files.uid] = deal(uid{:});
    [files.path] = deal(paths{:});
    [files.frameCount] = dealVector(frameCounts);
    [files.inferenceDate] = dealVector(inferenceDate);
    [files.recordingDate] = dealVector(recordingDate);
    [files.id] = dealVector(id);
    
    % Keep the first occurrence of a series of overlapping videos.
    mask = false(nFiles, 1);
    for s = 1:nFiles
        % Scan videos for each session.
        sessionId = sessionNames{s};
        k = find(ismember(sessionNames, sessionId));
        nFrames = [files(k).frameCount];
        offsets = [files(k).offset];
        epochs = [offsets + 1; nFrames + offsets - 1];
        [~, map] = blendEpochs(epochs);
        [~, u] = unique(map);
        mask(k(u)) = true;
    end

    % Get bouts.
    fprintf('done!\n');
    nBouts = 0;
    for f = 1:nFiles
        file = files(f);
        fprintf('[%04d:%04d] "%s" ', f, nFiles, file.uid);
        if mask(f)
            % Body and paw midpoints, and full body orientation.
            [CX, CY, CA, FLX, FLY, FRX, FRY, BLX, BLY, BRX, BRY] = config.getter(paths{f});
            
            nFrames = numel(CX);
            if nFrames > config.minBoutDuration * config.acquisitionRate
                % Distance from center.
                FLM = sqrt((FLX - CX) .^ 2 + (FLY - CY) .^ 2);
                FRM = sqrt((FRX - CX) .^ 2 + (FRY - CY) .^ 2);
                BLM = sqrt((BLX - CX) .^ 2 + (BLY - CY) .^ 2);
                BRM = sqrt((BRX - CX) .^ 2 + (BRY - CY) .^ 2);
                
                % Estimate swing and stance for the whole clip.
                fcn = @(x, y) getPhases(x, y, CA, config.minStrideDuration * config.acquisitionRate, config.maxStrideDuration * config.acquisitionRate, config.minPhaseProminenceSD);
                FLP = fcn(FLX - CX, FLY - CY);
                FRP = fcn(FRX - CX, FRY - CY);
                BLP = fcn(BLX - CX, BLY - CY);
                BRP = fcn(BRX - CX, BRY - CY);
                
                % Flag frames where paws maintain a consistent path.
                options = {config.correlationThreshold, round(0.5 * config.minStrideDuration * config.acquisitionRate)};
                valid = consistency(FLP, FLM, options{:}) | ...
                        consistency(FRP, FRM, options{:}) | ...
                        consistency(BLP, BLM, options{:}) | ...
                        consistency(BRP, BRM, options{:});
                
                % Flag frames where speed is within limits.
                w = round(config.speedWindowDuration * config.acquisitionRate);
                v = sqrt(diff(CX) .^ 2 + diff(CY) .^ 2) * config.acquisitionRate;
                v = smooth(v, 2.5, w);
                v = cat(1, v, v(end));
                valid = valid & v >= config.minSpeed & v <= config.maxSpeed;
                
                % Flag frames where duration is consistent.
                P1 = flag(FLP == 1 & valid, config.durationSD);
                P0 = flag(FLP == 0 & valid, config.durationSD);
                valid = P1 | P0;
                P1 = flag(FRP == 1 & valid, config.durationSD);
                P0 = flag(FRP == 0 & valid, config.durationSD);
                valid = P1 | P0;
                P1 = flag(BLP == 1 & valid, config.durationSD);
                P0 = flag(BLP == 0 & valid, config.durationSD);
                valid = P1 | P0;
                P1 = flag(BRP == 1 & valid, config.durationSD);
                P0 = flag(BRP == 0 & valid, config.durationSD);
                valid = P1 | P0;
                epochs = flagToEpochs(valid);
    
                % For group data, splice video data according to manual labels of mice id for given epochs.
                sameIds = true;
                entry = config.annotations(f);
                if file.id == 0
                    if ~isempty(entry.labels)
                        % Grab corresponding annotation entry, if any.
                        annotationEpochs = cuts2epochs(entry.cuts, [1, nFrames]);
                        [epochs, k] = intersectEpochs(annotationEpochs, epochs);
                        ids = entry.ids(k);
                        file.ids = unique(ids);
                        % Bout labels.
                        labels = entry.labels(k);
                        sameIds = false;
                    end
                else
                    file.ids = file.id;
                end
                if sameIds
                    % Default annotation is id:0 label:a (no id / 'not chasing').
                    ids = repmat(file.id, 1, size(epochs, 2));
                    labels = repmat({'a'}, 1, size(epochs, 2));
                end
                
                validEpochs = diff(epochs) >= config.minBoutDuration * config.acquisitionRate;
                % Remove epochs flagged with zeros.
                validEpochs = validEpochs & ids > 0;
                epochs = epochs(:, validEpochs);
                ids = ids(validEpochs);
                nEpochs = size(epochs, 2);
                fprintf('nFrames:%4d nEpochs:%2d\n', nFrames, size(epochs, 2));
            else
                nEpochs = 0;
                fprintf('nFrames:%4d nEpochs:%2d\n', nFrames, 0);
            end
            
            % Append data.
            file.frameCount = nFrames;
            file.epochs = epochs;
            bids = [];
            for e = 1:nEpochs
                nBouts = nBouts + 1;
                bouts(nBouts).fid = f;
                bouts(nBouts).epoch = epochs(:, e);
                bids = cat(1, bids, nBouts);
                for i = 1:numel(sharedFields)
                    bname = sharedFields{i};
                    bouts(nBouts).(bname) = file.(bname);
                end
                % Override mouse id.
                bouts(nBouts).id = ids(e);
                % Set mouse label.
                bouts(nBouts).label = labels(e);
            end
            file.bids = bids;
            files(f) = file;
        else
            fprintf('skipped\n');
        end
    end
end

% Keep islands of similar size.
function mask = flag(mask, sd)
    nFrames = numel(mask);
    epochs = flagToEpochs(mask);
    duration = diff(epochs);
    limits = mean(duration) + sd * std(duration) * [-1, +1];
    k = duration >= limits(1) & duration <= limits(2);
    mask = epochsToMask(epochs(:, k), nFrames);
end

function valid = consistency(phases, amplitude, threshold, patternSize)
    % Number of frames for template.
    nFrames = numel(phases);
    valid = false(nFrames, 1);
    [swingEpochs, stanceEpochs] = flagToEpochs(phases);
    
    % Mask for clipped phases.
    epochs = swingEpochs;
    if size(epochs, 2) > 0
        epochs = [epochs(1, :); epochs(1, :) + patternSize - 1];
        keep = all(epochs <= nFrames);
        epochs = epochs(:, keep);
        if size(epochs, 2) >= 3
            k = epochs2ind(epochs);
            % Target phases.
            targets = reshape(amplitude(k), patternSize, []);
            % Template is the most common value at each time step.
            template = median(targets, 2);
            keep = corr(targets, template) >= threshold;
        else
            keep = true(1, size(epochs, 2));
        end
    else
        keep = true(1, size(epochs, 2));
    end
    valid = valid | epochsToMask(swingEpochs(:, keep), nFrames);
    
    % Mask for clipped phases.
    epochs = stanceEpochs;
    if size(epochs, 2) > 0
        epochs = [epochs(1, :); epochs(1, :) + patternSize - 1];
        keep = all(epochs <= nFrames);
        epochs = epochs(:, keep);
        if size(epochs, 2) >= 3
            k = epochs2ind(epochs);
            % Target phases.
            targets = reshape(amplitude(k), patternSize, []);
            % Template is the most common value at each time step.
            template = median(targets, 2);
            keep = corr(targets, template) >= threshold;
        else
            keep = true(1, size(epochs, 2));
        end
    else
        keep = true(1, size(epochs, 2));
    end
    valid = valid | epochsToMask(stanceEpochs(:, keep), nFrames);
end

function varargout = dealVector(input)
    varargout = cell(1, numel(input));
    input = num2cell(input);
    [varargout{:}] = deal(input{:});
end