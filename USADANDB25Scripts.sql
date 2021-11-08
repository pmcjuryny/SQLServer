BEGIN/*Show captured sessions where end users are using service accounts to generate ad-hoc connections*/
SELECT TOP (1000) [USERNAME]
      ,[OSUSER]
      ,[MACHINE]
      ,[PROGRAM]
      ,[LOGON_TIME]
      ,[import_date]
      ,[DBNAME]
  FROM [ORACLE_DATA].[dbo].[ServiceAccountLogons]
  where username<>osuser
  order by username
END

BEGIN/*Show captured sessions where end users are using service accounts to generate ad-hoc connections joined with powerdoc_rep table to show real name as well as username*/
SELECT distinct username, osuser, rn.real_name, machine, program, logon_time, dbname
  FROM [ORACLE_DATA].[dbo].[ServiceAccountLogons] sl 
  full join POWERDOC_REP.dbo.oracle_real_names rn on sl.osuser=rn.user_name
where username<>osuser
END

BEGIN/*query captured Oracle database tablespace information*/ 
select 
  target_name,
  sum(tablespace_size)/1024/1024/1024,
  contents,
  start_timestamp
  from dbo.tablespace_history
  where 	target_name like '%.na.praxair.com' 
			and (target_name not like '%1%' and target_name not like'%2%')
  group by target_name, contents, start_timestamp
  order by target_name, contents, start_timestamp

select target_name, tablespace_size, contents, start_timestamp 
  from dbo.tablespace_history
  where CONVERT(date, start_timestamp)=CONVERT(date, getdate())

select target_name, tablespace_size, contents, start_timestamp
  from dbo.tablespace_history
  where convert(date, start_timestamp)=convert(date, (select min(start_timestamp) from dbo.tablespace_history where start_timestamp like DATEADD(month, -1, getdate())))

select target_name, sum(tablespace_size), contents, start_timestamp
  from dbo.tablespace_history
  where DATEPART(month, CONVERT(date,start_timestamp))=DATEPART(month, CONVERT(date,DATEADD(month, -1, getdate())))
  and DATEPART(year, CONVERT(date,start_timestamp))=DATEPART(year, CONVERT(date,DATEADD(month, -1, getdate())))
  group by target_name, tablespace_size, contents, start_timestamp

select distinct target_name, start_timestamp
  from dbo.tablespace_history
  order by target_name, start_timestamp

select a.target_name,a.contents, b.tspc/1024/1024/1024 as "TBLSPC_TODAY", a.tspc/1024/1024/1024 as "TBLSPC_PRIOR", (b.tspc-a.tspc)/1024/1024/1024 as "TBLSPC_DIFF"
from (  select target_name as "target_name", sum(tablespace_size) as tspC, contents as "Contents", min(start_timestamp) as "time"
  from dbo.tablespace_history
  where DATEPART(month, CONVERT(date,start_timestamp))=DATEPART(month, CONVERT(date,DATEADD(day, -5, getdate())))
  and DATEPART(day, CONVERT(date,start_timestamp))=DATEPART(day, CONVERT(date,DATEADD(day, -5, getdate())))
  and DATEPART(year, CONVERT(date,start_timestamp))=DATEPART(year, CONVERT(date,DATEADD(day, -5, getdate())))
  group by target_name, contents) a
  join (select target_name as "target_name", sum(tablespace_size) as tspC, contents as "Contents", min(start_timestamp) as "time"
  from dbo.tablespace_history
  where DATEPART(month, CONVERT(date,start_timestamp))=DATEPART(month, CONVERT(date,getdate()))
  and DATEPART(day, CONVERT(date,start_timestamp))=DATEPART(day, CONVERT(date,getdate()))
  and DATEPART(year, CONVERT(date,start_timestamp))=DATEPART(year, CONVERT(date,getdate()))
  group by target_name, contents) b on a.target_name=b.target_name and b.contents=a.contents

