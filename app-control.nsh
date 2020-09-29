#!/bin/nsh

#
# (c) BMC Software, Sean Berry sean_berry@bmc.com, 2020-09-29
#
# Which server is the leader is hardcoded here, and assumes that the designated leader was started first.
#   After restarting the leader, a different server will be the leader, and restart-leader won't know which
#   server that is.
#

LEADER="server1"
APPS="server2 server3 server4 server5"

# what services to stop/start
SERVICES="blappserv blprocserv blpxe bltftp"
#SERVICES="blappserv blprocserv"

function start {
	echo "======================="
	echo "Starting up app servers"
	echo "======================="
	start-leader
	echo "Waiting 60 sec for head start"
	sleep 60
	for app in $APPS
	do
		echo "	Starting $SERVICES on $app"
		for SVC in $SERVICES
		do
			nexec $app service $SVC start
		done
	done
	echo "======================="
	echo "Done starting app servers"
	echo "======================="
}

function stop {
	echo "======================="
	echo "Stopping app servers"
	echo "======================="
	for app in $APPS
	do
		echo "	Stopping $SERVICES on $app"
		for SVC in $SERVICES
                        do
                        nexec $app service $SVC stop
                done
	done
	# stop leader last to avoid forcing an election
	echo "Stopping leader server $LEADER"
	stop-leader
	echo "======================="
	echo "Done stopping app servers"
	echo "======================="
}

function start-leader {
	echo "	Starting $SERVICES on leader server $LEADER"
	for SVC in $SERVICES
		do
		nexec $LEADER service $SVC start
		done
	echo "Done starting leader app server"
}

function stop-leader {
	echo "Stopping $SERVICES on leader server $LEADER"
	for SVC in $SERVICES
        do
                nexec $LEADER service $SVC stop 
        done
	echo "Done stopping leader app server, another server will get elected leader"
	echo "... and stop-leader will no longer apply..."
}

function check_status {
	echo "======================="
	echo "Checking for number of Appserver Processes on each appserver"
	echo "======================="
	for each in $LEADER $APPS
	do
		echo "Checking $each, count of appserver processes: should be 1 or more if running..."
		nexec $each ps -auxww | grep java | grep -i com.bladelogic.om.infra.mfw.fw.BlManager | wc -l 
		echo "Checking $each, count of launcher processes: should be 1 or more if running..."
		nexec $each ps -auxww | grep java | grep -i com.bladelogic.om.infra.app.profile.AppServerLauncher | wc -l 
		echo "All java processes (more than one is fine):"
		nexec $each ps -ef | grep java | grep -v grep
	done
}

case "$1" in
    start)
        start
        ;;
    stop)
        stop
        ;;
    restart)
        stop
        start
        ;;
    restart-leader)
        stop-leader
        start-leader
        ;;
    status)
        check_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|restart-leader}"
        exit 1
        ;;
esac
