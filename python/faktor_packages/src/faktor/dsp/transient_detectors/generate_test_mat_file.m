clear, close, clc

st_test(1).a = 1;
st_test(1).b = 2;
st_test(1).st_substruct.sub = 'hallo';
st_test(2).a = 3;
st_test(2).b = 4;
st_test(2).st_substruct.sub = 'duda';

save('test', 'st_test');
