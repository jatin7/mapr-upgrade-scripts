#!/bin/bash

# Stop Mail Application

# Unmount NFS

# Stop mapr-loopbacknfs
sudo service mapr-loopbacknfs stop

# Update MapR Yum Repository
if [ -f /etc/yum.repos.d/mapr.repo ]; then
	sed -i '0,/baseurl=.*package.mapr.com.*/{s,,baseurl=http://package.mapr.com/releases/v5.0.0/redhat,}' /etc/yum.repos.d/mapr.repo
else
	echo "/etc/yum.repos.d/mapr.repo not found or needs hand edit"
	exit 1
fi

# Install MapR Posix Client
	echo "Checking if MapR Posix Client Is Installed"
	rpm --quiet -q mapr-loopbacknfs
	if [ $? = 0 ]
	then
		echo "Upgrading $i"
		sudo yum update -y mapr-loopbacknfs
		if [ $? -ne 0 ]
		then
			echo "yum update of $i failed"
			exit 2
		fi
	else
		echo "$i Not Found... Skipping."
	fi
done

# Install Patch
rpm --quiet -q mapr-loopbacknfs
if [ $? -ne 0 ]
then
	echo "Installing MapR Patch"
	sudo yum install -y ~/mapr-patch-loopbacknfs-5.0.0.32987.GA-34890.x86_64.rpm
	if [ $? -ne 0 ]
	then
		echo "yum install of patch failed."
		exit 3
	fi
fi

# Start MapR Posix Client
sudo service mapr-loopbacknfs start
sleep 10

# Mount NFS Mount

# Start Mail Application