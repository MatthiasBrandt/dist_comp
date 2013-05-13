clear, close all, clc

dc = c_dist_comp();

dc.add_parameter('number', (1:10));
dc.add_parameter('string', {'hello', 'you'});

struct2table(dc.get_combinations());