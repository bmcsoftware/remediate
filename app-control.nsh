#!/bin/nsh

#
# (c) BMC Software, Sean Berry sean_berry@bmc.com
#
# Which server is the leader is hardcoded here, and assumes that the designated leader was started first.
#   After restarting the leader, a different server will be the leader, and restart-leader won't know which
#   server that is.
#

LEADER=server1
APPS="server2 server3 server4 server5"

function start {
	echo "Starting up app servers"
	echo "Starting leader server $LEADER"
	nexec $LEADER service blappserv start
	echo "Waiting 60 sec for head start"
	sleep 60
	for app in $APPS
	do
		echo "Starting blappserv on $app"
		nexec $app service blappserv start
	done
	echo "Done starting app servers"
}

function stop {
	echo "Stopping app servers"
	for app in $APPS
	do
		echo "Stopping blappserv on $app"
		nexec $app service blappserv stop
	done
	# stop leader last to avoid forcing an election
	echo "Stopping leader server $LEADER"
	nexec $LEADER service blappserv stop
	echo "Done stopping app servers"
}

function start-leader {
	echo "Starting leader server $LEADER"
	nexec $LEADER service blappserv start
	echo "Done starting leader app server"
}

function stop-leader {
	echo "Stopping leader server $LEADER"
	nexec $LEADER service blappserv stop
	echo "Done stopping leader app server, another server will get elected leader"
}

function stop-leader {
	echo "Stopping leader server $LEADER"
	nexec $LEADER service blappserv stop
	echo "Done stopping leader app server, another server will get elected leader"
}


function check_status {
	echo "Checking for number of Appserver Processes on each appserver"
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
