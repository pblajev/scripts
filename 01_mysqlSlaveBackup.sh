#!/bin/bash
# vim: sw=5
###########################################################################
#
#       Program name:   mysqlSlaveBackup.sh
#       File name:      mysqlSlaveBackup.sh
#       Author:         PBB
#       First revision: Jan '2012
#
#       Description:
#         Script is intended to run from cron. It wll stop the mysql
#         slave, dump the database and start the mysql slave again.
#         The connection information should be in /root/.<defaultsFile>
#         and it should be accessible only to root:
#         	cat /root/.<defaultsFile>
#			[client]
#			host=127.0.0.1
#			port=3311 (or whatever the port is)
#			user = backup
#			password = secret
#			[mysqladmin]
#			host=127.0.0.1
#			port=3311
#			user = backup
#			password = secret
#
#  The mysql backup account requires SUPER privileges to be able to stop slave
#    mysql> grant super
#        -> on *.* to 'backup'@'localhost'
#        -> IDENTIFIED BY 'secret';
#
#	  The cron entry should look like this:
#	  	mysqlSlaveBackup \
#	  		-c /root/.mysqlCustom.cnf \
#	  		-d /dbslave/backup/daily \
#	  		--keep 5
#
#	  	This command will use .mysqlCustom.cnf to connect to the
#	  	database, create backup file:
#	  		/dbslave/backup/daily/mysql-<hostName>Slave-date.sql.gz
#	  	and keep the 5 most recent files in the backup
#	  	directory. It will remove the older files.
#
###########################################################################

PATH="/usr/local/bin:/usr/local/sbin:/usr/bin:/bin:/usr/sbin:/sbin"

self="`basename $0`"

HOSTNAME=`hostname | sed 's/\..*//'`
USAGE="YES"

# Collect some parametters
#
while [ $# -ne 0 ]; do

     case $1 in
     "-c"|"--config")
	  USAGE="NO"
	  defaultsFile=$2
	  shift 1
	  ;;
     "-d"|"--directory")
	  USAGE="NO"
	  backupDir=$2
	  shift 1
	  ;;
     "--keep")
	  USAGE="NO"
	  toKeep=$2
	  shift 1
	  ;;
     *)
	  USAGE="YES"
	  ;;
     esac

     shift 1
done

[ -z $defaultsFile ] && USAGE="YES"
[ -z $backupDir ] && USAGE="YES"

if [ ! -r $defaultsFile ]; then
     echo "File $defaultsFile not readable"
     exit 1
fi

if [ ! -d $backupDir ]; then
     echo ""
     echo "ERROR: Directory $backupDir not accessible !!!"
     USAGE="YES"
fi

if [ "$USAGE" = "YES" ]; then
     echo "
${self}:

Usage:	$self -c defaultsFile -d backupDir --keep N

     -c, --config defaultsFile
	  Use only this file to get connection information.

     -d, --directory backupDir
	  Dump the databases in this directory.

     --keep N
	  Where N is number of most recent backup files to keep.
	  Delete the rest.

     -?, --help
	Show this help message.

"

     exit 1
fi

nameAddOn=`mysql --defaults-file=$defaultsFile -e 'show slave status\G' | \
     grep Master_Host | awk '{print $2}'`
backupFile="$backupDir/mysql-${nameAddOn}Slave-`date +%Y%m%d`-$$.sql.gz"

# ===========================================================================
# Good to go. Let's do some real work.

# ---------------------------------------------------------------------------
stopSlave ()
{
     CMD="mysql --defaults-file=$defaultsFile -e 'stop slave;'"
     echo $CMD
     echo $CMD | bash
}

# ---------------------------------------------------------------------------
startSlave ()
{
     sleep 5
     CMD="mysql --defaults-file=$defaultsFile -e 'start slave;'"
     echo $CMD
     echo $CMD | bash
}

# ---------------------------------------------------------------------------
backupSlave ()
{
     sleep 5
     /bin/touch $backupFile
     if [ $? -ne 0 ]; then
	  echo ""
	  echo "     ERROR: Can't create file $backupFile"
	  exit 1
     fi
     /bin/chmod 600 $backupFile

     CMD="mysqldump --defaults-file=$defaultsFile \
	  --opt --quote-names --all-databases | gzip > $backupFile"
     echo $CMD
     echo $CMD | bash
}

# ---------------------------------------------------------------------------
rotateBackups ()
{
     directoryFiles=`ls -t ${backupDir}/mysql-${nameAddOn}Slave*`
     countFiles=`echo $directoryFiles | tr ' ' '\n' | wc -l`
     if [ $countFiles -gt $toKeep ]; then
	  toDelete=`expr $countFiles - $toKeep`
	  deleteFiles=`echo $directoryFiles | tr ' ' '\n' | tail -$toDelete`
	  echo "   Deleting:"
	  echo $deleteFiles | tr ' ' '\n'
	  echo $deleteFiles | xargs /bin/rm -f {}
	  if [ $? -ne 0 ]; then
	       echo "   ERROR: Failed to successfully delete old backups !!!"
	       exit 1
	  fi
     else
	  echo "   Nothing to delete. Found only $countFiles backups."
     fi
}

# ---------------------------------------------------------------------------
echo ""; echo "=== [`date +%D\ -\ %T`] Running $self on $HOSTNAME ==="
echo "   DB backup file $backupFile"

echo ""; echo "=== [`date +%D\ -\ %T`] Stop MySQL Slave Instance ==="
echo -n "   Command: "
stopSlave
if [ $? -ne 0 ]; then
     echo "   ERROR: MySQL slave instance failed to stop !!!"
     exit 1
fi

echo ""; echo "=== [`date +%D\ -\ %T`] Backup MySQL Slave Instance ==="
echo -n "   Command: "
backupSlave
if [ $? -ne 0 ]; then
     echo "   ERROR: MySQL slave instance backup FAILED !!!"
     exit 1
fi

echo ""; echo "=== [`date +%D\ -\ %T`] Rotate the backups ==="
echo "   Keep $toKeep backups in $backupDir"
rotateBackups
if [ $? -ne 0 ]; then
     echo "   ERROR: Rotating backup files FAILED !!!"
     exit 1
fi

echo ""; echo "=== [`date +%D\ -\ %T`] Start MySQL Slave Instance ==="
echo -n "   Command: "
startSlave
if [ $? -ne 0 ]; then
     echo "   ERROR: MySQL slave instance failed to start !!!"
     exit 1
fi

echo ""; echo "=== [`date +%D\ -\ %T`] End of $self ==="

exit 0

# ----
