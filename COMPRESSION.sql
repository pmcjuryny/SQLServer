BEGIN
/*
Generate script to compress indexes in the database
*/
select 'ALTER INDEX '+ '[' + si.[name] + ']' + ' ON ' + '[' + ss.[name] + ']' + '.' + '[' + st.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);' as [NOT_Compressed]
from sys.indexes si,
     sys.i htables  st,
     sys.partitions sp,
     sys.schemas ss
where si.object_id = st.object_id  and
      sp.object_id = st.object_id  and
      sp.index_id  = si.index_id   and
      st.schema_id = ss.schema_id  and 
      si.name is not null          and
      sp.data_compression_desc = 'NONE'
END


Begin
/*
generate script to compress tables in the database
*/
select 'ALTER TABLE ' + '[' + ss.[name] + ']'+'.' + '[' + st.[name] + ']' + ' REBUILD WITH (DATA_COMPRESSION=PAGE);' as [NOT_Compressed]
from sys.tables  st,
     sys.partitions sp,
     sys.schemas ss
where sp.object_id = st.object_id  and
      st.schema_id = ss.schema_id  and
      sp.data_compression_desc = 'NONE';
END


BEGIN
/*
script to loop through all databases on the server, and generate compression statements for all objects
*/
SET NOCOUNT ON
DECLARE @db_name VARCHAR(50);
DECLARE @sql VARCHAR(max);
DECLARE @comp CHAR(4);
SET @comp = 'PAGE'; -- Desired Compression Type

-- Create Cursor for all non-system databases, running in compatibility level above 90, online and not read-only.
DECLARE cur_dbs CURSOR FOR 
	SELECT name
	FROM sys.databases 
	WHERE database_id > 4
		AND compatibility_level > 90
		AND is_read_only = 0
		AND state = 0
		-- AND name NOT IN ('exclude_my_database1','exclude_my_database2')
	ORDER BY database_id

IF  EXISTS (
	SELECT * FROM tempdb.sys.objects WHERE type = 'U' AND object_id = OBJECT_ID(N'tempdb..#TempCompressTable')
	)
DROP TABLE #TempCompressTable;

CREATE TABLE #TempCompressTable (
	Rows BIGINT
	,db_name NVARCHAR(255)
	,CompressStatement NVARCHAR(2000)
	,create_date DATETIME
	,modify_date DATETIME
);

OPEN cur_dbs

