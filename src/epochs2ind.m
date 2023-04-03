% epochs = [1 5; 6 10; 11 15]';
% ind = epochs2ind(epochs)

% 2022-07-14. Leonardo Molina.
% 2022-07-19. Last modified.
function ind = epochs2ind(epochs)
    ind = zeros(0, 1);
    n = numel(epochs);
    for e = 1:2:n - 1
        a = epochs(e);
        b = epochs(e + 1);
        ind = cat(1, ind, colon(a, b)');
    end
    % If all epochs last the same, reshape.
    d = epochs(2:2:end) - epochs(1:2:end - 1);
    if sum(diff(d)) == 0
        ind = reshape(ind, d(1) + 1, []);
    end
end