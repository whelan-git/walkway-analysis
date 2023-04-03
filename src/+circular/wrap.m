% 2022-07-18. Leonardo Molina.
% 2022-07-18. Last modified.
function d = wrap(data, range)
    d = mod(data + range(2), diff(range)) + range(1);
end