FETCH NEXT FROM cur_dbs INTO @db_name;
WHILE @@FETCH_STATUS = 0
   BEGIN
     SET @sql = 'USE ['+@db_name+'];' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + 'INSERT INTO #TempCompressTable' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + 'SELECT ' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + '	ROWS' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + '	,db_name() AS db_name ' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + '	,[--CompressStatement]  ' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + '	,create_date' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + '	,modify_date' + CHAR(13) + CHAR(10)
     SET @sql = @sql + 'FROM (' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	SELECT p.rows AS rows, ''BEGIN TRY ALTER TABLE ['' + db_name() + ''].['' + SCHEMA_NAME(schema_id) + ''].['' + name + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = '+@comp+', ONLINE = ON); PRINT ''''ONLINE:  ['' + db_name() + ''].['' + SCHEMA_NAME(schema_id) + ''].['' + name + ''];'''' END TRY BEGIN CATCH ALTER TABLE ['' + db_name() + ''].['' + SCHEMA_NAME(schema_id) + ''].['' + name + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = '+@comp+', ONLINE = OFF); PRINT ''''OFFLINE: ['' + db_name() + ''].['' + SCHEMA_NAME(schema_id) + ''].['' + name + '']''''; END CATCH;'' AS [--CompressStatement], create_date, modify_date ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	--SELECT *' + CHAR(13) + CHAR(10)
	 SET @sql = @sql + 'FROM' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		sys.objects o' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		,sys.partitions p' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	WHERE ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		p.object_id = o.object_id' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND type = ''U'' ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND p.index_id <= 1' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND o.name <> ''sysdiagrams''' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND p.partition_number = 1' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND o.is_ms_shipped = 0 ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND data_compression = 0 -- all uncompressed user tables' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	UNION' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	SELECT p.rows AS rows, ''BEGIN TRY ALTER INDEX ['' + i.name + ''] ON ['' + db_name() + ''].['' + SCHEMA_NAME(o.schema_id) + ''].['' + OBJECT_NAME(i.object_id) + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = '+@comp+', ONLINE = ON); PRINT ''''ONLINE:  ['' + db_name() + ''].['' + i.name + ''] ON ['' + OBJECT_NAME(i.object_id) + ''];'''' END TRY BEGIN CATCH ALTER INDEX ['' + i.name + ''] ON ['' + db_name() + ''].['' + SCHEMA_NAME(o.schema_id) + ''].['' + OBJECT_NAME(i.object_id) + ''] REBUILD PARTITION = ALL WITH (DATA_COMPRESSION = '+@comp+', ONLINE = OFF); PRINT ''''OFFLINE: ['' + db_name() + ''].['' + i.name + ''] ON ['' + OBJECT_NAME(i.object_id) + '']''''; END CATCH;'' AS [--CompressStatement], create_date, modify_date ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	FROM ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		sys.indexes i' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		,sys.objects o' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		,sys.partitions p' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '	WHERE' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		o.object_id = i.object_id' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND o.object_id = p.object_id' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND i.type = 2 -- nonclustered index' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND i.name <> ''UK_principal_name'' -- nonclustered index' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND p.partition_number = 1' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND p.index_id > 1 -- nonclustered index' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND o.is_ms_shipped = 0 ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND NOT o.type in (''TF'',''FN'')' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND data_compression = 0 -- all uncompressed user tables' + CHAR(13) + CHAR(10)
     SET @sql = @sql + '		AND o.schema_id NOT IN (3,4)  ' + CHAR(13) + CHAR(10)
     SET @sql = @sql + ') x' + CHAR(13) + CHAR(10)
     SET @sql = @sql + 'ORDER BY ROWS DESC, [--CompressStatement] DESC' + CHAR(13) + CHAR(10)
     EXEC (@sql)
     FETCH NEXT FROM cur_dbs INTO @db_name;
   END;
DEALLOCATE cur_dbs;

-- Retrieve the compression statements. If everything needs to be compressed, select the content of the column "CompressStatement" and run it manually.
SELECT rows, db_name, create_date, modify_date, CompressStatement
FROM #TempCompressTable
ORDER BY db_name, Rows ASC
END




BEGIN 
---Script uses cursors to find all database in databases where compression is in use, reports the size once the tables would have compression removed
--TEMP TABLE TO HOLD DATABASE NAMES, WHERE COMPRESSION IS USED IN THE DATABASE
create table #pattemp (
database_name varchar(100),
feature_name varchar(200))

--TEMP TABLE TO HOLD THE OUTPUT FROM SP_ESTIMATE_DATA_COMPRESSION_SAVINGS 
create table #PATTEMP2 (
object_name varchar(200),
schema_name varchar(20),
index_id bigint,
partition_number bigint,
size_with_current_compression_setting_kb bigint,
size_with_requested_compression_setting_kb bigint,
sample_size_with_current_compression_setting_kb bigint,
sample_size_with_requested_compression_setting_kb bigint)

--INSERT THE DATABASE NAME OF DATABASES THAT HAVE ENTERPRISE ONLY FEATURES, MAINLY COMPRESSION
insert into #pattemp exec sp_msforeachdb 'select ''?'',feature_name from sys.dm_db_persisted_sku_features'

--CREATE A CURSOR WITH THE DATABASE NAMES TAKEN FROM THE #PATTEMP TABLE
declare @databasename varchar(100)
declare database_names cursor for
select database_name from #pattemp

--LOOP THROUGH THE DATABASES FROM THE CURSOR
open database_names
	fetch next from database_names into @databasename
	while  @@FETCH_STATUS=0
		begin 
				declare @tablename varchar(100)
				declare @OPENTABCURSOR varchar(1000)
				--CREATE CURSOR USING DYNAMIC SQL.  DYNAMIC SQL IS REQUIRED TO USE THE @DATABASENAME VARIABLE
				select @OPENTABCURSOR = 'declare table_names cursor for select name from '+@databasename+'.sys.tables'
				EXEC (@OPENTABCURSOR)
				open table_names
				fetch next from table_names into @tablename
				-- LOOP TO RUN SP_ESTIMATE_DATA_COMPRESSION_SAVINGS PROCEDURE IN EACH DATABASE, FOR EACH TABLE
				While @@FETCH_STATUS=0
				begin
					DECLARE @COMMAND VARCHAR(1000)
					SELECT @COMMAND='insert into #pattemp2 exec '+@DATABASENAME+'.SYS.sp_estimate_data_compression_savings ''dbo'','''+@tablename+''',NULL,NULL,''none'''					
					EXEC (@COMMAND)					
					Fetch next from table_names into @tablename				
				end	
				close table_names
				deallocate table_names
				FETCH NEXT FROM DATABASE_NAMES INTO @DATABASENAME
		end
close database_names
deallocate database_names

select * from #pattemp2
END







