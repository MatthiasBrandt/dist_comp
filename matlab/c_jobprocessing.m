classdef c_jobprocessing < handle
    properties
        st_parameters
        c_parameter_names
        N_combinations
        N_parameters
        
        st_local_parameters
        c_local_parameter_names
        N_local_parameters
        
        dir_output
        
        pre_process_fcn;
        
        function_name
        
        file_name_method
        file_name_scheme
        
        N_cores
        b_local
        
        %         c_multi_instance
        %obj_remote_task
    end
    
    methods
        function obj = c_jobprocessing()
            obj.st_parameters = [];
            obj.c_parameter_names = {};
            obj.N_combinations = 0;
            obj.N_parameters = 0;
            
            obj.dir_output = fullfile('.', 'tasks');
            
            obj.function_name = '';
            
            obj.file_name_method = 'numbered';
            
            obj.file_name_scheme = 'task_%s';
            
            obj.N_cores = 1;
            obj.b_local = true;
            
            %             obj.c_multi_instance = c_multi_instance;
            
            %obj.obj_remote_task = c_remote_task();
            
            %obj.obj_remote_task.st_server_info.task_path = '/share/APFELNETZ/remote_task_normalized_2'
            
            %obj.obj_remote_task.connect();
        end
        
        function obj = add_parameter(obj, parameter_name, parameter_values)
            obj.st_parameters.(parameter_name) = parameter_values;
            obj.c_parameter_names{end+1} = parameter_name;
            obj.N_parameters = obj.N_parameters + 1;
            obj.update_N_combinations();
        end
        
        function obj = set_local(b_local)
            obj.b_local = b_local;
        end
        
        function obj = set_N_cores(obj, N_cores)
            obj.N_cores = N_cores;
        end
        
        function obj = add_local_parameter(obj, parameter_name)
            %             obj.st_local_parameters.(parameter_name) = [];
            obj.c_local_parameter_names{end+1} = parameter_name;
            obj.N_local_parameters = obj.N_local_parameters + 1;
        end
        
        function update_N_combinations(obj)
            if obj.N_parameters == 0
                obj.N_combinations = 0;
            else
                obj.N_combinations = 1;
                for a = 1 : obj.N_parameters
                    obj.N_combinations = ...
                        obj.N_combinations ...
                        * length(obj.st_parameters.(obj.c_parameter_names{a}));
                end
            end
        end
        
        function st_combinations = get_combinations(obj, idx_param)
            % recursive
            if nargin == 1
                idx_param = 1;
            end
            
            st_combinations = [];
            
            if idx_param == obj.N_parameters
                for a = 1 : length(obj.st_parameters.(obj.c_parameter_names{idx_param}))
                    cur_value = obj.st_parameters.(obj.c_parameter_names{idx_param})(a);
                    switch class(cur_value)
                        case 'cell'
                            % is this okay?
                            cur_value = cur_value{1};
                    end
                    
                    st_combinations(a).(obj.c_parameter_names{idx_param}) = cur_value;
                end
                return;
            end
            
            for a = 1 : length(obj.st_parameters.(obj.c_parameter_names{idx_param}))
                temp_result = obj.get_combinations(idx_param + 1);
                
                for b = 1 : length(temp_result)
                    cur_value = obj.st_parameters.(obj.c_parameter_names{idx_param})(a);
                    if iscell(cur_value), cur_value = cur_value{1}; end
                    st_combinations(end+1).(obj.c_parameter_names{idx_param}) = ...
                        cur_value;
                    for c = 1+ idx_param: obj.N_parameters
                        st_combinations(end).((obj.c_parameter_names{c})) = ...
                            temp_result(b).(obj.c_parameter_names{c});
                    end
                end
                
            end
            
            if idx_param == obj.N_parameters
                for a = 1 : length(obj.st_parameters.(obj.c_parameter_names{idx_param}))
                    st_combinations(a).(obj.c_parameter_names{idx_param}) = obj.st_parameters.(obj.c_parameter_names{idx_param})(a);
                end
            end
        end
        
        function write_task_files(obj)
            % makes sure all task files exist
            
            st_combinations = obj.get_combinations();
            
            N_combinations = obj.N_combinations;
            
            if exist(obj.dir_output, 'dir') ~= 7
                warning('output directory created');
                mkdir(obj.dir_output);
            end
            
            for a = 1 : N_combinations
                st_parameters = st_combinations(a);
                
                [b_combination_exists, task_id] = obj.check_param_comb_exists(st_parameters);
                
                if b_combination_exists
                    % this parameter combination has already been stored
                    continue;
                end
                
                % find the next free task_id
                new_task_id = obj.get_next_valid_task_id(task_id);
                
                % save parameters
                save(fullfile(obj.dir_output, sprintf('task_%s_parameters', new_task_id)), 'st_parameters');
                
                % write status
                obj.write_status(obj.dir_output, new_task_id, sprintf('created by: %s on %s', get_user_name(), get_machine_name()));
            end
        end
        
        function create_remote_tasks(obj, b_batch)
            % makes sure all task files exist
            
            if nargin == 1
                b_batch = true;
            end
            
            st_combinations = obj.get_combinations();
            
            N_combinations = obj.N_combinations;
            
            if exist(obj.dir_output, 'dir') ~= 7
                warning('output directory created');
                mkdir(obj.dir_output);
            end
            
            if b_batch
                % just check once for all existing combinations
                % makes sense. i don't know why i started in a different
                % way. i think i thought the scp getting each file individually was faster...
                [vec_b_combination_exists, vec_task_id, vec_st_status_on_server] = obj.check_param_comb_exists(st_combinations);
                
                for a = 1 : N_combinations
                    if vec_b_combination_exists(a)
                        % get the task status
                        temp_status = vec_st_status_on_server(a);
                        fprintf('task %d already exists (%d: %s)\n', a, temp_status.task_id, temp_status.status);
                        continue;
                    end
                    
                    st_parameters = st_combinations(a);
                    
                    new_task_id = obj.get_next_valid_task_id();
                    
                    % create c_parameters cell array
                    user_data = st_parameters;
                    c_parameters = struct2cell(st_parameters);
                    fcn_name = obj.function_name;
                    pre_process_fcn = obj.pre_process_fcn;
                    
                    obj.obj_remote_task.add_task(user_data, pre_process_fcn, fcn_name, c_parameters{:});
                end
            else
                
                
                for a = 1 : N_combinations
                    st_parameters = st_combinations(a);
                    
                    [b_combination_exists, task_id] = obj.check_param_comb_exists(st_parameters);
                    
                    if b_combination_exists
                        % this parameter combination has already been stored
                        continue;
                    end
                    
                    % find the next free task_id
                    new_task_id = obj.get_next_valid_task_id(task_id);
                    
                    % create c_parameters cell array
                    user_data = st_parameters;
                    c_parameters = struct2cell(st_parameters);
                    fcn_name = obj.function_name;
                    pre_process_fcn = obj.pre_process_fcn;
                    
                    obj.obj_remote_task.add_task(user_data, pre_process_fcn, fcn_name, c_parameters{:});
                    
                    % create task file
                    
                    % save parameters
                    %                 save(fullfile(obj.dir_output, sprintf('task_%s_parameters', new_task_id)), 'st_parameters');
                    
                    % write status
                    %obj.write_status(obj.dir_output, new_task_id, sprintf('created by: %s on %s', get_user_name(), get_machine_name()));
                end
            end
        end
        
        function new_task_id = get_next_valid_task_id(obj, task_id)
            % finds the next available task id
            new_task_id = obj.obj_remote_task.get_next_free_task_id();
            %             if nargin == 1 || (nargin==2 && isempty(task_id))
            %                 switch obj.file_name_method
            %                     case 'numbered'
            %                         task_id = sprintf('%05.0f', 0);
            %                     case 'uuid'
            %                         task_id = uuid();
            %                 end
            %             end
            %
            %             new_task_id_numeric = str2num(task_id);
            %
            %             while true
            %                 switch obj.file_name_method
            %                     case 'numbered'
            %                         new_task_id_numeric = new_task_id_numeric + 1;
            %                         new_task_id = sprintf('%05.0f', new_task_id_numeric);
            %                     case 'uuid'
            %                         new_task_id = uuid();
            %                 end
            %
            %                 % check whether the file already exists
            %                 b_already_exists = (exist(fullfile(obj.dir_output, sprintf([obj.file_name_scheme '_status'], new_task_id)), 'file') == 2);
            %
            %                 if ~b_already_exists
            %                     break;
            %                 end
            %             end
        end
        
        
        function [vec_b_param_comb_found, task_id, st_status_on_server] = check_param_comb_exists(obj, st_parameters)
            
            st_status_on_server = [];
            
            % scan all status files whether the desired parameter
            % combination already exists
            [~, ~, st_tasks] = obj.obj_remote_task.get_task_list();
            N_tasks = length(st_tasks);
            
