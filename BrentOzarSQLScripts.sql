/* 
Run first responder health check on a server
*/
EXEC dba.dbo.sp_Blitz @CheckUserDatabaseObjects = 0, @CheckServerInfo = 1;