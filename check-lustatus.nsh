#!/bin/zsh
#
# Copyright 2020 BMC Software, sberry@bmc.com
#   All Rights Reserved, etc.
#

if [ -x /usr/bin/zonename ]; then
	ZONENAME="`/usr/bin/zonename`"
else
	"/usr/bin/zonename not found, running on something other than Solaris?"
fi

ZONENAME=global
if [ $ZONENAME = "global" ]; then
	echo "LiveUpgrade Status:" 
	lustatus
	# 2020.9 is the particular LU string this user was looking for
	LUSTATUS=`lustatus | grep 2020.9`
	COUNT_OF_LUS=`lustatus | grep 2020.9 | wc -l`
	if [ $COUNT_OF_LUS -ne 1 ]; then
		echo "lustatus is not ready on $HOSTNAME"
		exit 1
	else
		echo "Exactly one lu present: $LUSTATUS"
		exit 0
	fi
else
	echo "Running in a child zone: $ZONENAME"
	exit 0
fi