%             vec_idx_on_server = -1 * ones(length(st_parameters), 1);
            
            vec_b_param_comb_found = false(length(st_parameters), 1);
            task_id = [];
            
            if N_tasks == 0
                return;
            end
            
            % download all task files
            for a = 1 : N_tasks
                c_file_names{a} = [sprintf(obj.obj_remote_task.filename_scheme, st_tasks(a).task_id) '.mat'];
            end
                
            N_files_per_run = 100;
            N_runs = floor(N_tasks / N_files_per_run);
            N_remaining_files = N_tasks - N_files_per_run * N_runs;
            
            for cur_run = 1 : N_runs
                obj.obj_remote_task.obj_ssh = scp_get(obj.obj_remote_task.obj_ssh, c_file_names((cur_run-1)*N_files_per_run+1:cur_run*N_files_per_run), obj.obj_remote_task.temp_dir, obj.obj_remote_task.st_server_info.task_path);
            end
            
            % deal with the remaining files
            obj.obj_remote_task.obj_ssh = scp_get(obj.obj_remote_task.obj_ssh, c_file_names(N_runs*N_files_per_run+1:N_tasks), obj.obj_remote_task.temp_dir, obj.obj_remote_task.st_server_info.task_path);
            
            % reset the st_status_on_server struct
            for a = 1 : length(st_parameters)
                st_status_on_server(a).task_id = -1;
                st_status_on_server(a).status = 'new';
                    st_status_on_server(a).comment = '';
            end
            
            for a = 1 : N_tasks
                st_file_contents = load(fullfile(obj.obj_remote_task.temp_dir, c_file_names{a}));
                for b = 1 : length(st_parameters)
                    b_parameters_equal = compareCells(st_file_contents.c_parameters, struct2cell(st_parameters(b)));
                    vec_b_param_comb_found(b) = vec_b_param_comb_found(b) | b_parameters_equal;
