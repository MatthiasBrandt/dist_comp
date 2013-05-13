function s_tuple = py_tuple(vec_input)

s_tuple = '(';

for a = 1 : length(vec_input)
    s_tuple = [s_tuple ...
        num2str(vec_input(a))];
    if a < length(vec_input)
        s_tuple = [s_tuple ', '];
    end
end

s_tuple = [s_tuple ')'];