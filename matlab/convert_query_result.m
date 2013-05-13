function st_output = convert_query_result(query_result)

c_fieldnames = fieldnames(query_result);
N_fields = length(c_fieldnames);

N_entries = length(query_result.(c_fieldnames{1})); % should all be the same length

for a = 1 : N_entries
    for b = 1 : N_fields
        st_output(a).(c_fieldnames{b}) = query_result.(c_fieldnames{b})(a);
    end
end