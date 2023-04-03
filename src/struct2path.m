% 2022-08-05. Leonardo Molina.
% 2022-08-05. Last modified.
function path = struct2path(data)
    code = 'CT';
    date = [data.uid(1:4) '-' data.uid(5:6) '-' data.uid(7:8)];
    basename = [data.prefix, '-', code(data.free + 1), data.uid];
    group = sprintf('%s%02i', data.sex, data.group);
    if data.id > 0
        id = sprintf('%02i', data.id);
        path = fullfile(date, group, id, basename);
    else
        path = fullfile(date, group, basename);
    end
end