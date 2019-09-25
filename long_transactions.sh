##

# Seteo directorios

export TMP_DIR=/p01/oebsprod/DBA/scripts/tmp
export MONITOREO_DIR=/p01/oebsprod/DBA/scripts/monitoreo
export LOG="$TMP_DIR/long_transactions_`date +%Y%m%d_%H%M`.log"

#----------------------------------------------------------------------------------------------------#
# Seteo de variables de entorno                                                                      #
#----------------------------------------------------------------------------------------------------#
. /p01/oracle/product/11.2.0/ERPP_usdcebsp.env

cd $MONITOREO_DIR

sqlplus /nolog << FIN
connect / as sysdba

set pages 300 trimspool on linesize 400
col spid format a7 head "UnixPid"
col username format a15
col osuser format a12
col event format a30
col module format a40
col action format a40
col start_scn format 9999999999999
set ver off echo off

spoo $LOG
start long_transactions 

spool off
exit
FIN

# Borro la 1 linea del archivo
#sed '1d' /p01/oebsprod/DBA/scripts/tmp/listadoConcurrentes.out > $LOG


# Seteo variable para control de errores

#export CHECK=`(cat $LOG |grep -i "No rows selected")`
CHECK=`cat  $LOG | grep -i "No rows selected"`
if [ "$CHECK" = "" ]
then
	mailx  -s "Transacciones de mas de 180 minutos de antiguedad en ERPP" admin@xxxxxxxx.com.ar < $LOG
fi


#if [ -s $LOG ]
#then
	##mailx  -s "Solicitudes con 120 Minutos de ejecucion"  ebs_@xxxxxxxx.com.ar  < $LOG	
#	mailx  -s "Solicitudes con mas de 120 Minutos de ejecucion" alertas@xxxxxxxxx.com latam_soporte@xxxxxxx.com desarrollo@xxxxxxxx.com  < $LOG	
#	mv $LOG /p01/oebsprod/DBA/scripts/tmp/hist/.
#fi

#rm $LOG
find $TMP_DIR -name "long_transactions*log" -mtime +45 -exec rm {} \;

exit
