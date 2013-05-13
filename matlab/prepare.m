function prepare()

st_settings = evalin('base', 'st_settings');

% VERSION INFORMATION______________________________________________________
%
% $Date: 2010-09-14 16:18:57 +0200 (Di, 14 Sep 2010) $
% $Author: karl $
% $Revision: 193 $
% $URL: svn://applesoup.kicks-ass.org/share/svn/matlab/tools/setup_tools.m $
% _________________________________________________________________________

dirsToAdd = getAllSubdirs(st_settings.dir_code, 'nosvn', false);
N_dirs = length(dirsToAdd);
for a = 1 : N_dirs
    addpath(dirsToAdd{a});
end

dirsToAdd = getAllSubdirs(st_settings.dir_common, 'nosvn', false);
N_dirs = length(dirsToAdd);
for a = 1 : N_dirs
    addpath(dirsToAdd{a});
end

% addpath(st_settings.path);
addpath(st_settings.dir_code);
addpath(st_settings.dir_common);

javaaddpath(fullfile(st_settings.dir_common, 'mysql-connector-java-5.1.6-bin.jar'))

%javaaddpath(fullfile(st_settings.dir_data, 'mysql-connector-java-5.1.6-bin.jar'));

% import edu.stanford.covert.db.MySQLDatabase;

% disp('soweit gut')

% st_result = evalin('base', 'st_result');
% task_index = evalin('base', 'task_index');

% filename_temp = [tempname() '.mat'];

% write data to a tempfile
% save(filename_temp, 'st_result');

% create the database connection
% db = MySQLDatabase(st_settings.mysql.host, ...
%     st_settings.mysql.database, ...
%     st_settings.mysql.user, ...
%     st_settings.mysql.password);

% db.prepareStatement('INSERT INTO results (value) VALUES("{F}")', filename_temp);
% db.query();

% obtain the index of the new value in the results table
% db.prepareStatement('SELECT LAST_INSERT_ID()');
% value_index = db.query();
% value_index=value_index.LAST_INSERT_ID__;

% value_index

% db.prepareStatement('UPDATE tasks SET result = "{Sn}", status=3 WHERE tasks.index = "{Sn}"', value_index, st_settings.task_index);
% db.query();

end

% VERSION INFORMATION______________________________________________________
%
% $Date: 2010-09-14 16:18:57 +0200 (Di, 14 Sep 2010) $
% $Author: karl $
% $Revision: 193 $
% _________________________________________________________________________

function cDirs = getAllSubdirs(startPath, mode, b_relative_paths, max_recursion_depth)

% file history_____________________________________________
% o 19.02.08 - first version:
%              -> only recursive mode working
% o 26.05.10 - added 'nosvn' option
% _________________________________________________________

if ( nargin < 4 )
    max_recursion_depth = inf;
end
if ( nargin < 3 )
    b_relative_paths = false;
end
if ( nargin < 2 )
    mode = 'all';
end
if ( nargin < 1 )
    %startPath = cd;
    startPath = '.';
    % elseif nargin == 1
    %     mode = 'all';
elseif (nargin > 4)
    error('too many arguments');
end

cDirs = scanDir(startPath, mode, b_relative_paths, max_recursion_depth);

return;

% scanning for a certain directory name not implemented yet...
% hitIndices = [];
% for i = 1 : length(stFiles)
%     tStartIndex = regexp(stFiles(i).name, fileName);
%     if (~isempty(tStartIndex))
%         hitIndices(end+1) = i;
%     end
% end
% %nHitIndices = cell2mat(regexp({stFiles.name}, fileName));
% %stRDirs = stDirs(hitIndices);
end
% subfunctions_____________________________________________
function cRDirs = scanDir(dirName, mode, b_relative_paths, max_recursion_depth)

stRDirs = []; %struct('name', '', 'path', '');
cRDirs = {};

stTDirs = dir(dirName);

% get rid of the '.' and '..' directories
temp_vec_b_valid_dir = true(length(stTDirs), 1);
for a = 1 : length(stTDirs)
    if any(strcmp(stTDirs(a).name, {'.', '..'}))
        temp_vec_b_valid_dir(a) = false;
    end
end
% stTDirs = stTDirs(3:end);
stTDirs = stTDirs(temp_vec_b_valid_dir);

dirIndices = find([stTDirs.isdir]);
nDirs = length(dirIndices);

max_recursion_depth = max_recursion_depth - 1;

if (nDirs == 0)
    return;
end

if max_recursion_depth >= 0
    for d = 1 : nDirs
        subSubDir = stTDirs(dirIndices(d)).name;
        if strcmp(mode, 'nosvn') && strcmp(subSubDir, '.svn')
            continue;
        end
        if ~b_relative_paths
            cRDirs = [cRDirs; {fullfile(dirName, subSubDir)}];
        else
            cRDirs = [cRDirs; {subSubDir}];
        end
        tDirs = scanDir(fullfile(dirName, subSubDir), mode, b_relative_paths, max_recursion_depth);
        if (~isempty(tDirs))
            cRDirs = [cRDirs; tDirs];
        end
    end
end

end