select a.target_name,a.contents, b.tspc/1024/1024/1024 as "TBLSPC_TODAY", a.tspc/1024/1024/1024 as "TBLSPC_PRIOR", (b.tspc-a.tspc)/1024/1024/1024 as "TBLSPC_DIFF"
from (  select target_name as "target_name", sum(tablespace_size) as tspC, contents as "Contents", min(start_timestamp) as "time"
  from dbo.tablespace_history
  where convert(date, start_timestamp)=convert(date,DATEADD(day,-1,getdate()))
  group by target_name, contents) a
  join (select target_name as "target_name", sum(tablespace_size) as tspC, contents as "Contents", min(start_timestamp) as "time"
  from dbo.tablespace_history
  where convert(date,start_timestamp)=convert(date,getdate())
  group by target_name, contents) b on a.target_name=b.target_name and b.contents=a.contents
  
SELECT     
	df.tablespace_name "Tablespace", 
	totalusedspace "Used MB", 
	(df.totalspace - tu.totalusedspace) "Free MB", 
	df.totalspace "Total MB", 
	round(100 * ((df.totalspace - tu.totalusedspace) / df.totalspace)) "Pct. Free", 
	i.Instance_Name "InstanceName", 
	TO_CHAR(SYSDATE, 'yyyy/mm/dd') "Date"
FROM         (SELECT     tablespace_name, round(SUM(bytes) / 1048576) TotalSpace
                       FROM          dba_data_files
                       GROUP BY tablespace_name) df,
                          (SELECT     round(SUM(bytes) / (1024 * 1024)) totalusedspace, tablespace_name
                            FROM          dba_segments
                            GROUP BY tablespace_name) tu,
                          (SELECT     instance_name
                            FROM          v$instance) I
WHERE     df.tablespace_name = tu.tablespace_name

select DISTINCT 
SUM("Total MB") over(PARTITION BY instanceName) as Total_MB
,SUM("Free MB") over (PARTITION BY instanceName) as Free_MB
,SUM ("Used MB") over (PARTITION BY instanceName) as Used_MB
,InstanceName
,"Sample Date"
from dbo.exadata_space 
union ALL
select 
  SUM("Total MB") as Total_MB
  ,SUM("Free MB") as Free_MB
  ,SUM ("Used MB") as Used_MB
  ,null
  ,null
from dbo.exadata_space

select DISTINCT 
SUM("Total MB") over(PARTITION BY instanceName) as Total_MB
,SUM("Free MB") over (PARTITION BY instanceName) as Free_MB
,SUM ("Used MB") over (PARTITION BY instanceName) as Used_MB
,InstanceName
,"Sample Date"
from dbo.exadata_space
union ALL
select 
  SUM("Total MB") as Total_MB
  ,SUM("Free MB") as Free_MB
  ,SUM ("Used MB") as Used_MB
  ,null
  ,null
from dbo.exadata_space
END

BEGIN/*correct instance names in captured oracle database information, convert node specific SID into service names*/
BEGIN TRAN
update dbo.Exadata_Space
set InstanceName='pxpdsa'
where InstanceName like 'pxpdsa%'

update dbo.Exadata_Space
set InstanceName='pxpdgen'
where InstanceName like 'pxpdgen%'

update dbo.Exadata_Space
set InstanceName='pxpdna'
where InstanceName like 'pxpdna%'

update dbo.Exadata_Space
set InstanceName='pxprod'
where InstanceName like 'pxprod%'

update dbo.Exadata_Space
set InstanceName='pxpdbmr'
where InstanceName like 'pxpdbmr%'

update dbo.Exadata_Space
set InstanceName='pxchdem'
where InstanceName like 'pxchdem%'

update dbo.Exadata_Space
set InstanceName='pxusig'
where InstanceName like 'pxusig%'

update dbo.Exadata_Space
set InstanceName='pxpdobi'
where InstanceName Like 'pxpdobi%'
END

