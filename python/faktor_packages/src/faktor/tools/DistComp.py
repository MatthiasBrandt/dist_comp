import mysql.connector
import paramiko, base64
import scp
import os
import posixpath
import subprocess
import threading
import socket
import time

import pdb

class DistComp:
    """A first attempt to job processing on different computers..."""

    def __init__(self, local_directory):
        # mysql database connection properties
        self.mysql_config = {
            'user': 'dist_comp',
            'password': 'mastering',
            'host': '192.168.1.2',
            'database': 'dist_comp',
            }

        self.ssh_config = {
            'rsa_key': 'AAAAB3NzaC1yc2EAAAABIwAAAQEA2o7igZxvT+64jcjXwcfwINeY2zzZhHxtTbY03mUvicnmCeoc12wg2lLhuTvp1Bcy/ILOJWBD18IZwZBulIsYWJlNM8tQ/ZN0XjvKtqANmczaQ9zi1VhQHnU2FhA9FBfV4MGhy2cSejvqNZFZanNf4i2ASwiygAGqOiFxG4W47r9++l4OBsmnDP0gRaF09SY01jew3IW2kqeE382nOZ++qPR3ai/xVlqMYU+1gNU2+CMFGUD2ws7UJZj+R8NZ66TWdgP/kqgDECb4MydW9lCqSmwGwuIoMB36qSuBBxISEdQJM6xXMRXqBkNHi2ZzliRZq+5uaR1PlZLkKFia9Rf5vQ== admin@APPLESERVER',
            'host': '192.168.1.2',
            'user': 'admin', 
            'password': '16PSsba1!',
            }

        self.local_directory = local_directory

        print("local directory is set to {0}".format(self.local_directory))

        # some initial values
        self.ssh_conn = {}
        self.scp_conn = {}
        self.project = {}
        self.settings = {}

        self.project['local_common_directory'] = os.path.join(self.local_directory, "common")

        self.settings['number_of_threads'] = 10;
        


    def connect(self):
        """Connect to the mysql database and via ssh
        """

        # first mysql
        try:
            self.cnx = mysql.connector.connect(**self.mysql_config)
            print("Sucess.")

        except mysql.connector.Error as err:
            if err.errno == errorcode.ER_ACCESS_DENIED_ERROR:
                print("Something is wrong your username or password.")
            elif err.errno == errorcode.ER_BAD_DB_ERROR:
                print("Database does not exist.")
            else:
                print(err)
        else:
            self.cursor=self.cnx.cursor()
            
            #query = ("SELECT * FROM data_files")
            
            #self.cursor.execute(query)

            #for filename in self.cursor:
            #    print("{}".format(filename))

        # then ssh
        try:
            self.ssh_conn['key'] = paramiko.RSAKey(data=base64.decodestring(self.ssh_config['rsa_key']))
            self.ssh_conn['conn'] = paramiko.SSHClient()
            self.ssh_conn['conn'].get_host_keys().add(self.ssh_config['host'], 'ssh-rsa', self.ssh_conn['key'])
            self.ssh_conn['conn'].connect(self.ssh_config['host'], username=self.ssh_config['user'], password=self.ssh_config['password'])

        except:
            print('error2')

        # finally: scp
        try:
            self.scp_conn['conn'] = scp.SCPClient(self.ssh_conn['conn'].get_transport())
        except:
            print('error3')

    
                                                

    def disconnect(self):
        """ close the mysql connection
        """

        try:
            self.cursor.close()
            self.cnx.close()
        except mysql.connector.Error as err:
            print(err)

        print("successfully closed.")

    def list_projects(self):
        """List the projects that are on the server
        """
        
        query = ("SELECT * FROM projects")

        self.cursor.execute(query)

        for (index, name, directory) in self.cursor:
            print("{0}: {1} ({2})".format(index, name, directory))

    def select_project(self, project_index):
        """ select the project with the given index
        """
        
        self.project_index = project_index

        self.local_project_directory = os.path.join(self.local_directory.replace("\\", "\\"), str(self.project_index))

        # obtain the remote project directory for the selected project
        query = ("SELECT server_directory FROM projects WHERE projects.index = %s")
        self.cursor.execute(query, (self.project_index,))
        self.project['remote_directory'] = self.cursor.fetchone()[0]

        # obtain the remote data directory for the selected project
        #query = ("SELECT data_directory FROM projects WHERE projects.index = %s")
        #self.cursor.execute(query, (self.project_index,))
        

        # obtain the remote code  directory for the selected project
        #query = ("SELECT code_directory FROM projects WHERE projects.index = %s")
        #self.cursor.execute(query, (self.project_index,))
        #self.project['remote_code_directory'] = self.cursor.fetchone()[0]

        # obtain the server root directory for all distributed computing jobs
        query = ("SELECT root_directory FROM settings")
        self.cursor.execute(query)
        self.settings['server_root_directory'] = self.cursor.fetchone()[0]

        self.settings['remote_common_directory'] = self.settings['server_root_directory'] + "/common"#self.cursor.fetchone()[0]

        # obtain the name of the selected project
        # -> code directory
        query = ("SELECT name FROM projects WHERE projects.index = %s")
        self.cursor.execute(query, (self.project_index,))
        self.project['name'] = self.cursor.fetchone()[0]
        self.project['remote_code_directory'] = posixpath.join(self.settings['server_root_directory'], str(self.project_index), 'code')

        self.project['local_code_directory'] = os.path.join(self.local_directory, str(self.project_index), "code")


    def list_tasks(self):
        """ lists the tasks of the selected project
        """

        # not done yet...

        query = ("SELECT DISTINCT tasks.name, tasks.index FROM tasks LEFT JOIN parameter_values ON tasks.index = parameter_values.task WHERE parameter_values.project = %s")
        self.cursor.execute(query, (self.project_index,))

        for (name, index) in self.cursor:
            print("task #{0}: {1}".format(index, name))
            #print(index[0])

    def process(self):
        """ process all tasks of the current project
        """

        l_threads = [None] * self.settings['number_of_threads']

        while True:
            
            print("looking for unprocessed tasks...")

            # first obtain the tasks that are part of this project
            query = ("SELECT DISTINCT tasks.name, tasks.index, tasks.function_name FROM tasks LEFT JOIN parameter_values ON tasks.index = parameter_values.task WHERE parameter_values.project = %s && tasks.status=1")
            self.cursor.execute(query, (self.project_index,))

            all_tasks = self.cursor.fetchall()

            # just for debugging: list the parameters
            for (name, index, function_name) in all_tasks:
                print("start processing task #{0} - {1}".format(index, name))
                # print("task #{0} ({1}) has the following parameters".format(index, name))

                # obtain the parameters and values for the current task
                query = ("SELECT parameter, value FROM parameter_values WHERE parameter_values.task = %s")
                #query = ("SELECT parameters.name FROM parameters LEFT JOIN parameter_values ON parameters.index = parameter_values.parameter WHERE parameter_values.task = %s")
                self.cursor.execute(query, (index,))

                all_parameters_and_values = self.cursor.fetchall()

                # print(all_parameters_and_values)

                # pdb.set_trace()

                # create the parameter-struct-creating matlab command
                param_struct_command = ""
                for (parameter, value) in all_parameters_and_values:
                    # fetch the parameter name from the database
                    query = ("SELECT name FROM `parameters` WHERE parameters.index = %s")
                    self.cursor.execute(query, (parameter,))
                    parameter_name = self.cursor.fetchone()

                    #print(parameter_name)

                    # fetch the parameter value from the database
                    query = ("SELECT value FROM `values` WHERE values.index = %s")
                    self.cursor.execute(query, (value,))
                    parameter_value = self.cursor.fetchone()

                    #print("parameter: {0} = {1}".format(parameter_name[0], parameter_value[0]))

                    param_struct_command = param_struct_command + \
                        "st_parameters.{0} = {1};".format(parameter_name[0], parameter_value[0])

                #print(param_struct_command)

                # create the settings-struct-creating matlab command
                # - first, obtain the local settings for this machine
                query = ("SELECT host_address FROM `clients` WHERE name = %s")
                self.cursor.execute(query, (socket.gethostname(),))
                host_address = self.cursor.fetchone()[0]

                # obtain information about required "code" directories
                query = ("SELECT `code_files`.path FROM `code_files` LEFT JOIN `project_code_files` ON `code_files`.index = `project_code_files`.file WHERE `project_code_files`.project = %s")
                self.cursor.execute(query, (self.project_index,))
                code_directories = self.cursor.fetchall()

                #pdb.set_trace()

                settings_struct_command = "st_settings.mysql.host = '" + host_address + "';"
                settings_struct_command = settings_struct_command \
                    + "st_settings.mysql.{0} = '{1}';".format("database", self.mysql_config['database']) \
                    + "st_settings.mysql.{0} = '{1}';".format("user", self.mysql_config['user']) \
                    + "st_settings.mysql.{0} = '{1}';".format("password", self.mysql_config['password']) \
                    + "st_settings.dir_common = '{0}';".format(self.project['local_common_directory']) \
                    + "st_settings.dir_code = '{0}';".format(self.project['local_code_directory']) \
                    + "st_settings.task_index = {0};".format(index) \
                    + "st_settings.path = '{0}';".format(";".join([x[0] for x in code_directories]))

                matlab_start_command = ["matlab", "-automation", "-wait", "-r", "\"{0}; {1}; {2}; addpath(fullfile(st_settings.dir_common)); prepare; st_result={3}(st_parameters); {4}; exit;\"".format(param_struct_command, settings_struct_command, "cd(st_settings.dir_code)", function_name, "save_results")]

                #server_start_command = "start \"server {0}\" /min cmd /c \"matlab -automation -r \"{1}\"".format(1, matlab_start_command)
                #server_start_command = "start \"server bla\" /min cmd"

                # print(matlab_start_command)


               
                task_processed = False
                while True:

                    for thread_index in range(self.settings['number_of_threads']):


                        if l_threads[thread_index] is None or l_threads[thread_index].status ==  3: #l_threads[thread_index].is_alive():
                            if l_threads[thread_index] is None:
                                # create new worker process
                                l_threads[thread_index] = TaskProcess(matlab_start_command)
                            elif l_threads[thread_index].status == 3:
                                # status must be ==3...
                                #l_threads[thread_index].init(matlab_start_command)
                                l_threads[thread_index] = TaskProcess(matlab_start_command)

                            l_threads[thread_index].start()

                            #print("{0}: {1}".format(thread_index, l_threads[thread_index].status))
                            #print(l_threads[1].status)

                            # update the status of the current tasl
                            query = ("UPDATE tasks SET status=2 WHERE tasks.index = %s")
                            self.cursor.execute(query, (index,))
                            #print("new")
                            task_processed = True
                        if task_processed:
                            break
                    
                    if task_processed:
                            #print("done")
                        break
                    else:
                        print("waiting for free thread")
                        time.sleep(5)
                        #print(l_threads)
                            #print(l_threads[0].status)

