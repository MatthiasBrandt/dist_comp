function save_results()

st_settings = evalin('base', 'st_settings');

%javaaddpath(fullfile(st_settings.dir_data, 'mysql-connector-java-5.1.6-bin.jar'));

import edu.stanford.covert.db.MySQLDatabase;

disp('soweit gut')

st_result = evalin('base', 'st_result');
% task_index = evalin('base', 'task_index');

filename_temp = [tempname() '.mat'];

% write data to a tempfile
save(filename_temp, 'st_result');

% create the database connection
db = MySQLDatabase(st_settings.mysql.host, ...
    st_settings.mysql.database, ...
    st_settings.mysql.user, ...
    st_settings.mysql.password);

db.prepareStatement('INSERT INTO results (value) VALUES("{F}")', filename_temp);
db.query();

% obtain the index of the new value in the results table
db.prepareStatement('SELECT LAST_INSERT_ID()');
value_index = db.query();
value_index=value_index.LAST_INSERT_ID__;

value_index

db.prepareStatement('UPDATE tasks SET result = "{Sn}", status=3 WHERE tasks.index = "{Sn}"', value_index, st_settings.task_index);
db.query();