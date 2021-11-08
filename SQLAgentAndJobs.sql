BEGIN
/*
Show SQL Server Agent Jobs and Schedules
*/
select
sysjobs.job_id
,sysjobs.name job_name
,sysjobs.enabled job_enabled
,sysschedules.name schedule_name
,sysschedules.schedule_id
,sysschedules.schedule_uid
,sysschedules.enabled schedule_enabled
from msdb.dbo.sysjobs
inner join msdb.dbo.sysjobschedules on sysjobs.job_id = sysjobschedules.job_id
inner join msdb.dbo.sysschedules on sysjobschedules.schedule_id = sysschedules.schedule_id
where sysjobs.name like '%DBA_MAINT%'
order by sysjobs.name asc
END


BEGIN
/* Show all sql agent jobs where owner is not SA, and select jobs with a specified owner
This was created to show jobs owned by when when he was leaving and his account was being disabled
Jobs owned by a disabled or missing account will not run
*/
select name as 'DatabaseName',suser_sname(owner_sid) as 'DatabaseOwner'
into #usapxm20_temp from master.sys.databases
where owner_sid<>0x01

select * from #usapxm20_temp
where DatabaseOwner='praxair-usa\usaxnts7104'

drop table #usapxm20_temp

SELECT name AS 'JobName',
Enabled = CASE WHEN Enabled = 0 THEN 'No'
ELSE 'Yes'
END,
suser_sname(owner_sid) AS 'OwnerName'
into #usapxm20_temp
FROM MSDB.dbo.sysjobs

select * from #usapxm20_temp
where OwnerName='PRAXAIR-USA\usaxnts7104'

drop table #usapxm20_temp
END


BEGIN
/*
Set on_fail_action for step 2 to be  "go to next step"
*/
EXEC msdb.dbo.sp_update_jobstep @job_id=N'95e1eea4-7ac9-4f45-9de3-29aa5e203d62', @step_id=2 , 
		@on_fail_action=3
GO
END


BEGIN
/*SQL Agent generate queries to update all steps other than 6, where job name like powerdoc, to continue on step failure
@on_fail_action=3
*/
select 'EXEC msdb.dbo.sp_update_jobstep @job_id=N'''+cast(job_id as varchar(50))+''', @step_id='+ cast(step_id as varchar(5))+' , @on_fail_action=3' from msdb.dbo.sysjobsteps
where job_id in
(select job_id from msdb.dbo.sysjobs
where name like 'POWERDOC%') and step_id<>6
order by step_id
END


BEGIN
/* 
Show agent jobs with schedule 
*/
select
sysjobs.name job_name
,sysjobs.enabled job_enabled
,schedule.name schedule_name
,[Occurs] = 
			CASE [schedule].[freq_type]
				WHEN   1 THEN 'Once'
				WHEN   4 THEN 'Daily'
				WHEN   8 THEN 'Weekly'
				WHEN  16 THEN 'Monthly'
				WHEN  32 THEN 'Monthly relative'
				WHEN  64 THEN 'When SQL Server Agent starts'
				WHEN 128 THEN 'Start whenever the CPU(s) become idle' 
				ELSE ''
			END
,[Occurs_detail] = 
				CASE [schedule].[freq_type]
					WHEN   1 THEN 'O'
					WHEN   4 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' day(s)'
					WHEN   8 THEN 'Every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' weeks(s) on ' + 
						LEFT(
							CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END + 
							CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END , 
							LEN(
								CASE WHEN [schedule].[freq_interval] &  1 =  1 THEN 'Sunday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  2 =  2 THEN 'Monday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  4 =  4 THEN 'Tuesday, '   ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] &  8 =  8 THEN 'Wednesday, ' ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 16 = 16 THEN 'Thursday, '  ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 32 = 32 THEN 'Friday, '    ELSE '' END + 
								CASE WHEN [schedule].[freq_interval] & 64 = 64 THEN 'Saturday, '  ELSE '' END 
							) - 1
						)
					WHEN  16 THEN 'Day ' + CONVERT(VARCHAR, [schedule].[freq_interval]) + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)'
					WHEN  32 THEN 'The ' + 
							CASE [schedule].[freq_relative_interval]
								WHEN  1 THEN 'First'
								WHEN  2 THEN 'Second'
								WHEN  4 THEN 'Third'
								WHEN  8 THEN 'Fourth'
								WHEN 16 THEN 'Last' 
							END +
							CASE [schedule].[freq_interval]
								WHEN  1 THEN ' Sunday'
								WHEN  2 THEN ' Monday'
								WHEN  3 THEN ' Tuesday'
								WHEN  4 THEN ' Wednesday'
								WHEN  5 THEN ' Thursday'
								WHEN  6 THEN ' Friday'
								WHEN  7 THEN ' Saturday'
								WHEN  8 THEN ' Day'
								WHEN  9 THEN ' Weekday'
								WHEN 10 THEN ' Weekend Day' 
							END + ' of every ' + CONVERT(VARCHAR, [schedule].[freq_recurrence_factor]) + ' month(s)' 
					ELSE ''
				END
		,[Frequency] = 
				CASE [schedule].[freq_subday_type]
					WHEN 1 THEN 'Occurs once at ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 2 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Seconds(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 4 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Minute(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					WHEN 8 THEN 'Occurs every ' + 
								CONVERT(VARCHAR, [schedule].[freq_subday_interval]) + ' Hour(s) between ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_start_time]), 6), 5, 0, ':'), 3, 0, ':') + ' and ' + 
								STUFF(STUFF(RIGHT('000000' + CONVERT(VARCHAR(8), [schedule].[active_end_time]), 6), 5, 0, ':'), 3, 0, ':')
					ELSE ''
				END
from msdb.dbo.sysjobs
inner join msdb.dbo.sysjobschedules on sysjobs.job_id = sysjobschedules.job_id
inner join msdb.dbo.sysschedules schedule on sysjobschedules.schedule_id = schedule.schedule_id
order by sysjobs.name asc
END