BEGIN/*Litespeed Data Queries Select litespeed version based on primary dba*/
select ia.InstanceName, servername, PrimaryDBA, version 
from InstanceAssignments as ia
inner join Litespeed as ls
on ia.InstanceName=ls.InstanceName
where PrimaryDBA='McJury, Patrick'
GO
END

BEGIN/*JobHistory and failures queries*/
select * from dbo.JobFailureWatchList
GO

select * from dbo.JobHistory
GO
END

BEGIN/*list all failed jobs for primary and secondary support @hoursback determines how far back into the job history to check*/
--
--
declare @hoursback int;
set @HOURSBACK=24;
select DISTINCT c.FullName, i.InstanceName,i.DBVersion, i.DBEdition, jh.jobname, jh.StartDate from instance as i
join Contact as c
on i.PrimaryDBA = c.ID
join JobHistory as jh
on i.InstanceName=jh.InstanceName
where c.FullName ='McJury, Patrick' and StartDate>= dateadd(hh,-@HOURSBACK, getdate()) and RunStatus=0 
union
select c.FullName, i.InstanceName,i.DBVersion, i.DBEdition, jh.jobname, jh.StartDate from instance as i
join Contact as c
on i.SecondaryDBA = c.ID
join JobHistory as jh
on i.InstanceName=jh.InstanceName
where c.FullName ='McJury, Patrick' and StartDate>= dateadd(hh,-@HOURSBACK, getdate()) and RunStatus=0
order by InstanceName
GO
END

BEGIN /* list all failed jobs based on keyword search @hoursback determines how many hours to go back in the job historyg*/
--
--
declare @hoursback int;
set @HOURSBACK=24;
select DISTINCT c.FullName, i.InstanceName,i.DBVersion, i.DBEdition, jh.jobname, jh.StartDate from instance as i
join Contact as c
on i.PrimaryDBA = c.ID
join JobHistory as jh
on i.InstanceName=jh.InstanceName
where c.FullName ='McJury, Patrick'
and StartDate>= dateadd(hh,-@HOURSBACK, getdate()) and RunStatus=0 
and jh.jobname LIKE '%backup%'
order by jh.jobname
GO
END

BEGIN/*Query job history from dbainventory*/
select DISTINCT c.FullName, i.InstanceName,i.DBVersion, i.DBEdition, jh.jobname, jh.StartDate from instance as i
join Contact as c
on i.PrimaryDBA = c.ID
join JobHistory as jh
on i.InstanceName=jh.InstanceName
where c.FullName ='McJury, Patrick'
and StartDate like '2015-02-25%' and RunStatus=0 
order by jh.jobname
GO
END

BEGIN/*COPY CURRENT DATA FROM DBAInventory.dbo.Instance*/
select count(*) from dbo.instance_pat
insert into dbo.Instance_pat
select *,SYSDATETIME()
from usatondb25.dbainventory.dbo.instance as ri
where ri.primarydba = 249
END

BEGIN/*DASHBOARD SQL to Check for NEW Instance Assignments*/
select 
	instanceName
	,ServerName
	,DBVersion
	,Port
	,DateDetected
	,date_of_check
from dbo.instance_pat_current

except 

select 
	instanceName
	,ServerName
	,DBVersion
	,Port
	,DateDetected
	,date_of_check
from dbo.instance_pat_old

select count(*) from dbo.instance_pat_current
select count(*) from dbo.instance_pat_old
END

BEGIN/*DAILY Proccessing to Update/Move Data*/
insert into dbo.instance_pat_archive
select * from dbo.instance_pat_old

truncate table dbo.instance_pat_old

insert into dbo.instance_pat_old
select * from dbo.instance_pat_current

truncate table dbo.instance_pat_current

insert into dbo.Instance_pat_current
select *,SYSDATETIME()
from usatondb25.dbainventory.dbo.instance as ri
where ri.primarydba = 249
END
	
