/*
Disable all triggers in a database
*/
DECLARE PROC_CALL CURSOR FOR
select 'disable trigger '+a.name+'.'+b.name+' on '+a.name+'.'+OBJECT_NAME(b.parent_obj)+';' from sys.schemas a, sysobjects b
where a.schema_id=b.uid
AND XTYPE='TR'

OPEN PROC_CALL

DECLARE @sql1 NVARchar(80)

FETCH NEXT FROM PROC_CALL INTO @sql1
WHILE (@@FETCH_STATUS = 0)
BEGIN
   print @sql1 
   EXEC SP_executesql  @sql1
   FETCH NEXT FROM PROC_CALL INTO @sql1
END

CLOSE PROC_CALL
DEALLOCATE PROC_CALL
GO

/* show triggers in database */
select * from sysobjects where type='TR'

/* show triggers, trigger owner, table trigger is on */
select name, USER_NAME(uid) as Owner, OBJECT_NAME(parent_obj) as [Table Name] 
from sysobjects where type='TR'