#                    if task_processed:
#                        break


            time.sleep(5)

                #stream = os.popen("cmd.exe")



                #pdb.set_trace()


    def init_project(self):
        """ set everything up for the project that has been selected
        """

        # check whether the local directory for this project already exists
        if not os.path.exists(self.local_project_directory):
            os.makedirs(self.local_project_directory)
            print("local project directory created.")

        # check whether the local data directory already exists
        if not os.path.exists(self.project['local_common_directory']):
            os.makedirs(self.project['local_common_directory'])
            print("local data directory created.")

        # check whether the local data directory already exists
        if not os.path.exists(self.project['local_code_directory']):
            os.makedirs(self.project['local_code_directory'])
            print("local code directory created.")

        # obtain the required common files: # data files
        #query = ('select filename from common_files left join project_data_files on data_files.index = project_data_files.file where project_data_files.project = %s')
        query = ('SELECT path, type FROM common_files')
        self.cursor.execute(query)

        for (path,common_type) in self.cursor:
            print(path)
            if common_type == 1: # this is a file
                if False and os.path.exists(os.path.join(self.project['local_common_directory'], path)):
                    # switched off to alwas have the current versions...
                    print("file ""{0}"" already exists in the common directory".format(path))
                else:
                    print('fetching "{0}" from the server...'.format(path)),
                    try:
                        self.scp_conn['conn'].get(self.settings['remote_common_directory']+"/"+path, self.project['local_common_directory'])
                    except scp.SCPException as err:
                #pdb.set_trace()
                        print(err)
                    print("done.")
            else:
                # this path points to a directory
                print("fetching the {0} directory...".format(path)),
                # -> get all subdirectories and files...
                stdin, stdout, stderr = self.ssh_conn['conn'].exec_command("pushd {0}/{1} 1>&2 ; /opt/bin/find . -type f ; popd 1>&2".format(self.settings['remote_common_directory'], path))
                #pdb.set_trace()
                for line in stdout:
                    # split the filename string to obtain the relative path (without the filename)
                    relative_path =  os.path.join(path, *line.split("/")[1:-1])
                    
                    filename =  os.path.join(line.split("/"))[-1].strip()
                    full_path = os.path.join(self.project['local_common_directory'], relative_path).replace("\\\\", "\\")
                    if not os.path.exists(full_path):
                        os.makedirs(full_path)

                        
                    self.scp_conn['conn'].get(posixpath.join(self.settings['remote_common_directory'],relative_path.replace("\\", "/"), filename), os.path.join(self.project['local_common_directory'], relative_path))
                print("done")
                    

        # take care of the "code" files
        query = ('select path, type from code_files left join project_code_files on code_files.index = project_code_files.file where project_code_files.project = %s')
        self.cursor.execute(query, (self.project_index,))
            
        for (path,common_type) in self.cursor:
            #print(filename)
            if common_type == 1: # this is a file
                if False and os.path.exists(os.path.join(self.project['local_code_directory'], path)):
                    # switched off... (see above)
                    print("file ""{0}"" already exists in the code directory".format(path))
                else:
                    print('fetching "{0}" from the server...'.format(path)),
                    try:
                        self.scp_conn['conn'].get(self.project['remote_code_directory']+"/"+path, self.project['local_code_directory'])
                    except scp.SCPException as err:
                #pdb.set_trace()
                        print(err)
            else:
                # this is a directory
                print("fetching the {0} directory...".format(path)),
                # -> get all subdirectories and files...
                #pdb.set_trace()
                stdin, stdout, stderr = self.ssh_conn['conn'].exec_command("pushd {0}/{1} 1>&2 ; /opt/bin/find . -type f ; popd 1>&2".format(self.project['remote_code_directory'], path))
                #pdb.set_trace()
                for line in stdout:
                    # split the filename string to obtain the relative path (without the filename)
                    relative_path =  os.path.join(path, *line.split("/")[1:-1])
                    
                    filename =  os.path.join(line.split("/"))[-1].strip()
                    full_path = os.path.join(self.project['local_code_directory'], relative_path).replace("\\\\", "\\")
                    if not os.path.exists(full_path):
                        os.makedirs(full_path)

                    #pdb.set_trace()
                    self.scp_conn['conn'].get(posixpath.join(self.project['remote_code_directory'],relative_path.replace("\\", "/"), filename), os.path.join(self.project['local_code_directory'], relative_path))
                print("done")
                # -> download recursively
                
               

        #print("fetching current version of \"save_results.m\"..."),
        #self.scp_conn['conn'].get(self.project['remote_code_directory']+"/"+"save_results.m", self.project['local_code_directory'])
        #print("done.")

        #print("fetching current version of java mysql class..."),
        #self.scp_conn['conn'].get(self.project['remote_data_directory']+"/"+"mysql-connector-java-5.1.6-bin.jar", self.project['local_data_directory'])
        #print("done.")


                

       
    #def get_project_files(self):
    #    """ get the list of files required for this project
    #    """
    #    
    #    query = ('select filename from files left join project_files on files.index = project_files.file where project_files.project =# %s')##

#        self.cursor.execute(query, (self.project_index,))

        #pdb.set_trace()

#        for filename in self.cursor:
 #           print('{0}'.format(filename))

        

        


class TaskProcess(threading.Thread):
    """
    """
    
    def __init__(self, command):
        """
        """
        threading.Thread.__init__(self)
        # self.dist_comp_object = dist_comp_object
        self.command = command
        self.status = 1

    def run(self):
        """
        """
        #print("start")
        #print(self.command)
        self.status = 2
        #pdb.set_trace()
        p = subprocess.call(self.command)
        #p.wait()
        #print("done")
        #print(p)
        self.status = 3
        #pdb.set_trace()

    def init(self, command):
        """ set a new command and reset status
        """
        
        self.command = command
        self.status = 1

            

        
        
        

                

