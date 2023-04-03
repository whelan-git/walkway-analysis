% epochs = cuts2epochs(cuts, range, overlap);
% 
% Get epochs from cuts in a range. Optional overlap offsets the start and
% end points of each epoch.
% 
% Example:
%   range = [1, 100];
%   cuts = [20, 50];
%   overlap = [0, 1];
%   epochs = cuts2epochs(cuts, range, overlap);
%      1    20    50
%     19    49    99

% 2022-08-25. Leonardo Molina.
% 2022-08-25. Last modified.
function epochs = cuts2epochs(cuts, range, overlap)
    if nargin < 3
        overlap = [0, 0];
    end
    cuts = cuts(:)';
    steps = unique([range(1), cuts, range(2)]);
    epochs = [steps(1:end - 1) + overlap(1); steps(2:end) - overlap(2)];
end