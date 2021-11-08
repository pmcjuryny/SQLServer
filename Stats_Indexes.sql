BEGIN /*Show Stale sql server stats, only look at objects with more than 1000 modifications*/
DECLARE @Build nvarchar(20);
DECLARE @B1 nvarchar(20) ;
DECLARE @B2 nvarchar(20);
DECLARE @B3 nvarchar(20);
DECLARE @BT1 nvarchar(20) ;
DECLARE @BT2 nvarchar(20) ;
SET @Build = CONVERT(nvarchar(20),(SELECT SERVERPROPERTY('ProductVersion')))
SELECT @Build AS ProductVersion
SET @B1 = SUBSTRING(@Build,0,PATINDEX('%.%',@Build))
SET @BT1 = SUBSTRING(@Build,(LEN(@B1+'.')+1),LEN(@Build))
SET @B2 = SUBSTRING(@BT1,0,PATINDEX('%.%',@BT1))
SELECT @BT2 = SUBSTRING(@BT1,(LEN(@B2+'.')+1),LEN(@BT1))
SET @B3 = SUBSTRING(@BT2,0,PATINDEX('%.%',@BT2))

IF (CAST(@B1 AS int)=10 AND CAST(@B2 AS int)=50 AND CAST(@B3 AS int) >= 4000) OR (CAST(@B1 AS int)=11 AND CAST(@B2 AS int)=00 AND CAST(@B3 AS int)>= 3000) OR (CAST(@B1 AS int)>11)
BEGIN
SELECT obj.name AS ObjectName, obj.object_id, stat.name AS StatisticsName, stat.stats_id, last_updated, modification_counter
FROM sys.objects AS obj
JOIN sys.stats AS stat 
ON stat.object_id = obj.object_id
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE obj.type='U' and sp.modification_counter>1000
order by ObjectName
--order by modification_counter desc
END
ELSE
BEGIN
	PRINT 'SQL Server version is not SQL Server 2008 R2 starting with Service Package 2 or SQL Server 2012 starting with Service Package 1';
END
END


BEGIN /*View reads and writes to indexes in databases Only view indexes with 10,000 rows or more*/
select objectname=OBJECT_NAME(s.OBJECT_ID)
    , indexname=i.name
    ,i.index_id
    ,READS=user_seeks + user_scans + user_lookups
    ,writes = user_updates
    ,p.rows
from sys.dm_db_index_usage_stats s 
    join sys.indexes i
        on i.index_id = s.index_id and s.OBJECT_ID=i.OBJECT_ID
    join sys.partitions p 
        on p.index_id=s.index_id and s.object_id=p.object_id
where objectproperty(s.object_ID,'IsUserTable') =1
    and s.database_id=DB_ID()
    and i.type_desc='nonclustered' --REMOVE to include cluster and nonclustered indexes
    and i.is_primary_key=0
    and i.is_unique_constraint=0
    and p.rows>10000
order by reads, rows desc
END


BEGIN /*View index fragmentation, Current Database*/
SELECT s.[name] +'.'+t.[name]  AS table_name
    ,i.NAME AS index_name
    ,index_type_desc
    ,ROUND(avg_fragmentation_in_percent,2) AS avg_fragmentation_in_percent
    ,record_count AS table_record_count
FROM sys.dm_db_index_physical_stats(DB_ID(), NULL, NULL, NULL, 'SAMPLED') ips
    INNER JOIN sys.tables t 
        on t.[object_id] = ips.[object_id]
    INNER JOIN sys.schemas s 
        on t.[schema_id] = s.[schema_id]
    INNER JOIN sys.indexes i 
        ON (ips.object_id = i.object_id) AND (ips.index_id = i.index_id)
ORDER BY avg_fragmentation_in_percent DESC
END


BEGIN /*rebuild all indexes on a specific table*/
ALTER INDEX ALL ON SCHEMA.TABLE REBUILD
END


BEGIN /*Rebuild all indexes on specific table, set fill factor*/
ALTER INDEX ALL ON SCHEMA.TABLE REBUILD WITH (FILLFACTOR = 100)
END


BEGIN /*Rebuild a single index on a specific table*/
alter index IndexName on SCHEMA.TABLE REBUILD
END


BEGIN /*View all indexes on a specific table*/
SELECT * FROM Sys.Indexes WHERE object_id=OBJECT_ID('SCHEMA.TABLE')
END


BEGIN /*Find and Rebuild indexes with fill factor less than 80, but not 0*/
SELECT 'ALTER INDEX '+name+' ON '+OBJECT_SCHEMA_NAME(object_id)+'.'+OBJECT_NAME(object_id)+' REBUILD WITH (FILLFACTOR=80);'
FROM sys.indexes 
WHERE fill_factor < 80 AND fill_factor <> 0
AND is_disabled = 0 AND is_hypothetical = 0;
END


BEGIN /* Monitor the progress of update stats process
uses total number of stats, plus the number of stats updated earlier than today, to estimate the percent completed*/
declare @t float
declare @d float
declare @r date
select @r= CONVERT(DATE, GETDATE(), 120)
select @t=count(*) from sys.stats
select @d=count(*) from (
SELECT OBJECT_NAME(object_id) AS [ObjectName]
      ,[name] AS [StatisticName]
      ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats
) a where a.[StatisticUpdateDate] >=@r
--select @r
--select @t
--select @d
select (@d/@t)*100 as 'PercentCompleted'
END


BEGIN /* Shows stats and their last time updated*/
SELECT OBJECT_NAME(object_id) AS [ObjectName]
      ,[name] AS [StatisticName]
      ,STATS_DATE([object_id], [stats_id]) AS [StatisticUpdateDate]
FROM sys.stats;
END


BEGIN /* show stats details for specific database objects*/
SELECT obj.name AS ObjectName, obj.object_id, stat.name AS StatisticsName, stat.stats_id, last_updated, modification_counter
FROM sys.objects AS obj
JOIN sys.stats AS stat 
ON stat.object_id = obj.object_id
CROSS APPLY sys.dm_db_stats_properties(stat.object_id, stat.stats_id) AS sp
WHERE obj.type='U' 
and (
	Obj.name='IN_SEQUENCE' or 
	Obj.name='IN_SC_CONNECTION' or 
	Obj.name='IN_CHILD_ITEM' or 
	Obj.name='IN_OSM_TREE_FSS'
	)
order by ObjectName
END