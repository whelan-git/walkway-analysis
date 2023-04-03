% Find largest island in a mask.
% [blob, ids, counts] = maxBlob([0 1 1 1 0 1 1 0 1])
% %                  ==>   blob: 0 1 1 1 0 0 0 0 0
% %                  ==>    ids: 0 1 1 1 0 2 2 0 3
% %                  ==> counts: 0 3 3 3 0 2 2 0 1

% 2022-10-25. Leonardo Molina.
% 2022-10-25. Last modified.
function [mask, ids, counts] = maxBlob(mask)
    mask = mask ~= 0;
    change = diff([0; mask(:)]) == 1;
    change = reshape(change, size(mask));
    cs = cumsum(change);
    ids = cs .* mask;
    counts = zeros(size(mask));
    mx = 0;
    for id = 1:max(cs)
        k = ids == id;
        current = sum(k);
        counts(k) = current;
        if current > mx
            mx = current;
        end
    end
    mask = counts == mx;
end