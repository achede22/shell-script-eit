
#!/bin/bash
# This script is to send mail for alerting Data gaurd DR sync status of given database.
# Assumption smtb confirgured,TNS entry of db in tnsname.ora,created DIR's

export ORACLE_HOME=/p01/oracle/product/11.2.0
export PATH=/p01/oracle/product/11.2.0/bin:/usr/sbin:$PATH
export SCRIPT_DIR=/p01/oebsprod/DBA/scripts/monitoreo 
export LOG_DIR=/tmp                        
#export TNS_ADMIN=/u01/app/oracle/util/scripts

CURR_DATE=`date '+%m/%d/%y_%H:%M'`

if [ -f ${LOG_DIR}/DR_Sync_status.txt ]
  then
    `rm   ${LOG_DIR}/DR_Sync_status.txt `
fi
if [ -f ${LOG_DIR}/DR_Sync_output.log ]
  then
    `rm ${LOG_DIR}/DR_Sync_output.log `
fi

touch ${LOG_DIR}/DR_Sync_status.txt

for SID in ERPP          
do
 echo $SID
 echo "-----------------------------------------------------------------------" >> ${LOG_DIR}/DR_Sync_status.txt
 echo "DR SYNC STATUS REPORT FOR DATABASE: ${SID} " >> ${LOG_DIR}/DR_Sync_status.txt
echo "-----------------------------------------------------------------------" >> ${LOG_DIR}/DR_Sync_status.txt
export ORACLE_SID=$SID
 sqlplus /nolog << EOF 
connect  / as sysdba

 set term off trims on linesize 300 pages 300 echo off underline off heading on
 spool ${LOG_DIR}/DR_Sync_output.log
 col name for a10
 set und off
 col INST_NAME heading "INST" for a10 justify c
 col LOG_ARCHIVED heading "ARCHIVA" for 99999999 justify c
 col LOG_APPLIED heading "APLIC" for 99999999 justify c
 col TIME_APPLIED heading "HORARIO" for a20 justify c
SELECT INST_NAME ,LOG_ARCHIVED,  LOG_APPLIED , TIME_APPLIED ,  LOG_ARCHIVED - LOG_APPLIED GAP FROM
  (SELECT   INST_ID, INSTANCE_NAME INST_NAME, HOST_NAME  FROM GV\$INSTANCE ORDER BY INST_ID) NAME,  (SELECT   INST_ID,
  PROTECTION_MODE, SYNCHRONIZATION_STATUS FROM GV\$ARCHIVE_DEST_STATUS WHERE DEST_ID = 2 ORDER BY INST_ID) STAT,
             (SELECT   THREAD#, MAX (SEQUENCE#) LOG_ARCHIVED FROM GV\$ARCHIVED_LOG WHERE DEST_ID = 1
 AND ARCHIVED = 'YES' AND RESETLOGS_ID = (SELECT MAX (RESETLOGS_ID) FROM GV\$ARCHIVED_LOG  WHERE DEST_ID = 1
AND ARCHIVED = 'YES')  GROUP BY THREAD# ORDER BY THREAD#) ARCH, (SELECT   THREAD#,MAX (SEQUENCE#) LOG_APPLIED,
TO_CHAR (MAX (COMPLETION_TIME),  'DD-Mon HH24:MI:SS') TIME_APPLIED FROM GV\$ARCHIVED_LOG  WHERE DEST_ID = 2 AND APPLIED = 'YES'
AND RESETLOGS_ID = (SELECT MAX (RESETLOGS_ID) FROM GV\$ARCHIVED_LOG  WHERE DEST_ID = 1 AND ARCHIVED = 'YES') GROUP BY THREAD#
              ORDER BY THREAD#) APPL  WHERE NAME.INST_ID = STAT.INST_ID AND NAME.INST_ID = ARCH.THREAD# AND NAME.INST_ID = APPL.THREAD#
--and (LOG_ARCHIVED - LOG_APPLIED) <> 0
and  (LOG_ARCHIVED - LOG_APPLIED) > 1
/
 spool off
 exit
EOF

CHECK=`cat  ${LOG_DIR}/DR_Sync_output.log | grep -i "No rows selected"`
if [ "$CHECK" = "" ]
then

	cat ${LOG_DIR}/DR_Sync_output.log |grep -v 'SQL>'|grep -v 'SQL&gt' | grep -v selected  >> ${LOG_DIR}/DR_Sync_status.txt
	if [ -f ${LOG_DIR}/DR_REPORT.html ]
  	then
    		`rm   ${LOG_DIR}/DR_REPORT.html `
	fi


	cat  ${LOG_DIR}/DR_Sync_status.txt >>  ${LOG_DIR}/DR_REPORT.html
#rm  ${LOG_DIR}/DR_Sync_output.log
#rm ${LOG_DIR}/DR_Sync_status.txt
	#mailx -s "ESTADO DATAGUARD ERPP" alertas@xxxxxxxx.com < ${LOG_DIR}/DR_REPORT.html 
	mailx -s "ESTADO DATAGUARD ERPP"  hlozza@tecsolgroup.com.ar  < ${LOG_DIR}/DR_REPORT.html

fi

done

