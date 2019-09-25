#----------------------------------------------------------------------------------------------------#
#                                                                                                    #
# Script para matar procesos de sesiones inactivas                                                   #
#                                                                                                    #
# Modo de uso:                                                                                       #
#                                                                                                    #
# ./kill_inactive.sh                                                                                 #
#                                                                                                    #
#----------------------------------------------------------------------------------------------------#

#----------------------------------------------------------------------------------------------------#
# Seteo de variables de entorno                                                                      #
#----------------------------------------------------------------------------------------------------#
. /p01/oracle/product/11.2.0/ERPP_usdcebsp.env

#----------------------------------------------------------------------------------------------------#
# Inicializacion de variables                                                                        #
#----------------------------------------------------------------------------------------------------#
SERVER=`uname -n`
MAIL_DBA="database@xxxxxxxxxxxxxxxx.com.ar"
PATH_SCRIPTS="/p01/oebsprod/DBA/scripts"
TMP_FILE="${PATH_SCRIPTS}/logs/kill_inactive_${ORACLE_SID}_`date +%d-%m-%Y_%H-%M`.log"
KILL_FILE="${PATH_SCRIPTS}/monitoreo/tmp/kill_inactive_${ORACLE_SID}_`date +%d-%m-%Y_%H-%M`.sh"

#----------------------------------------------------------------------------------------------------#
# Comienzo de ejecucion                                                                              #
#----------------------------------------------------------------------------------------------------#

sqlplus -S "/as sysdba" <<ENDOFSQL

TTITLE CENTER "Chequeo de Sesiones Inactivas"
SET LINES 300 pages 9999
SET FEED OFF

col killsent format a15
col username format a15
col program format a20 trunc
col machine format a30 trunc
col module format a30 trunc
col action format a30 trunc
col logon_time format a18

spool ${TMP_FILE}

SELECT  p.spid , sid, s.serial#, s.username, s.program, s.machine, s.module, s.action, s.process, s.sql_id, 
	to_char(logon_time, 'dd-mm-yy hh24:mi:ss') logon_time, last_call_et
FROM v\$session s, v\$process p
WHERE s.paddr = p.addr
AND s.status = 'INACTIVE'
AND s.username = 'APPS'
AND s.last_call_et/3600 > 2
AND (s.action LIKE 'FRM%'
        or        
     nvl(s.program,' ')<>'JDBC Thin Client'
     )
AND s.machine in ('usdc1srp00224.prosegur.local','usdc1srp00225.prosegur.local','usdc1srp00226.prosegur.local')
union all
SELECT  p.spid , sid, s.serial#, s.username, s.program, s.machine, s.module, s.action, s.process, s.sql_id,
        to_char(logon_time, 'dd-mm-yy hh24:mi:ss') logon_time, last_call_et
FROM v\$session s, v\$process p
WHERE s.paddr = p.addr
AND s.status = 'INACTIVE'
AND s.last_call_et/3600 > 2
and (upper(nvl(s.program,' ')) like '%TOAD%' or upper(nvl(s.program,' ')) like '%PLSQLDEV%')
order by 1 
/


spool off
exit

ENDOFSQL


#Se obtiene del archivo anterior los PID de SO y se arma la sentencia de kill
#la que se guarda en el archivo KILL_FILE

# cat ${TMP_FILE} | grep usdc1srp0022 | awk '{print "kill -9 " $1}' | sort -u > ${KILL_FILE}
cat ${TMP_FILE} | awk '{print "kill -9 " $1}' | sort -u > ${KILL_FILE}


SIZE=`ls -l ${KILL_FILE} | awk '{ print int($5) }';`

if [[ $SIZE -gt 1 ]]; then
	   echo "\n\nComando de SO ejecutado para matar sesiones inactivas /s:\n" >> $TMP_FILE
	   cat ${KILL_FILE} >> $TMP_FILE
          . ${KILL_FILE}
          mailx -s "($SERVER) - Kill de sesiones inactivas [$ORACLE_SID]" $MAIL_DBA < $TMP_FILE
else
          rm -f $KILL_FILE
fi

find "${PATH_SCRIPTS}/logs/kill_inactive*" -mtime +15 -exec rm {} \;
find "${PATH_SCRIPTS}/monitoreo/tmp/kill*" -mtime +15 -exec rm {} \;

################################################################################################

