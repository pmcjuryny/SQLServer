BEGIN /* run consitency check on individual table */
DBCC CHECKTABLE('SCHEMA.TABLE') with all_errormsgs, no_infomsgs
END

BEGIN /*Standard database consitency check*/
DBCC CHECKDB('DB_NAME') with all_errormsgs, no_infomsgs
END

BEGIN /*Database consistency check of only physical structure of page and record headers, a lower impact check */
DBCC CHECKDB('DB_NAME') with PHYSICAL_ONLY, all_errormsgs, no_infomsgs
END

BEGIN /*Double byte consistency errors can be caused by the last byte of a double byte character being dropped from the table */
--This has happened several times for JDE asia databases.
--Run checkdb on the table that is causing the error, this should show which column the problem data is in
-- by increasing the column size by one, and then returning it to the original size, the partial character is dropped 
--If the column is in the primary key or an index the key/index will need to be dropped/recreated, setting database to single user mode reduces the changes of blocking issues
--This example is from a database named JDE_PD7333, the table is PD7333.F980011, primary key and index definitions need to be saved before dropping them

alter database JDE_PD7333 set SINGLE_USER

alter table PD7333.F980011 drop constraint F980011_PK
DROP INDEX [F980011_6] ON [PD7333].[F980011]
GO
alter table PD7333.F980011 alter column SIFDNM char(31) NOT NULL
alter table PD7333.F980011 alter column SIFDNM char(30) NOT NULL
ALTER TABLE [PD7333].[F980011] ADD  CONSTRAINT [F980011_PK] PRIMARY KEY CLUSTERED 
(	[SIOBNM] ASC,	[SIOBJP] ASC,	[SIATRP] ASC,	[SIFDNM] ASC,	[SIATRS] ASC,	[SIDDID] ASC,	[SIAPPLID] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, IGNORE_DUP_KEY = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
CREATE NONCLUSTERED INDEX [F980011_6] ON [PD7333].[F980011]
(	[SIFDNM] ASC)
WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, SORT_IN_TEMPDB = OFF, DROP_EXISTING = OFF, ONLINE = OFF, ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, FILLFACTOR = 90) ON [PRIMARY]
GO
ALTER database JDE_PD7333 SET MULTI_USER
END 

BEGIN /*Show database information, including data of last DBCC*/
DBCC DBINFO ('DBNAME') WITH TABLERESULTS
END
