#!/bin/bash

# Update MapR Yum Repository
if [ -f /etc/yum.repos.d/mapr.repo ]; then
	sed -i '0,/baseurl=.*package.mapr.com.*/{s,,baseurl=http://package.mapr.com/releases/v5.0.0/redhat,}' /etc/yum.repos.d/mapr.repo
else
	echo "/etc/yum.repos.d/mapr.repo not found or needs hand edit"
	exit
fi

# Place nodes in maintenance mode
maprcli node maintenance -nodes $(hostname) -timeoutminutes 30

# Notify the CLDB that the node is going to be upgraded
maprcli notifyupgrade start -node $(hostname)

# Stop warden
service mapr-warden stop

# Stop Zookeeper
if [ -f /opt/mapr/roles/zookeeper ]; then
    echo "Stopping Zookeeper" && service mapr-zookeeper stop
fi

# Wait for Zookeeper to stop
while [ -f /var/lock/subsys/mapr-zookeeper ]
do
	sleep 2
done

# Wait for processes to stop
while [ -f /opt/mapr/pid/warden.pid ]
do
	sleep 2
done

# Upgrade each MapR package in the following order

packages=(mapr-cldb mapr-core-internal mapr-core mapr-fileserver mapr-hadoop-core mapr-historyserver mapr-jobtracker
mapr-mapreduce1 mapr-mapreduce2 mapr-metrics mapr-nfs mapr-nodemanager mapr-resourcemanager mapr-tasktracker mapr-webserver mapr-zk-internal mapr-zookeeper)

for i in ${packages[@]}
do
	echo "Checking if $i is Installed"
	rpm --quiet -q $i
	if [ $? = 0 ]
		then
		yum update -y $i
		echo "Upgrading $i"
	else
		echo "$i Not Found... Skipping."
	fi
done

#Re-Run configure.sh
/opt/mapr/server/configure.sh -R

# Start Zookeeper
if [ -f /opt/mapr/roles/zookeeper ]; then
	service mapr-zookeeper start
fi

# Zookeeper Process Check
while [ ! -f /var/lock/subsys/mapr-zookeeper ]
do
	sleep 2
done

# Start warden
service mapr-warden start

# Process Check
while [ ! -f /opt/mapr/pid/warden.pid ]
do
	sleep 2
done

# Verify cldb is up and running
LOG=/tmp/wait_for_cldb.log
MAX_WAIT=${MAX_WAIT:-600}
STIME=5
CMSTR_CMD="timeout -s HUP 5s ca 2> /dev/null"
SWAIT=MAX_WAIT

$CMSTR_CMD 2>> $LOG
while [ $? -ne 0  -a 120 -gt 0 ]; do
	echo "CLDB not found; will wait for $SWAIT more seconds" | tee -a $LOG
	sleep $STIME
	SWAIT=$[SWAIT - $STIME]
	$CMSTR_CMD 2>> $LOG
done

# Take node out of maintenance mode
maprcli node maintenance -nodes $(hostname) -timeoutminutes 0

# If CLDB, Instruct CLDB About New Version
# maprcli config save -values {mapr.targetversion:"`cat /opt/mapr/MapRBuildVersion`"}

# Notify the CLDB that the node upgrade is finished
maprcli notifyupgrade finish –node $(hostname)

# Wait for the containers to synchronize
length=1
while [ $length -ne 0 ]; do
	resync_status=$(/opt/mapr/server/mrconfig info containers resync local)
	length=${#resync_status}
done