BEGIN/*Show servers/drives with less than 10% free SPACE*/
  SELECT ds.ServerName
      ,[Date]
      ,[DiskName]
      ,[Size]
      ,[FreeSpace]
      ,[VolumeName]
	  ,100*(cast(freespace as decimal)/cast(size as decimal)) as PercentFree
  FROM [DBAInventory].[dbo].[DiskSpace] as DS
  join dbo.Instance as I on I.ServerName = DS.ServerName
  where 
  ds.Date > dateadd(dd,-1,getdate())
  and 100*(cast(freespace as decimal)/cast(size as decimal)) < 10
  and i.PrimaryDBA=249
END

BEGIN/*show instances in instance_pat_current that are not in instance_pat_old*/
select 
		instanceName
		,ServerName
		,DBVersion
		,Port
		,DateDetected
	from dbo.instance_pat_current
except 
select 
		instanceName
		,ServerName
		,DBVersion
		,Port
		,DateDetected
	from dbo.instance_pat_old
END	
	
BEGIN	/*Show list of CMS groups*/
SELECT TOP (1000) [server_group_id]
      ,[name]
      ,[description]
      ,[server_type]
      ,[parent_id]
      ,[is_system_object]
  FROM [msdb].[dbo].[sysmanagement_shared_server_groups_internal]
END

BEGIN/*generate insert statements find instances from dba inventory, put instances in server groups broken down by version*/
select 'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (8,'''+instancename+''','''+instancename+''','' '',0)'
from dbo.Instance
where DBVersion like '9.%'
and RDBMSTypeCD='SQL'
and RemovedFromServiceDate is null
union all
select 'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (9,'''+instancename+''','''+instancename+''','' '',0)'
from dbo.Instance
where (DBVersion like '10%' and DBVersion not like '10.50%')
and RDBMSTypeCD='SQL'
and RemovedFromServiceDate is null
union all
select 'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (10,'''+instancename+''','''+instancename+''','' '',0)'
from dbo.Instance
where DBVersion like '10.50%'
and RDBMSTypeCD='SQL'
and RemovedFromServiceDate is null
union all
select 'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (11,'''+instancename+''','''+instancename+''','' '',0)'
from dbo.Instance
where DBVersion like '11%'
and RDBMSTypeCD='SQL'
and RemovedFromServiceDate is null
END


BEGIN/*generate insert statements find instances from dba inventory, put instances in server groups broken down by Primary DBA*/
  SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (12,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='Boyal, Pinnel'
  union all
  SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (13,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='Shi, Grace'
  union all
  SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (14,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='Devereaux, Joseph'
  union all  
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (15,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='Gavish, Edan'
END 

BEGIN/* generate insert statements find instances from dba inventory, put instances in server groups broken down by version and Primary DBA*/  

  SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (25,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '9.%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (26,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '10.0%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (27,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '10.50%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (28,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '11.%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (29,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '12.%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (30,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '13.%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (33,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '14.%'
  union all
    SELECT 
	  'INSERT INTO msdb.dbo.sysmanagement_shared_registered_servers_internal (server_group_id, name, server_name,description,server_type) VALUES (32,'''+instancename+''','''+instancename+''','' '',0)'
  FROM [DBAInventory].[dbo].[Instance] i
  join dbo.Contact c on i.PrimaryDBA=c.ID
  where i.RemovedFromServiceDate is null
  and c.FullName='McJury, Patrick'
  and i.dbversion like '15.%'
END 
  
 
BEGIN/*Extract usernames and passwords from DBAInventory*/
SELECT 'SQL Server' 
	  ,i.RDBMSTypeCD
      ,p.[InstanceName]
      ,p.[UserID]
	  ,UPPER(p.[userid])
      ,dba.decrypt([Password]) 'Password'
      ,p.[Comments]
  FROM [DBAInventory].[dbo].[Password] p
  join dbo.Instance i
	on i.InstanceName=p.InstanceName
  where (userid='sa' or userid like '%sql%' or userid='pxdba')
   and i.RemovedFromServiceDate is null
   and i.RDBMSTypeCD='SQL'
   and userid<>'praxair-usa\sqlsvr_pddsv05'
   order by RDBMSTypeCD, InstanceName,userid
   END   
   