%                     st_status_on_server(b).task_id = -1;
                    
                    if b_parameters_equal %vec_b_param_comb_found(b)
                        vec_task_id = st_tasks(a).task_id;
                        st_status_on_server(b) = st_tasks(a);
                        continue;
                    end
                end
            end
            
            
            
            
            %             for a = 1 : N_tasks
            %                 % download everything
            %
            %                 obj.obj_remote_task.obj_ssh = scp_get(obj.obj_remote_task.obj_ssh, [sprintf(obj.obj_remote_task.filename_scheme, st_tasks(a).task_id) '.mat'], obj.obj_remote_task.temp_dir, obj.obj_remote_task.st_server_info.task_path);
            %                 % filename_temp  = tempname;
            %
            %
            %                 st_file_contents = load(fullfile(obj.obj_remote_task.temp_dir, [sprintf(obj.obj_remote_task.filename_scheme, st_tasks(a).task_id) '.mat']));
            %                 %
            %                 %             st_status_files = findFile('\w*_(status)$', obj.dir_output, false, 1);
            %                 %             N_status_files = length(st_status_files);
            %
            %
            %
            %                 %             for a = 1 : N_status_files
            %                 %                 cur_task_id = regexp(st_status_files(a).name, '(?<=_)\w*(?=_status)', 'match');
            %                 %                 cur_task_id = cur_task_id{1};
            %                 %                 st_file_contents = load(fullfile(st_status_files(a).path, sprintf('task_%s_parameters', cur_task_id)));
            %
            %
            %                 b_parameters_equal = compareCells(st_file_contents.c_parameters, struct2cell(st_parameters));
            %                 %                 b_structs_equal = compareStructs(st_parameters, st_file_contents.st_parameters);
            %
            %                 b_param_comb_found = b_param_comb_found | b_parameters_equal;
            %
            %                 if b_param_comb_found
            %                     % obtain task id
            %                     task_id = st_tasks(a).task_id;
            %                     return;
            %                 end
            %             end
        end
        
        function write_status(obj, dir_output, task_id, string)
            % writes entries into the status file
            
            fid = fopen(fullfile(dir_output, sprintf([obj.file_name_scheme '_status'], task_id)), 'a');
            fprintf(fid, '[%s] %s\n', datestr(now), string);
            fclose(fid);
        end
        
        function process_tasks(obj, dir_tasks)
            % all tasks so far
            
            % find all task status files
            st_task_status_files = findFile('\w*(status)$', dir_tasks, false, 1);
            
            N_task_files = length(st_task_status_files);
            
            for a = 1 : N_task_files
                cur_task_status_file = st_task_status_files(a);
                
                % check whether this combination may be processed
                % -> is not currently being processed
                % -> not already finished
                b_okay_to_process = check_task_validity(fullfile(cur_task_status_file.path, cur_task_status_file.name));
                
                if b_okay_to_process
                    % obtain task number
                    % (does the following line work for both numbering
                    % methods??)
                    task_id = regexp(cur_task_status_file.name, '(?<=_)\w*(?=_status)', 'match')
                    task_id = task_id{1};
                    
                    % write_status
                    obj.write_status(obj.dir_output, task_id, ...
                        sprintf('started processing on %s', get_machine_name()));
                    
                    % load the parameters
                    st_parameters = load(fullfile(dir_tasks, sprintf([obj.file_name_scheme '_parameters'], task_id)));
                    st_parameters = st_parameters.st_parameters;
                    
                    %                     c_parameter_names = fieldnames(st_parameters);
                    %                     N_parameters = length(c_parameter_names);
                    %
                    %                     % create a temporary parameter cell
                    %                     for a = 1 : N_parameters
                    %                         cur_value = st_parameters.(c_parameter_names{a});
                    %                         if iscell(cur_value)
                    %                             c_temp_parameters{a} = cur_value{1};
                    %                         else
                    %                             c_temp_parameters{a} = cur_value;
                    %                         end
                    %                     end
                    
                    % some preliminary steps...
                    N_return_values = nargout(obj.function_name);
                    %                     output=cell(N_return_values, 1);
                    clear('output');
                    
                    % start processing
                    if N_return_values > 0
                        try
                            %                             output{1:N_return_values} = feval(obj.function_name, c_temp_parameters{:});
                            [output{1:N_return_values}] = feval(obj.function_name, st_parameters, obj.c_local_parameter_names);
                        catch
                            obj.write_status(obj.dir_output, task_id, sprintf('error!'));
                        end
                        save(fullfile(obj.dir_output, sprintf([obj.file_name_scheme '_result'], task_id)), 'output');
                        obj.write_status(obj.dir_output, task_id, sprintf('finished'));
                    else
                        try
                            feval(obj.function_name, c_temp_parameters{:});
                        catch
                            % bla
                        end
                        obj.write_status(obj.dir_output, task_id, sprintf('finished'));
                    end
                end
            end
        end
        
        
    end
end

function b_okay_to_process = check_task_validity(filename)
% check whether it's okay to process this combination
fid = fopen(filename, 'r');

b_okay_to_process = true;

while ~feof(fid)
    cur_line = fgetl(fid);
end

fclose(fid);

temp = regexp(cur_line, '\w* (finished)$', 'match');
b_done_found = ~isempty(temp);

temp = regexp(cur_line, '\w*(started processing)\w*', 'match');
b_started_processing_found = ~isempty(temp);

b_okay_to_process = ~b_done_found && ~b_started_processing_found;
end

% param_1 param_2 param_3
% -----------------------
%       1       1       1
%       1       1       2
%       1       2       1
%       1       2       2
%       2       1       1
%               .
%               .
%               .^