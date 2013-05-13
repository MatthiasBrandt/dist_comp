classdef c_remote_task < handle
    
    
    properties
        st_settings % global parameters
        db % the mysql database connection
        ssh % the ssh connection
        project_index
    end
    
    methods
        function obj = c_remote_task(st_arguments)
            
            
            obj.st_settings.mysql.host = st_arguments.mysql.host;
            obj.st_settings.mysql.user = st_arguments.mysql.user;
            obj.st_settings.mysql.password = st_arguments.mysql.password;
            obj.st_settings.mysql.database = st_arguments.mysql.database;
            
            obj.st_settings.ssh.host = st_arguments.ssh.host;
            obj.st_settings.ssh.user = st_arguments.ssh.user;
            obj.st_settings.ssh.password = st_arguments.ssh.password;
        end
        
        function obj = connect(obj)
            % first connect to the mysql server
            import edu.stanford.covert.db.MySQLDatabase;
            
            obj.db = MySQLDatabase(obj.st_settings.mysql.host, ...
                obj.st_settings.mysql.database, ...
                obj.st_settings.mysql.user, ...
                obj.st_settings.mysql.password);
            
            % then to the ssh server
            obj.ssh = ssh2_config(obj.st_settings.ssh.host, ...
                obj.st_settings.ssh.user, ...
                obj.st_settings.ssh.password);
            
            % and obtain some settings that are stored in the database
            query = 'SELECT `settings`.root_directory FROM `settings`';
            obj.db.prepareStatement(query);
            query_result = obj.db.query();
            obj.st_settings.server_root_directory = query_result.root_directory{1};
        end
        
        function obj = set_project(obj, project_index)
            obj.project_index = project_index;
        end
        
        function obj = add_common_file(obj, filename)
            % detect whether it's a file or a directory
            b_isdir = exist(filename, 'dir') == 7;
            
            st_filenamesplit = fileNameSplit(filename);
            
            % upload everything to the server
            if b_isdir
                st_files = findFile('\w*', filename, false, inf, true);
                
                % create all required directories on the server
                for a = 1 : length(st_files)
                    ssh2_command(obj.ssh, sprintf('mkdir --parents %s', strrep(fullfile(obj.st_settings.server_root_directory, 'common', st_filenamesplit.name, st_files(a).path), '\', '/')));
                end
                
                % copy the files
                for a = 1 : length(st_files)
                    % upload...
                    % (expecting unix-like directory separators... ("/"))
                    scp_put(obj.ssh, st_files(a).name, strrep(fullfile(obj.st_settings.server_root_directory, 'common', st_filenamesplit.name, st_files(a).path, '\'), '\', '/'), fullfile(filename, st_files(a).path));
                end
                
                type = 2;
            else
                try
                    scp_put(obj.ssh, st_filenamesplit.name, strrep(fullfile(obj.st_settings.server_root_directory, 'common', '\'), '\', '/'), st_filenamesplit.path);
                catch
                    error(lasterr);
                end
                type = 1;
            end
            % find out whether this file is already in the database
            query = 'SELECT `common_files`.index FROM `common_files` WHERE `common_files`.type = "{Si}" && `common_files`.path = "{S}"';
            obj.db.prepareStatement(query, type, st_filenamesplit.name);
            query_result = obj.db.query();
            
            if isempty(query_result.index)
                % add an entry to the database
                query = 'INSERT IGNORE INTO `common_files` (type, path) VALUES("{Si}", "{S}")';
                temp = fileNameSplit(filename);
                obj.db.prepareStatement(query, type, st_filenamesplit.name);
                obj.db.query();
            end
            
        end
        
        function obj = add_code_file(obj, filename)
            % detect whether it's a file or a directory
            b_isdir = exist(filename, 'dir') == 7;
            
            st_filenamesplit = fileNameSplit(filename);
            
            % upload everything to the server
            if b_isdir
                st_files = findFile('\w*', filename, false, inf, true);
                
                % create all required directories on the server
                for a = 1 : length(st_files)
                    ssh2_command(obj.ssh, sprintf('mkdir --parents %s', strrep(fullfile(obj.st_settings.server_root_directory, ['' num2str(obj.project_index)], 'code', st_filenamesplit.name, st_files(a).path), '\', '/')));
                end
                
                % copy the files
                for a = 1 : length(st_files)
                    % upload...
                    % (expecting unix-like directory separators... ("/"))
                    scp_put(obj.ssh, st_files(a).name, strrep(fullfile(obj.st_settings.server_root_directory, ['' num2str(obj.project_index)], 'code', st_filenamesplit.name, st_files(a).path, '\'), '\', '/'), fullfile(filename, st_files(a).path));
                end
                
                type = 2;
            end
            
            % find out whether this code is already in the database
            query = 'SELECT `code_files`.index FROM `code_files` WHERE `code_files`.type = "{Si}" && `code_files`.path = "{S}"';
            obj.db.prepareStatement(query, type, filename);
            query_result = obj.db.query();
            file_index_in_database = query_result.index;
            
            if isempty(file_index_in_database)
            % add an entry to the database
            query = 'INSERT INTO `code_files` (type, path) VALUES("{Si}", "{S}")';
            obj.db.prepareStatement(query, type, filename);
            obj.db.query();
            
            % obtain the index of the new file
            query = 'SELECT `code_files`.index FROM `code_files` WHERE `code_files`.type = "{Si}" && `code_files`.path = "{S}"';
            obj.db.prepareStatement(query, type, filename);
            query_result = obj.db.query();
            file_index_in_database = query_result.index;
            end
            
            query = 'INSERT IGNORE INTO `project_code_files` (project, file) VALUES("{Si}", "{Si}")';
            obj.db.prepareStatement(query, obj.project_index, file_index_in_database);
            obj.db.query();
            
        end
        
        function obj = add_task(obj, function_name, st_parameters, name)
            
            if nargin == 3
                name = '[no name]';
            end
            
            b_task_already_in_database = true;
            
            % obtain the number of tasks in the database
            query = 'SELECT COUNT(`index`) FROM tasks';
            obj.db.prepareStatement(query);
            query_result = obj.db.query();
            
            vec_identical_tasks = (1:query_result.COUNT__index__);
            
            % check whether this function name / parameter combination
            % already exists
            % - first: determine whether the parameters already exist, if
            % yes: get their indices
            % query the database for the parameter names
            c_parameter_names = fieldnames(st_parameters);
            N_parameters = length(c_parameter_names);
            
            % the potential task id's which have the same parameter/value
            % combination
            for a = 1 : N_parameters
                query = 'SELECT * FROM `parameters` WHERE parameters.name = "{S}"';
                obj.db.prepareStatement(query, c_parameter_names{a});
                query_result = obj.db.query();
                
                b_parameter_exists = ~isempty(query_result.index);
                
                if ~b_parameter_exists
                    % add this parameter to the database
                    query = 'INSERT INTO `parameters` (name) VALUES ("{S}")';
                    obj.db.prepareStatement(query, c_parameter_names{a});
                    obj.db.query();
                    
                    % and obtain the index of the new entry
                    query = 'SELECT * FROM `parameters` WHERE parameters.name = "{S}"';
                    obj.db.prepareStatement(query, c_parameter_names{a});
                    query_result = obj.db.query();
                    
                    % this task is obviously not in the database
                    b_task_already_in_database = false;
                    
                    %query_result.index;
                end
                
                parameter_index = query_result.index;
                
                % find out whether the value of this parameter is already
                % in the database
                query = 'SELECT * FROM `values` WHERE values.value = "{S}"';
                obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                query_result = obj.db.query();
                
                b_value_exists = ~isempty(query_result.index);
                
                if ~b_value_exists
                    % add this value to the database
                    query = 'INSERT INTO `values` (value) VALUES ("{S}")';
                    obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                    obj.db.query;
                    
                    % and obtain the index of the new entry
                    query = 'SELECT * FROM `values` WHERE values.value = "{S}"';
                    %                     query = 'SELECT LAST_INSERT_ID()';
                    obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                    query_result = obj.db.query();
                    %                     display(query_result);
                    
                    b_task_already_in_database = false;
                    
                end
                value_index = query_result.index;
                
                % obtain the potential task ids with the same
                % parameter/value combination:
                %                 query = 'SELECT task FROM parameter_values WHERE parameter_values.parameter = "{Si}" && parameter_values.value = "{Si}" && parameter_values.project="{Si}"';
                query = 'SELECT task FROM parameter_values LEFT JOIN tasks ON tasks.index=parameter_values.task WHERE parameter_values.parameter = "{Si}" && parameter_values.value = "{Si}" && parameter_values.project="{Si}" && tasks.function_name="{S}"';
                obj.db.prepareStatement(query, parameter_index, value_index, obj.project_index, function_name);
                query_result = obj.db.query();
                
                vec_identical_tasks = intersect(vec_identical_tasks, query_result.task);
                
                
                %                 % now link everything in the "parameter_values" table
                %                 query = 'INSERT INTO `parameter_values` (project, task, parameter, value) VALUES ("{Si}", "{Si}", "{Si}", "{Si}")';
                %                 obj.db.prepareStatement(query, ...
                %                     obj.project_index, ...
                %                     task_index, ...
                %                     parameter_index, ...
                %                     value_index);
                %                 obj.db.query();
                
                
            end
            
            if isempty(vec_identical_tasks)
                b_task_already_in_database = false;
            end
            
            if ~b_task_already_in_database
                
                % add an entry in the "tasks" table
                query = 'INSERT INTO tasks (status, type, name, function_name, result) VALUES("{Si}", "{S}", "{S}", "{S}", "{Sn}")';
                obj.db.prepareStatement(query, 1, 'matlab', name, function_name, -1);
                obj.db.query();
                
                % and obtain the index of this new task
                query = 'SELECT LAST_INSERT_ID()';
                %             query = 'SELECT * FROM tasks WHERE tasks.name = "{S}"';
                obj.db.prepareStatement(query);
                query_result = obj.db.query();
                task_index = query_result.LAST_INSERT_ID__;
                
                % query the database for the parameter names
                c_parameter_names = fieldnames(st_parameters);
                N_parameters = length(c_parameter_names);
                for a = 1 : N_parameters
                    query = 'SELECT * FROM `parameters` WHERE parameters.name = "{S}"';
                    obj.db.prepareStatement(query, c_parameter_names{a});
                    query_result = obj.db.query();
                    
                    %                 b_parameter_exists = ~isempty(query_result.index);
                    %
                    %                 if ~b_parameter_exists
                    %                     % add this parameter to the database
                    %                     query = 'INSERT INTO `parameters` (name) VALUES ("{S}")';
                    %                     obj.db.prepareStatement(query, c_parameter_names{a});
                    %                     obj.db.query();
                    %
                    %                     % and obtain the index of the new entry
                    %                     query = 'SELECT * FROM `parameters` WHERE parameters.name = "{S}"';
                    %                     obj.db.prepareStatement(query, c_parameter_names{a});
                    %                     query_result = obj.db.query();
                    %
                    %                     %query_result.index;
                    %                 end
                    
                    parameter_index = query_result.index;
                    
                    % find out whether the value of this parameter is already
                    % in the database
                    query = 'SELECT * FROM `values` WHERE values.value = "{S}"';
                    obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                    query_result = obj.db.query();
                    
                    %                 b_value_exists = ~isempty(query_result.index);
                    %
                    %                 if ~b_value_exists
                    %                     % add this value to the database
                    %                     query = 'INSERT INTO `values` (value) VALUES ("{S}")';
                    %                     obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                    %                     obj.db.query;
                    %
                    %                     % and obtain the index of the new entry
                    %                     query = 'SELECT * FROM `values` WHERE values.value = "{S}"';
                    %                     %                     query = 'SELECT LAST_INSERT_ID()';
                    %                     obj.db.prepareStatement(query, mat2str(st_parameters.(c_parameter_names{a})));
                    %                     query_result = obj.db.query();
                    % %                     display(query_result);
                    %
                    %                 end
                    value_index = query_result.index;
                    
                    % now link everything in the "parameter_values" table
                    query = 'INSERT INTO `parameter_values` (project, task, parameter, value) VALUES ("{Si}", "{Si}", "{Si}", "{Si}")';
                    obj.db.prepareStatement(query, ...
                        obj.project_index, ...
                        task_index, ...
                        parameter_index, ...
                        value_index);
                    obj.db.query();
                    %
                    %
                end
                display('task added to the database.');
            else
                display('this task is already in the database.');
            end
            % add an entry to the mysql database
            %query = 'INSERT INTO tasks (name) VALUES ("{S}")';
            %obj.db.prepareStatement(query, 'hallo');
            %obj.db.query();
        end
        
        function st_tasks = get_task_list(obj)
            query = 'SELECT DISTINCT tasks.`index`,tasks.`status`,tasks.`name`,tasks.`function_name` FROM `tasks` LEFT JOIN `parameter_values` ON tasks.index = parameter_values.task WHERE parameter_values.project = "{Si}"';
            obj.db.prepareStatement(query, obj.project_index);
            query_result = obj.db.query();
            st_tasks = convert_query_result(query_result);
            %vec_index_finished = query_result.index;
        end
        
        function set_status(obj, tasks, status)
            
            % first obtain the task list
            st_tasks = obj.get_task_list();
            
            for a = 1 : length(tasks)
                cur_database_index = st_tasks(a).index;
                query = 'UPDATE `tasks` SET `status` = "{Si}" WHERE `tasks`.`index` = "{Si}"';
                obj.db.prepareStatement(query, status, tasks(cur_database_index));
                obj.db.query();
                
                a / length(tasks)
            end
        end
        
        function obj = get_tasks(obj, dir_target)
            % obtain the indices of finished tasks that belong to this
            % project
            %             query = 'SELECT DISTINCT tasks.`index` FROM `tasks` LEFT JOIN `parameter_values` ON tasks.index = parameter_values.task WHERE tasks.status = 3 && parameter_values.project = "{Si}"';
            
            % obtain the indices of all tasks that belong to this
            % project
            query = 'SELECT DISTINCT tasks.`index` FROM `tasks` LEFT JOIN `parameter_values` ON tasks.index = parameter_values.task WHERE parameter_values.project = "{Si}"';
            obj.db.prepareStatement(query, obj.project_index);
            query_result = obj.db.query();
            vec_index_project_tasks = query_result.index;
            N_project_tasks = length(vec_index_project_tasks);
            
            % generate the task list mat file
            st_parameters = [];
            for a = 1 : N_project_tasks
                % obtain the parameters for this task
                query = 'SELECT `parameter_values`.parameter, `parameter_values`.value FROM `parameter_values` WHERE `parameter_values`.task = "{Si}"';
                obj.db.prepareStatement(query, vec_index_project_tasks(a));
                query_result = obj.db.query();
                parameters_and_values = convert_query_result(query_result);
                N_parameters = length(parameters_and_values);
                
                for b = 1 : N_parameters
                    % get the parameter name
                    query = 'SELECT `parameters`.name FROM `parameters` WHERE `parameters`.index = "{Si}"';
                    obj.db.prepareStatement(query, parameters_and_values(b).parameter);
                    query_result = obj.db.query();
                    parameter_name = query_result.name{1};
                    
                    % get the parameter value
                    query = 'SELECT `values`.value FROM `values` WHERE `values`.index = "{Si}"';
                    obj.db.prepareStatement(query, parameters_and_values(b).value);
                    query_result = obj.db.query();
                    parameter_value = query_result.value{1};
                    
                    st_parameters(a).(parameter_name) = parameter_value;
                end
                a/N_project_tasks
            end
            
            % write the blobs to files in the target directory
            if exist(dir_target, 'dir') ~= 7
                mkdir(dir_target);
            end
            
            save(fullfile(dir_target, 'tasks'), 'st_parameters');
            
            % get the results for each completed task
            query = ['SELECT `results`.`index`,`results`.`value` FROM `results` LEFT JOIN `tasks` ON `tasks`.result = `results`.index WHERE `tasks`.index IN ' py_tuple(vec_index_project_tasks)]; ;
            obj.db.prepareStatement(query);
            query_result = obj.db.query();
            
            
            
            for a = 1 : length(query_result.index)
                fid=fopen(fullfile(dir_target, sprintf('%06d.mat', query_result.index(a))), 'w');
                fwrite(fid, query_result.value{a});
                fclose(fid);
            end
        end
    end
    
    
    
    
end

