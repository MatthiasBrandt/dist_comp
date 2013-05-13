classdef c_remote_task < handle
    properties
        s_start_command
        dir_output
        
        st_instance_info
        
        st_tasks
        
        c_pre_process_fcn
        c_local_fcn
        
        % server properties
        st_server_info
        
        % ssh connection object
        obj_ssh
        
        temp_dir
        
        dir_local_temp
        
        filename_scheme
        
        N_instances
        
        h_progbar
        
    end
    
    methods
        function obj = c_remote_task()
            % this command is executed (as a system command) to launch an instance of
            % matlab and run the desired MATLAB command(s):
            obj.s_start_command = 'start "server %.0d" /min cmd /c "matlab -automation -r "%s""';
            
            % the output dir for the demo files:
            obj.dir_output = 'temp';
            
            % create the output directory if it doesn't exist:
            if exist(obj.dir_output, 'dir') ~= 7
                mkdir(obj.dir_output);
            end
            
            % internal...
            obj.set_N_instances(1);
            %             obj.st_instance_info.vec_b_server_free = true(obj.N_instances, 1);
            % %             obj.st_instance_info.vec_b_server_working = false(obj.N_instances, 1);
            %             obj.st_instance_info.vec_task_id = -1 * ones(obj.N_instances, 1);
            
            obj.st_tasks = [];
            
            obj.c_pre_process_fcn = [];
            
            obj.dir_local_temp = fullfile('c:', 'remote_task_temp');
            
            obj.st_server_info.address = '192.168.1.2';
            obj.st_server_info.username = 'admin';
            obj.st_server_info.password = '16PSsba1!';
