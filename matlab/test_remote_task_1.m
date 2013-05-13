% clear all, close all, clc

javaaddpath(fullfile(cd, 'mysql-connector-java-5.1.6-bin.jar'));

st_settings.mysql.host = '192.168.1.2';
st_settings.mysql.user = 'dist_comp';
st_settings.mysql.password = 'mastering';
st_settings.mysql.database = 'dist_comp';

st_settings.ssh.host = '192.168.1.2';
st_settings.ssh.user = 'admin';
st_settings.ssh.password = '16PSsba1!';

rt = c_remote_task(st_settings);

rt.connect();

rt.add_common_file('F:\Dropbox\arbeit\matlab\file_exchange\28237-querymysql\src');  % required
rt.add_common_file('save_results.m');
rt.add_common_file('prepare.m');
rt.add_common_file('mysql-connector-java-5.1.6-bin.jar'); % required

rt.set_project(2);

rt.add_code_file('demo_code');
rt.add_code_file('Copy_of_demo_code');



% st_parameters.a = 3;
% st_parameters.b = 12;
% 
% rt.add_task('testfunktion', st_parameters, 'langer name2');

for a = 1 : 30
    st_parameters.a = a;
    for b = 1 : 20
        st_parameters.b = b;
        %tic
        rt.add_task('demo_function', st_parameters, ['aufgabe #' num2str((a-1)*10+b)]);
        %toc
        (a-1) * 10 + b
    end
    
end