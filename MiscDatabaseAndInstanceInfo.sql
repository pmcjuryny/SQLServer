BEGIN /* show active database sessions count by username, databasename, hostname and program name */
select 
	DB_NAME(database_id) as 'DatabaseName'
	,count(*) as 'NumberofConnections'
	,host_name
	,program_name
	,login_name 
from sys.dm_exec_sessions
where login_name<>'sa' and db_name(database_id) not in ('master','msdb','tempdb')
group by host_name, program_name, login_name, database_id
END


BEGIN /*Check the recovery model of a database, msdb used for SAMPLE*/
SELECT name AS [Database Name],
recovery_model_desc AS [Recovery Model]
FROM sys.databases
where name ='msdb'
END


BEGIN /*change recovery model to full for database, msdb used for sample*/
ALTER DATABASE msdb SET RECOVERY FULL 
END


BEGIN/* show databases files current size and size used 
      REPLACE <DB_NAME> with actual Database Name*/ 
use <DB_NAME>
go
SELECT 
 [type_desc], name AS FileName, 
size/128.0 AS CurrentSizeMB, 
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB, 
CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS UsedSpaceMB 
FROM <DB_NAME>.sys.database_files
END


BEGIN /* show triggers in database */
select * from sysobjects where type='TR'
END


BEGIN /* show triggers, trigger owner, table trigger is on */
select name, USER_NAME(uid) as Owner, OBJECT_NAME(parent_obj) as [Table Name] 
from sysobjects where type='TR'
END


BEGIN /*show user tables filtered by name*/
select name, user_name(uid) as owner
from sysobjects
where type='U' 
and name like '%J$%'
END


BEGIN /* select page life expectancy 
Multiple numa nodes should show as multiple entries */
SELECT [object_name],
[counter_name],
[cntr_value] FROM sys.dm_os_performance_counters
WHERE [object_name] LIKE '%Manager%'
AND [counter_name] = 'Page life expectancy'
END


BEGIN/* Show all Heaps in database 
A heap table is a table without a clusteres index. 
In common, using heap tables isn't best practice, only in some less szenarios a heap is acceptable.
In SQL Azure heap tables are not allowed, every table must have a clustered index. So if you want to migrate you SQL Server database to SQL Azure you have to define a clustered index or modify an existing index for all table, where no CI exists.
With this simple Transact-SQL statement you can query all heap tables.
*/
SELECT SCH.name + '.' + TBL.name AS TableName
FROM sys.tables AS TBL
     INNER JOIN sys.schemas AS SCH
         ON TBL.schema_id = SCH.schema_id
     INNER JOIN sys.indexes AS IDX
         ON TBL.object_id = IDX.object_id
            AND IDX.type = 0 -- = Heap
ORDER BY TableName
END


BEGIN /* show server information */
select @@SERVERNAME, @@SERVICENAME, @@VERSION, @@MICROSOFTVERSION 
END


BEGIN /*Generate scripts to alter the legnth of columns in a TABLE*/
create table #temp1 (sql_statement varchar(300))
DECLARE PROC_CALL CURSOR FOR
select table_schema, table_name, column_name from INFORMATION_SCHEMA.columns
where DATA_TYPE='varchar' and CHARACTER_MAXIMUM_LENGTH=-1 and TABLE_NAME<>'AlertsLast7Days'

OPEN PROC_CALL

DECLARE @schema varchar(50)
DECLARE @table varchar(50)
DECLARE @table2 varchar(100)
DECLARE @column varchar(80)
DECLARE @sql1 varchar(200)
DECLARE @sql2 nvarchar(200)
DECLARE @mlen int 

FETCH NEXT FROM PROC_CALL INTO @schema, @table, @column
WHILE (@@FETCH_STATUS = 0)
BEGIN
   set @table2= (CONCAT('[',@schema,'].[',@table,']'))
   set @sql2=(concat('select @mlen=max(len(',@column,')) from ',@table2))
   exec sp_executesql @sql2,N'@mlen int OUTPUT', @mlen=@mlen OUTPUT
   set @sql1=Concat('ALTER TABLE ',@schema,'.',@table,' ALTER COLUMN ',@column,' varchar(',@mlen+20,')')
   insert into #temp1 select @sql1
   FETCH NEXT FROM PROC_CALL INTO @schema, @table, @column
END

CLOSE PROC_CALL
DEALLOCATE PROC_CALL
GO

select * from #temp1

--DROP TABLE #TEMP1
END


BEGIN /* show server name and version */
select CONVERT(VARCHAR(128), SERVERPROPERTY ('productversion')), CONCAT(@@SERVERNAME,'\', @@SERVICENAME)
END


BEGIN /*Get current size and current freespace of database files*/
use <DB_NAME>
go
SELECT 
 [type_desc], name AS FileName, 
size/128.0 AS CurrentSizeMB, 
size/128.0 - CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS FreeSpaceMB, 
CAST(FILEPROPERTY(name, 'SpaceUsed') AS INT)/128.0 AS UsedSpaceMB 
FROM <DB_NAME>.sys.database_files
END


BEGIN /* show total, used, unused space in database files*/
select 
	t.name as TABLE_NAME, 
	i.type_desc, 
	CAST(ROUND(((SUM(a.total_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS TotalSpaceMB,
	CAST(ROUND(((SUM(a.used_pages) * 8) / 1024.00), 2) AS NUMERIC(36, 2)) AS UsedSpaceMB,
	CAST(ROUND(((SUM(a.total_pages) - SUM(a.used_pages)) * 8) / 1024.00, 2) AS NUMERIC(36, 2)) AS UnusedSpaceMB
FROM sys.tables t
INNER JOIN sys.indexes i ON t.OBJECT_ID = i.object_id
INNER JOIN sys.partitions p ON i.object_id = p.OBJECT_ID AND i.index_id = p.index_id
INNER JOIN sys.allocation_units a ON p.partition_id = a.container_id
LEFT OUTER JOIN sys.schemas s ON t.schema_id = s.schema_id
--where t.name like '%F0%'
group by t.name, i.type_desc
order by t.name
END


BEGIN /* Shows the current percent completed of a database backup or restore, and the estimated completion time */
SELECT 
   session_id as SPID, command, a.text AS Query, start_time, percent_complete,
   dateadd(second,estimated_completion_time/1000, getdate()) as estimated_completion_time
FROM sys.dm_exec_requests r 
   CROSS APPLY sys.dm_exec_sql_text(r.sql_handle) a 
WHERE r.command in ('BACKUP DATABASE','RESTORE DATABASE') 
END