%             obj.st_server_info.task_path = '/share/APFELNETZ/remote_task_normalized_2';
            obj.st_server_info.task_path = '/share/APFELNETZ/remote_task';%_2013-05-01';
            
            obj.temp_dir = fullfile('.', 'temp');
            
            obj.filename_scheme = 'task_%05.0f';
            
            obj.h_progbar = makeProgBar();
        end
        
        function obj = set_server_info(obj, address, username, password)
            obj.st_server_info.address = address;
            
            if nargin >= 3
                obj.st_server_info.username = username;
            end
            
            if nargin >= 4
                obj.st_server_info.password = password;
            end
        end
        
        function obj = connect(obj)
            % open the connection to the server
            obj.obj_ssh = ssh2_config(obj.st_server_info.address,obj.st_server_info.username,obj.st_server_info.password);
        end
        
        function obj = disconnect(obj)
            %close connection when done
            obj.obj_ssh = ssh2_close(obj.obj_ssh);
        end
        
        function obj = add_task(varargin)
            obj = varargin{1};
            user_data = varargin{2};
            pre_process_fcn = varargin{3};
            fcn_name = varargin{4};
            for a = 5 : nargin
                c_parameters{a-4} = varargin{a};
            end
            
            new_task_id = obj.get_next_free_task_id();
            
            filename_remote = sprintf([obj.filename_scheme], new_task_id);
            filename_local_temp = uuid();
            
            % save parameters
            save(fullfile(obj.temp_dir, filename_local_temp), 'user_data', 'pre_process_fcn', 'fcn_name', 'c_parameters');
            
            % write status
            obj.write_status(new_task_id, sprintf('created by: %s on %s', get_user_name(), get_machine_name()));
            
            scp_put(obj.obj_ssh, [filename_local_temp '.mat'], obj.st_server_info.task_path, obj.temp_dir, [filename_remote '.mat']);
            
            display(['just copied task ' num2str(new_task_id) ' to the server']);
        end
        
        function obj = set_N_instances(obj, N)
            obj.N_instances = N;
            obj.st_instance_info.vec_b_server_free = true(N, 1);
            obj.st_instance_info.vec_b_server_working = false(N, 1);
            obj.st_instance_info.vec_task_id = -1 * ones(N, 1);
        end
        
        function write_status(obj, task_id, string)
            filename = [sprintf(obj.filename_scheme, task_id) '_status'];
            
            % get rid of line breaks
            string = strrep(string, char(10), '/');
            
            %             % check whether the file exists already on the server
            %             s_command = sprintf('[ -f %s/%s] && echo "found" || echo "not found"', obj.st_server_info.task_path, filename);
            %             [obj.obj_ssh, result] = ssh2_command(obj.obj_ssh, s_command, false);
            %             if strcmp(lower(result{1}), 'not found')
            %                 % create an empty file
            %                 s_command = sprintf('touch %s/%s', obj.st_server_info.task_path, filename);
            %                 obj.obj_ssh = ssh2_command(obj.obj_ssh, s_command);
            %             end
            
            % writes entries into the status file
            s_status_string = sprintf('[%s] %s', datestr(now), string);
            s_command = sprintf('echo "%s" >> %s/%s', s_status_string, obj.st_server_info.task_path, filename);
            [obj.obj_ssh, ~] = ssh2_command(obj.obj_ssh, s_command);
            
        end
        
        function obj = set_required_files(obj, path)
            % makes a package that is downloaded by all task-computing
            % clients before executing the task(s)
            
            b_isdir = (exist(path, 'file') ~= 2);
            
            if b_isdir
                st_files = findFile('\w*', path, false, 1);
                N_files = length(st_files);
                c_files = cell(N_files, 1);
                for a = 1 : N_files
                    c_files{a} = fullfile(st_files(a).path, st_files(a).name);
                end
            else
                c_files = path;
            end
            
            temp_filename =  [uuid() '.zip'];
            zip(fullfile(obj.temp_dir,temp_filename), c_files);
            
            obj.obj_ssh = scp_put(obj.obj_ssh, temp_filename, obj.st_server_info.task_path, obj.temp_dir, 'package.zip');
        end
        
        function process_tasks(obj, vec_idx_task_id)
            % first: find out which task is ready to be processed
            
            while true
                % find a free instance
                
                while ~any(obj.st_instance_info.vec_b_server_free)
                    for b = 1 : obj.N_instances
                        obj.st_instance_info.vec_b_server_free(b) = isempty(taskinfo(sprintf('server %.0d', b)));
                    end
                    %display('waiting for free instance');
                    pause(5); % wait a little bit for each instance to start and terminate etc.
                end
                idx_cur_server = find(obj.st_instance_info.vec_b_server_free, 1, 'first');
                
                %display('free instance found. searching for unprocessed tasks...');
                fprintf('%d free instances. searching for unprocessed tasks\n', nnz(obj.st_instance_info.vec_b_server_free));
                [~, vec_task_id, st_tasks] = obj.get_task_list();
                
                %                 N_tasks = length(vec_task_id);
                
                if nargin == 1
                if false
                    % get id of first unprocessed task
                    c_temp = struct2cell(st_tasks);
                    id_next_unprocessed = find(strcmp(c_temp(2, :,:), 'unprocessed'), 1, 'first');
                else
                    % pick a random unprocessed task
                    c_temp = struct2cell(st_tasks);
                    vec_idx_unprocessed = find(strcmp(c_temp(2, :, :), 'unprocessed'));
                    N_unprocessed = length(vec_idx_unprocessed);
                    if N_unprocessed > 0
                    vec_temp_randperm = randperm(N_unprocessed);
                    id_next_unprocessed = vec_idx_unprocessed(vec_temp_randperm(1));
                    else
                        id_next_unprocessed = [];
                    end
                end
                
                vec_cur_task_id = id_next_unprocessed;
                else
                     vec_cur_task_id = [];
                    % list of tasks specified
                    c_temp = struct2cell(st_tasks);
                    for a = 1 : length(vec_idx_task_id)
                        cur_idx = vec_idx_task_id(a);
                        if strcmp(c_temp(2, :, cur_idx), 'unprocessed')
                            vec_cur_task_id = cur_idx;
                            break;
                        end
                    end
                end
                if isempty(vec_cur_task_id)
                    display('no unprocessed tasks found. waiting a little...');
                    pause(60);
                    
                    continue;
                end
               
                    
                
                %                 for a = 1 : N_tasks
                %                     b_task_ready_to_process = obj.get_task_ready_to_process(vec_task_id(a));
                
                %                     if b_task_ready_to_process
                
                
                display(['start processing task #' num2str(vec_cur_task_id) '...']);
                % write status file
                obj.write_status(vec_cur_task_id, sprintf('started processing on %s', get_machine_name()));
                
                % download the task file
                filename = [sprintf(obj.filename_scheme, vec_cur_task_id) '.mat'];
                obj.obj_ssh = scp_get(obj.obj_ssh, filename, obj.temp_dir, obj.st_server_info.task_path);
                
                % load data from the task file
                st_task_data = load(fullfile(obj.temp_dir, filename));
                
                % process...
                
                
                
                %                         if obj.st_instance_info.vec_b_server_working(idx_cur_server)
                %
                %                             % todo: no error handling so far...
                %                             obj.st_instance_info.vec_b_server_working(idx_cur_server) = false;
                %
                %                             % check whether the output file has been written
                %                             filename_output = [sprintf(obj.filename_scheme, obj.st_instance_info.vec_task_id(idx_cur_server)) '_output.mat'];
                %                             b_output_file_written = exist(fullfile(obj.dir_local_temp, filename_output), 'file') == 2;
                %                             if b_output_file_written
                %                                 % copy to the server
                %                                 obj.obj_ssh = scp_put(obj.obj_ssh, filename_output, obj.st_server_info.task_path, fullfile(obj.dir_local_temp));
                %
                %                                 % write status file (seems that everything is okay...)
                %                                 obj.write_status(obj.st_instance_info.vec_task_id(idx_cur_server), sprintf('finished'));
                %                             else
                %                                 % write status file (no output file written -> ??)
                %                                 obj.write_status(obj.st_instance_info.vec_task_id(idx_cur_server), sprintf('finished - but no output file has been found'));
                %                             end
                %                         end
                obj.st_instance_info.vec_task_id(idx_cur_server) = vec_cur_task_id;
                
                % prepare pre-process function calls
                s_pre_process_function_calls = [];
                for b = 1 : length(obj.c_local_fcn)
                    s_pre_process_function_calls = [...
                        s_pre_process_function_calls ...
                        obj.c_local_fcn{b} ';'];
                end
                
                s_pre_process_function_calls = [ ...
                    s_pre_process_function_calls ...
                    st_task_data.pre_process_fcn];
                
                % prepare the function call
                s_function_call = st_task_data.fcn_name;
                s_function_call = [s_function_call '('];
                for b = 1 : length(st_task_data.c_parameters)
                    switch class(st_task_data.c_parameters{b})
                        case 'double'
                            new_argument = mat2str(st_task_data.c_parameters{b});
                        case 'char'
                            new_argument = ['''' st_task_data.c_parameters{b} ''''];
                        otherwise
                            new_argument =st_task_data.c_parameters{b};
                    end
                    s_function_call = [s_function_call new_argument];
                    if b < length(st_task_data.c_parameters)
                        s_function_call = [s_function_call ', '];
                    end
                end
                s_function_call = [s_function_call ');'];
                
                runtime_directory = cd;
                
                
                
                % another string to make sure the temp directory
                % exists
                s_dir_temp_command = sprintf('if exist(''%s'', ''dir'') ~= 7, mkdir(''%s''), end', obj.dir_local_temp, obj.dir_local_temp);
                
                %                         s_finish_command = sprintf(
                
                s_command = sprintf('pause(5); task_id=%.0f; %s, %s; cd(''%s''); try,[output{1:nargout(''%s'')}]=%s; save(''%s'', ''output''); b_success=true; catch, b_success=false; end;remote_task_finish_script; exit', vec_cur_task_id, s_dir_temp_command, s_pre_process_function_calls, runtime_directory, st_task_data.fcn_name, s_function_call, fullfile(obj.dir_local_temp, [sprintf(obj.filename_scheme, vec_cur_task_id) '_output']));
                
                % run this system command
                system(sprintf(obj.s_start_command, idx_cur_server, s_command));
                
                obj.st_instance_info.vec_b_server_free(idx_cur_server) = false;
                obj.st_instance_info.vec_b_server_working(idx_cur_server) = true;
                
                
                
                %                         break;
                
                %                     else
                %                         continue;
                %                     end
                %                         % no task is ready to be processed
                %                         % -> check whether there are still tasks being
                %                         % processed on this machine
                %                         while any(~obj.st_instance_info.vec_b_server_free)
                %                             for b = 1 : obj.N_instances
                %                                 obj.st_instance_info.vec_b_server_free(b) = isempty(taskinfo(sprintf('server %.0d', b)));
                %
                %                                 if obj.st_instance_info.vec_b_server_free(b) && obj.st_instance_info.vec_b_server_working(b)
                %                                     % copy the results to the main server
                %                                     % todo: no error handling so far...
                %                                     obj.st_instance_info.vec_b_server_working(idx_cur_server) = false;
                %
                %                                     % check whether the output file has been written
                %                                     filename_output = [sprintf(obj.filename_scheme, obj.st_instance_info.vec_task_id(b)) '_output.mat'];
                %                                     b_output_file_written = exist(fullfile(obj.dir_local_temp, filename_output), 'file') == 2;
                %                                     if b_output_file_written
                %                                         % copy to the server
                %                                         obj.obj_ssh = scp_put(obj.obj_ssh, filename_output, obj.st_server_info.task_path, fullfile(obj.dir_local_temp));
                %
                %                                         % write status file (seems that everything is okay...)
                %                                         obj.write_status(obj.st_instance_info.vec_task_id(b), sprintf('finished'));
                %                                     else
                %                                         % write status file (no output file written -> ??)
                %                                         obj.write_status(obj.st_instance_info.vec_task_id(b), sprintf('finished - but no output file has been found'));
                %                                     end
                %                                 end
                %                                 obj.st_instance_info.vec_task_id(b) = -1;
                %                             end
                %                             pause(5); % wait a little bit for each instance to start and terminate etc.
                %                         end
                
                %                 end
                %                 pause(1);
            end
        end
        
        function reset_status(obj, task_id)
            for a = 1:length(task_id)
                obj.write_status(task_id(a), 'reset. start all over...');
            end
        end
        
        function cancel_task(obj, task_id)
            for a = 1:length(task_id)
                obj.write_status(task_id(a), 'cancelled');
            end
        end
        
        function b_okay_to_process = get_task_ready_to_process(obj, task_idx)
            %             % check whether it's okay to process this combination
            %
            %             % download the corresponding status file
            %             % filename_local_temp = uuid();
            %             filename_remote = [sprintf(obj.filename_scheme, task_idx) '_status'];
            %             obj.obj_ssh = scp_get(obj.obj_ssh, filename_remote, obj.temp_dir, obj.st_server_info.task_path);
            %             filename_local = fullfile(obj.temp_dir, filename_remote);
            %
            %             fid = fopen(filename_local, 'r');
            %
            %             b_okay_to_process = true;
            %
            %             while ~feof(fid)
            %                 cur_line = fgetl(fid);
            %             end
            %
            %             fclose(fid);
            %
            %             temp = regexp(cur_line, '\w* (finished)$', 'match');
            %             b_done_found = ~isempty(temp);
            %
            %             temp = regexp(cur_line, '\w*(started processing)\w*', 'match');
            %             b_started_processing_found = ~isempty(temp);
            %
            %             b_okay_to_process = ~b_done_found && ~b_started_processing_found;
            
            st_temp = obj.get_task_status(task_idx);
            s_status = st_temp.status;
            
            switch s_status
                case 'unprocessed'
                    b_okay_to_process = true;
                otherwise
                    b_okay_to_process = false;
            end
            
        end
        
        function get_finished_tasks(obj, target_dir)
            [~, ~, st_tasks] = obj.get_task_list();
            
            if isempty(st_tasks)
                display('no tasks found');
                return;
            end
            
            N_tasks = length(st_tasks);
            
            vec_b_finished = strcmp({st_tasks.status}, 'finished');
            
            obj.h_progbar(sprintf('(%.0f/%.0f) tasks found (all/finished)', N_tasks, nnz(vec_b_finished)), 'info');
            
            idx_task_finished = find(vec_b_finished);
            
            if isempty(idx_task_finished)
                %display('no finished tasks found');
                return;
            end
            
            if exist(target_dir, 'dir') ~= 7
                mkdir(target_dir);
            end
            
            % download finished tasks
            obj.h_progbar('downloading finished tasks', 1, nnz(vec_b_finished));
            for a = 1 : length(idx_task_finished)
                cur_output_file_name = [sprintf(obj.filename_scheme, st_tasks(idx_task_finished(a)).task_id) '_output.mat'];
                % get the remote file date
                % (we need this anyway to correctly set the local file
                % modification time...)
                s_command = sprintf('stat %s/%s -c size:%%s,change:%%z', obj.st_server_info.task_path, cur_output_file_name);
                [obj.obj_ssh, c_result] = ssh2_command(obj.obj_ssh, s_command);
                c_temp = regexp(c_result{1}, '((?<=size:)\d*|(?<=change:)[\W\S]*)', 'match');
                remote_size = str2num(c_temp{1});
                remote_date = datevec(c_temp{2});
                
                % find out whether there's already a local file with the
                % same name
                
                if exist(fullfile(target_dir, cur_output_file_name), 'file') == 2
                    % we need to check whether the file has changed on the
                    % server
                    
                    
                    
                    % get the local size and date
                    st_temp = dir(fullfile(target_dir, cur_output_file_name));
                    local_size = st_temp.bytes;
                    local_date = datevec(st_temp.datenum);
                    
                    b_files_different = ...
                        remote_size ~= local_size ...
                        || any(remote_date ~= local_date);
                    
                    if ~b_files_different
                        obj.h_progbar(a);
                        continue;
                    end
                end
                %copy
                
                obj.obj_ssh = scp_get(obj.obj_ssh, [sprintf(obj.filename_scheme, st_tasks(idx_task_finished(a)).task_id) '.mat'], target_dir, obj.st_server_info.task_path);
                obj.obj_ssh = scp_get(obj.obj_ssh, [sprintf(obj.filename_scheme, st_tasks(idx_task_finished(a)).task_id) '_output.mat'], target_dir, obj.st_server_info.task_path);
                set_file_modification_date(fullfile(target_dir, cur_output_file_name), remote_date);
                
                obj.h_progbar(a);
                
            end
            obj.h_progbar('done');
        end
        function st_return = get_task_status(obj, task_idx)
            % check whether it's okay to process this combination
            
            %             % download the corresponding status file
            %             % filename_local_temp = uuid();
            %             filename_remote = [sprintf(obj.filename_scheme, task_idx) '_status'];
            %             obj.obj_ssh = scp_get(obj.obj_ssh, filename_remote, obj.temp_dir, obj.st_server_info.task_path);
            %             filename_local = fullfile(obj.temp_dir, filename_remote);
            %
            %             fid = fopen(filename_local, 'r');
            
            %             b_okay_to_process = true;
            
            %             while ~feof(fid)
            %                 cur_line = fgetl(fid);
            %             end
            
            %             fclose(fid);
            
            if nargin == 2
                s_task_file_name = [obj.st_server_info.task_path, '/', [sprintf(obj.filename_scheme, task_idx) '_status']];
                s_command = sprintf('tail -n 1 -v %s', s_task_file_name);
            elseif nargin == 1
                % this was old and causes problems with too many open files
                %s_command = sprintf('tail -n 1 -v %s/*_status', obj.st_server_info.task_path);
                % this worked but was too slow
                %s_command = sprintf('for filename in %s/*_status; do tail -n 1 -v ${filename}; done', obj.st_server_info.task_path);
                s_command = sprintf('ls %s/*_status | xargs -n 500 tail -n 1 -v', obj.st_server_info.task_path);
            end
            [obj.obj_ssh, c_result] = ssh2_command(obj.obj_ssh, s_command);
            
            N_tasks = 0;
            
            for a = 1 : size(c_result, 1)
                cur_line = c_result{a};
                
                if isempty(cur_line)
                    continue;
                end
                
                if strcmp(cur_line(1:2), '==')
                    N_tasks = N_tasks + 1;
                    c_temp = regexp(cur_line, '(?<=_)\d*(?=_)', 'match');
                    st_return(N_tasks).task_id = str2num(c_temp{1});
                    b_header_line = true; % must be first line so no init...
                elseif b_header_line
                    s_status = 'unprocessed';
                    s_comment = '';
                    c_temp = regexp(cur_line, '\w* (finished)$', 'match');
                    if ~isempty(c_temp)
                        s_status = 'finished';
                    end
                    c_temp = regexp(cur_line, '\w*(started processing)\w*', 'match');
                    if ~isempty(c_temp)
                        s_status = 'being processed';
                        % find the machine that this task is processed on
                        c_temp = regexp(cur_line, '(?<=on )[\w-]*', 'match');
                        if ~isempty(c_temp)
                            s_status = [s_status ' on ' c_temp{1}];
                        end
                    end
                    c_temp = regexp(cur_line, '\w*(finished - but no output file has been found)\w*', 'match');
                    if ~isempty(c_temp)
                        s_status = 'no output written';
                    end
                    c_temp = regexp(cur_line, '\w*(cancelled)\w*', 'match');
                    if ~isempty(c_temp)
                        s_status = 'cancelled';
                    end                    
                    c_temp = regexp(cur_line, '\w* ERROR: \w*', 'match');
                    if ~isempty(c_temp)
                        s_status = 'error';
                        c_temp = regexp(cur_line, '(?<=ERROR: [)[\w\W]*(?=])', 'match');
                        s_comment = c_temp{1};
                    end
                    st_return(N_tasks).status = s_status;
                    st_return(N_tasks).comment = s_comment;
                    b_header_line = false;
                else
                    % do nothing...
                end
                %
                %
                %             c_status = 'unprocessed';
                %
                %             temp = regexp(c_last_line{1}, '\w* (finished)$', 'match');
                %             if ~isempty(temp)
                %                 s_status = 'finished';
                %             end
                %             temp = regexp(c_last_line{1}, '\w*(started processing)\w*', 'match');
                %             if ~isempty(temp)
                %                 s_status = 'being processed';
                %                 % find the machine that this task is processed on
                %                 temp = regexp(c_last_line{1}, '(?<=on )[\w-]*', 'match');
                %                 if ~isempty(temp)
                %                     s_status = [s_status ' on ' temp{1}];
                %                 end
                %             end
                %             temp = regexp(c_last_line{1}, '\w*(finished - but no output file has been found)\w*', 'match');
                %             if ~isempty(temp)
                %                 s_status = 'no output written';
                %             end
                
                
                
                
            end
        end
        
        function obj = add_local_fcn(obj, c_local_fcn)
            obj.c_local_fcn{end+1} = c_local_fcn;
        end
        
        function c_result = robust_ssh_command(obj, s_command)
            while true
                try
                    [obj.obj_ssh c_result] = ssh2_command(obj.obj_ssh, s_command);
                    break;
                catch
                    display('connection lost. trying to reconnect in 5 seconds...');
                    pause(5);
                    obj = obj.connect();
                end
            end
        end
        
        function [c_tasks, vec_task_id, st_task_status] = get_task_list(obj)
            s_command = sprintf('ls %s | grep "\\w*_\\(status\\)$"', obj.st_server_info.task_path);
            c_tasks = obj.robust_ssh_command(s_command);
            
            if isempty(c_tasks{1})
                vec_task_id = [];
                st_task_status = [];
                return;
            else
                
                N_tasks = length(c_tasks);
                vec_task_id = zeros(N_tasks, 1);
                for a = 1 : N_tasks
                    c_temp = regexp(c_tasks{a}, '(?<=_)\d*(?=_)', 'match');
                    vec_task_id(a) = str2num(c_temp{1});
                end
            end
            
            if nargout == 3
                if false
                    % slow
                    for a = 1 : N_tasks
                        st_task_status(a).task_id = vec_task_id(a);
                        st_temp = obj.get_task_status(vec_task_id(a));
                        st_task_status(a).status = st_temp.status;
                    end
                else
                    % hopefully faster
                    st_task_status = obj.get_task_status(); % empty argument list -> all files
                end
            end
        end
        
        function id = get_next_free_task_id(obj)
            [~, vec_task_id] = obj.get_task_list();
            if isempty(vec_task_id)
                id = 1;
            else
                id = vec_task_id(end) + 1;
            end
        end
    end
end