#!/bin/zsh
#
# Copyright 2020 BMC Software, sberry@bmc.com
#   All Rights Reserved, etc.
#
if [ -d /usr/bin ]; then
	echo "folder is there"
	exit 0
else 
	echo "folder not found, not working."
	exit 1
fi

