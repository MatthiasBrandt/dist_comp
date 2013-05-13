from faktor.tools import DistComp as dc

dc = reload(dc)

obj = dc.DistComp("c:\\remote_task_dir")

obj.connect()

obj.select_project(2)

#obj.list_tasks()

obj.init_project()

obj.process()

