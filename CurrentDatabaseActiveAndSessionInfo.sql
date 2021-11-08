/* 
Show sessions in rollback state 
*/
select session_id, command, percent_complete
from sys.dm_exec_requests
where status='rollback'

/* 
Show session information for specific status 
*/
select session_id, command, percent_complete, status from sys.dm_exec_requests
where session_id=123

/* 
Show current query from given session 
*/
DECLARE @sqltext VARBINARY(128)
SELECT @sqltext = sql_handle
FROM sys.sysprocesses
WHERE spid = (144)
SELECT TEXT
FROM sys.dm_exec_sql_text(@sqltext)
GO

/* 
show sessions that are not sleeping 
--Show twop 100 active sessions
*/
SELECT TOP 100 [spid]
      ,[waittime]
      ,[lastwaittype]
      ,d.name
      ,[cpu]
      ,[physical_io]
      ,[memusage]
      ,p.[status]
      ,[cmd]
      ,[loginame]
  FROM sys.sysprocesses as p
     join sys.sysdatabases as d 
          on d.dbid=p.dbid
  where p.status <> 'sleeping'

/* 
View sessions that are holding page allocations 
*/
SELECT s.session_id    AS 'SessionId',
       s.login_name    AS 'Login',
       DB_NAME(r.database_id) as 'Database_Name',
       COALESCE(s.host_name, c.client_net_address) AS 'Host',
       s.program_name  AS 'Application',
       t.task_state    AS 'TaskState',
       r.start_time    AS 'TaskStartTime',
       r.[status] AS 'TaskStatus',
       r.wait_type     AS 'TaskWaitType',
       TSQL.[text] AS 'TSQL',
       (
           tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count
       ) +(
           tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count
       )               AS 'TotalPagesAllocated'
FROM   sys.dm_exec_sessions s
       LEFT  JOIN sys.dm_exec_connections c
            ON  s.session_id = c.session_id
       LEFT JOIN sys.dm_db_task_space_usage tsu
            ON  tsu.session_id = s.session_id
       LEFT JOIN sys.dm_os_tasks t
            ON  t.session_id = tsu.session_id
            AND t.request_id = tsu.request_id
       LEFT JOIN sys.dm_exec_requests r
            ON  r.session_id = tsu.session_id
            AND r.request_id = tsu.request_id
       OUTER APPLY sys.dm_exec_sql_text(r.sql_handle) TSQL
WHERE  (
           tsu.user_objects_alloc_page_count - tsu.user_objects_dealloc_page_count
       ) +(
           tsu.internal_objects_alloc_page_count - tsu.internal_objects_dealloc_page_count
       ) > 0;


/* 
Show top 1000 transactions against specific database
Change database_id to db_id of database in question 
*/
--sys.dm_tran_database_transactions
--
--transaction_id								bigint			ID of the transaction at the instance level, not the database level. It is only unique across all databases within an instance, but not unique across all server instances.
--database_id									int				ID of the database associated with the transaction.
--database_transaction_begin_time					datetime	     	Time at which the database became involved in the transaction. Specifically, it is the time of the first log record in the database for the transaction.
--database_transaction_type						int				1 = Read/write transaction
--															2 = Read-only transaction
--															3 = System transaction
--database_transaction_state						int				1 = The transaction has not been initialized.
--															3 = The transaction has been initialized but has not generated any log records.
--															4 = The transaction has generated log records.
--															5 = The transaction has been prepared.
--															10 = The transaction has been committed.
--															11 = The transaction has been rolled back.
--															12 = The transaction is being committed. In this state the log record is being generated, but it has not been materialized or persisted.
--database_transaction_status						int				Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--database_transaction_status2					int				Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--database_transaction_log_record_count				bigint			Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of log records generated in the database for the transaction.
--database_transaction_replicate_record_count		int				Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of log records generated in the database for the transaction that will be replicated.
--database_transaction_log_bytes_used				bigint			Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of bytes used so far in the database log for the transaction.
--database_transaction_log_bytes_reserved			bigint			Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of bytes reserved for use in the database log for the transaction.
--database_transaction_log_bytes_used_system		     int				Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of bytes used so far in the database log for system transactions on behalf of the transaction.
--database_transaction_log_bytes_reserved_system	     int				Applies to: SQL Server 2008 through SQL Server 2016.
--																	Number of bytes reserved for use in the database log for system transactions on behalf of the transaction.
SELECT TOP 1000 *
  FROM [sys].[dm_tran_database_transactions]
  where database_id=10
  

/* 
View top 1000 session transactions 
*/
--sys.dm_tran_session_transactions
--
--session_id				int			ID of the session under which the transaction is running.
--transaction_id			bigint		ID of the transaction.
--transaction_descriptor	     binary(8)	     Transaction identifier used by SQL Server when communicating with the client driver.
--enlist_count				int			Number of active requests in the session working on the transaction.
--is_user_transaction		bit			1 = The transaction was initiated by a user request.
--									0 = System transaction.
--open_transaction_count				     The number of open transactions for each session.
SELECT TOP 1000 *
  FROM [sys].[dm_tran_session_transactions]



/* 
View active transaction in the system 
*/
--sys.dm_tran_active_transactions
--
--transaction_id			bigint			ID of the transaction at the instance level, not the database level. It is only unique across all databases within an instance but not unique across all server instances.
--name					nvarchar(32)		Transaction name. This is overwritten if the transaction is marked and the marked name replaces the transaction name.
--transaction_begin_time	     datetime			Time that the transaction started.
--transaction_type			int				Type of transaction.
--											1 = Read/write transaction
--											2 = Read-only transaction
--											3 = System transaction
--											4 = Distributed transaction
--transaction_uow			uniqueidentifier	Transaction unit of work (UOW) identifier for distributed transactions. MS DTC uses the UOW identifier to work with the distributed transaction.
--transaction_state			int					0 = The transaction has not been completely initialized yet.
--											1 = The transaction has been initialized but has not started.
--											2 = The transaction is active.
--											3 = The transaction has ended. This is used for read-only transactions.
--											4 = The commit process has been initiated on the distributed transaction. This is for distributed transactions only. The distributed transaction is still active but further processing cannot take place.
--											5 = The transaction is in a prepared state and waiting resolution.
--											6 = The transaction has been committed.
--											7 = The transaction is being rolled back.
--											8 = The transaction has been rolled back.
--transaction_status		int					Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--transaction_status2		int					Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--dtc_state				int					Applies to: Azure SQL Database (Initial release through current release).
--												1 = ACTIVE
--												2 = PREPARED
--												3 = COMMITTED
--												4 = ABORTED
--												5 = RECOVERED
--dtc_status				int					Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--dtc_isolation_level		int					Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--filestream_transaction_id	varbinary(128)		     Applies to: Azure SQL Database (Initial release through current release).
--												Identified for informational purposes only. Not supported. Future compatibility is not guaranteed.
--pdw_node_id				int					Applies to: Azure SQL Data Warehouse Public Preview, Parallel Data Warehouse
--												The identifier for the node that this distribution is on.
SELECT TOP 1000 *
  FROM [sys].[dm_tran_active_transactions]    
