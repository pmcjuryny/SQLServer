/* Script to recovery SSISDB on a new sql server from Just a database backup
  Password used to created original SSISDB catalog is required

  The script was modified from a script provided on the following website
  http://sqlblog.com/blogs/andy_leonard/archive/2016/11/27/deploying-ssis-projects-to-a-restored-ssis-catalog-ssisdb.aspx
  
  
  Microsoft documentation for the procedure can be found here.
  https://msdn.microsoft.com/en-us/library/hh213291.aspx
*/



-- create the ##MS_SSISServerCleanupJobLogin## login if it does not already exist.
USE [master]
GO

print '##MS_SSISServerCleanupJobLogin## login'
If Not Exists(Select [name]
              From sys.sql_logins
              Where [name] = '##MS_SSISServerCleanupJobLogin##')
begin
  print ' - Creating the ##MS_SSISServerCleanupJobLogin## login'
  CREATE LOGIN [##MS_SSISServerCleanupJobLogin##] WITH PASSWORD='<**NEW_PASSWORD**>' -- *** change this, please - Andy
   , DEFAULT_DATABASE=[master]
   , DEFAULT_LANGUAGE=[us_english]
   , CHECK_EXPIRATION=OFF
   , CHECK_POLICY=OFF
  print ' - ##MS_SSISServerCleanupJobLogin## login created'
end
Else
print ' - ##MS_SSISServerCleanupJobLogin## already exists.'
GO

print ''

print ' - Disabling the ##MS_SSISServerCleanupJobLogin## login'
ALTER LOGIN [##MS_SSISServerCleanupJobLogin##] DISABLE
print ' - ##MS_SSISServerCleanupJobLogin## login disabled'
GO


USE [master]
GO

SET ANSI_NULLS ON
GO

SET QUOTED_IDENTIFIER ON
GO

print 'dbo.sp_ssis_startup stored procedure'
If Exists(Select s.name + '.' + p.name
          From sys.procedures p
          Join sys.schemas s
            On s.[schema_id] = p.[schema_id]
          Where s.[name] = 'dbo'
            And p.name = 'sp_ssis_startup')
begin
  print ' - Dropping dbo.sp_ssis_startup stored procedure'
  Drop PROCEDURE [dbo].[sp_ssis_startup]
  print ' - dbo.sp_ssis_startup stored procedure dropped'
end

print ' - Creating dbo.sp_ssis_startup stored procedure'
go

    CREATE PROCEDURE [dbo].[sp_ssis_startup]
    AS
    SET NOCOUNT ON
        /* Currently, the IS Store name is 'SSISDB' */
        IF DB_ID('SSISDB') IS NULL
            RETURN
       
        IF NOT EXISTS(SELECT name FROM [SSISDB].sys.procedures WHERE name=N'startup')
            RETURN
        
        /*Invoke the procedure in SSISDB  */
        /* Use dynamic sql to handle AlwaysOn non-readable mode*/
        DECLARE @script nvarchar(500)
        SET @script = N'EXEC [SSISDB].[catalog].[startup]'
        EXECUTE sp_executesql @script
GO
print ' - dbo.sp_ssis_startup stored procedure created'
print ''

/*
use master  
go
print 'Enabling SQLCLR'
exec sp_configure 'clr enabled', 1 
reconfigure
print 'SQLCLR enabled'
print ''
*/

print 'MS_SQLEnableSystemAssemblyLoadingKey asymetric key'
If Not Exists(Select [name]
              From sys.asymmetric_keys
              Where [name] = 'MS_SQLEnableSystemAssemblyLoadingKey')
begin
  print ' - Creating MS_SQLEnableSystemAssemblyLoadingKey'
  Create Asymmetric key MS_SQLEnableSystemAssemblyLoadingKey 
   From Executable File = 'E:\Program Files\Microsoft SQL Server\130\DTS\Binn\Microsoft.SqlServer.IntegrationServices.Server.dll'  -- *** check this, please - Andy
  print ' - MS_SQLEnableSystemAssemblyLoadingKey created'
end
Else
print ' - MS_SQLEnableSystemAssemblyLoadingKey already exists.'
go
print ''

print 'MS_SQLEnableSystemAssemblyLoadingUser SQL Login'
If Not Exists(Select [name]
              From sys.sql_logins
              Where [name] = 'MS_SQLEnableSystemAssemblyLoadingUser')
begin
  print ' - Attempting to create MS_SQLEnableSystemAssemblyLoadingUser Sql login'
  begin try
  Create Login MS_SQLEnableSystemAssemblyLoadingUser 
       From Asymmetric key MS_SQLEnableSystemAssemblyLoadingKey  
  print ' - MS_SQLEnableSystemAssemblyLoadingUser Sql login created'
  print ' - Granting Unsafe Assembly permission to MS_SQLEnableSystemAssemblyLoadingUser'
  Grant unsafe Assembly to MS_SQLEnableSystemAssemblyLoadingUser
  print ' - MS_SQLEnableSystemAssemblyLoadingUser granted Unsafe Assembly permission'
  end try
  begin catch
   print ' - Something went wrong while attempting to create the MS_SQLEnableSystemAssemblyLoadingUser Sql login, but it''s probably ok...'
   -- nothing for now
  end catch
end
Else
print ' - MS_SQLEnableSystemAssemblyLoadingUser Sql login already exists.'

go

print ''

/*
print 'Restoring SSISDB'
USE [master]

begin try
ALTER DATABASE [SSISDB] SET SINGLE_USER WITH ROLLBACK IMMEDIATE
end try
begin catch
-- ignore the error (usually happens because the database doesn’t exist…)
end catch

RESTORE DATABASE [SSISDB]
FROM DISK = N'E:\Andy\backup\SSISDB_SP1.bak'  -- *** check this, please - Andy
  WITH FILE = 1,
   MOVE N'data' To N'E:\Program Files\Microsoft SQL Server\MSSQL13.TEST\MSSQL\DATA\SSISDB.mdf',   -- *** check this, please - Andy
   MOVE N'log' TO N'E:\Program Files\Microsoft SQL Server\MSSQL13.TEST\MSSQL\DATA\SSISDB.ldf',   -- *** check this, please - Andy
   NOUNLOAD
, REPLACE
, STATS = 5

ALTER DATABASE [SSISDB] SET MULTI_USER

GO
print ' - SSISDB restore complete'
print ''
*/

print 'Set ProcOption to 1 for dbo.sp_ssis_startup stored procedure'
EXEC sp_procoption N'[dbo].[sp_ssis_startup]', 'startup', '1'
print 'ProcOption set to 1 for dbo.sp_ssis_startup stored procedure'

GO
print ''

Use SSISDB
go

print '##MS_SSISServerCleanupJobUser## user in SSISDB database'
If Not Exists(Select *
              From sys.sysusers
              Where [name] = '##MS_SSISServerCleanupJobUser##')
begin
  print ' - Creating ##MS_SSISServerCleanupJobUser## user'
  CREATE USER [##MS_SSISServerCleanupJobUser##] FOR LOGIN [##MS_SSISServerCleanupJobLogin##] WITH DEFAULT_SCHEMA=[dbo]
  print ' - ##MS_SSISServerCleanupJobUser## user created'
end
Else
print ' - ##MS_SSISServerCleanupJobUser## already exists.'
GO
print ''

/*

-- One method for restoring the master key from the file.
-- NOTE: You must have the original SSISDB encryption password!

Restore master key from file = 'E:\Andy\backup\SSISDB_SP1_key'    -- *** check this, please - Andy
       Decryption by password = 'SuperSecretPassword' -- 'Password used to encrypt the master key during SSISDB backup'    -- *** check this, please - Andy
       Encryption by password = 'SuperSecretPassword' -- 'New Password'    -- *** check this, please - Andy
       Force 
go
*/

-- Another method for restoring the master key from the file.
-- NOTE: You must have the original SSISDB encryption password!
print 'Opening the master key'
Open master key decryption by password = '<**SSISDB_PASSWORD**>' --'Password used when creating SSISDB'   -- *** check this, please - Andy
Alter Master Key
  Add encryption by Service Master Key
go
print 'Master key opened'

print ''
