% phase = getPhases(pawX, pawY, motionAngle, minStrideDuration, maxStrideDuration, minProminenceSD)
% Returns the phase of the walking cycle for each time index.
%   0: stance
%   1: swing
% 
% Input arguments:
%   pawX and pawY: x and y coordinates of a single paw.
%   motionAngle: angle in radians of forward movement.
%   minStrideDuration: minimum number of frames that must exist in a stride.
%   minProminenceSD: minimum amplitude *prominence* that must exist in a walking phase, expressed as a standard deviation of the phase amplitude.

% 2022-07-11. Leonardo Molina.
% 2023-03-01. Last modified.
function phase = getPhases(pawX, pawY, motionAngle, minStrideDuration, maxStrideDuration, minProminenceSD)
    nSamples = numel(pawX);
    if nSamples >= 3
        % Get paw extension.
        pawD = sqrt(pawX .^ 2 + pawY .^ 2);
        minPeakProminence = abs(minProminenceSD * std(pawD));
        % Get all peaks and valleys.
        minStrideDuration = min(minStrideDuration, nSamples - 2);
        [~, allPeaks] = findpeaks(+pawD, 'MinPeakWidth', minStrideDuration / 2, 'MaxPeakWidth', maxStrideDuration / 2, 'MinPeakProminence', minPeakProminence);
        [~, allValleys] = findpeaks(-pawD, 'MinPeakWidth', minStrideDuration / 2, 'MaxPeakWidth', maxStrideDuration / 2, 'MinPeakProminence', minPeakProminence);
        % Keep only one peak between two consecutive valleys.
        peaks = [];
        test = unique([1; allValleys; nSamples]);
        n = numel(test);
        for i = 1:n - 1
            p = find(allPeaks >= test(i) & allPeaks <= test(i + 1));
            [~, k] = max(pawD(allPeaks(p)));
            peaks = cat(1, peaks, allPeaks(p(k)));
        end
        % Keep only one valley between two consecutive peaks.
        valleys = [];
        test = unique([1; allPeaks; nSamples]);
        n = numel(test);
        for i = 1:n - 1
            p = find(allValleys >= test(i) & allValleys <= test(i + 1));
            [~, k] = min(pawD(allValleys(p)));
            valleys = cat(1, valleys, allValleys(p(k)));
        end
        % Flag phase changes.
        phase = false(nSamples, 1);
        epochs = unique([1; peaks; valleys; nSamples]);
        n = numel(epochs);
        for e = 1:2:n - 1
            a = epochs(e);
            b = epochs(e + 1) - 1;
            phase(a:b) = true;
        end
        phase(nSamples) = phase(nSamples - 1);
    
        % Swing: Paw moves in the same direction as the body.
        % Stance: Paw moves in the opposite direction as the body.
        strideAngle = atan2(diff(pawY), diff(pawX));
        strideAngle(nSamples) = strideAngle(end);
        motionAngle(nSamples) = motionAngle(end);
        angles1 = [strideAngle(phase); (strideAngle(~phase) + pi)];
        angles2 = [motionAngle(phase); (motionAngle(~phase) +  0)]; % !!
        aligned = circular.wrap(circular.mean(angles1 - angles2), [0, pi]) > pi / 2;
        if ~aligned
            phase = ~phase;
        end
    else
        phase = false(size(pawX));
    end
end