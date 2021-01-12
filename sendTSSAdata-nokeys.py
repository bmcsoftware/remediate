# python
import json
import requests
import time
import subprocess
import re

# this is an example script to extract TSSA logging info from appserver logs and send it on to BMC Helix Operations Manager
#   It's potentially useful for stripping key metrics to provide to other monitoring systems. 
#
# Copyright 2020 BMC Software
#   2020-09-21 v1.0 Sean Berry sean_berry@bmc.com with tips from Thad White, Todd Brady, Cody Dean, etc.
#

dt = int(round(time.time() * 1000)) # microseconds?

print ("Timestamp is: " + str(dt))

# nexec MYAPPSERVER.bmc.com "tail -500 /opt/bmc/bladelogic/NSH/br/hostname-job1.log | grep 'Memory Monitor' | tail -1 | sed 's/^.*Used Work Item Threads: //' | sed 's/,.*$//' "

for server in "YOUR-APP-SERVER", "YOUR-APP-SERVER-2", "YOUR-APP-SERVER-3":
    print("Server: " + server)
    # your appserver logs are likely in different places, customize as needed
    for file in "/opt/bmc/bladelogic/NSH/br/appserver.log", "/opt/bmc/bladelogic/NSH/br/" + server + "-job1.log", "/opt/bmc/bladelogic/NSH/br/" + server + "-job2.log", "/opt/bmc/bladelogic/NSH/br/" + server + "-job3.log":
        print("File: " + file)
        line = subprocess.run(["/bin/nsh", "/root/get_last.nsh", server, file], stdout=subprocess.PIPE)

        #line = os.system("nsh /root/get_last.nsh hostname /opt/bmc/bladelogic/NSH/br/phx-bladepd-01-job1.log")
        # [04 Sep 2020 16:07:47,208] [Scheduled-System-Tasks-Thread-19] [INFO] [System:System:] [Memory Monitor] Total JVM (B): 4524605440,
        # Free JVM (B): 3791717008,Used JVM (B): 732888432,VSize (B): 18146349056,RSS (B): 7434936320,Used File Descriptors: 311,
        # Used Work Item Threads: 0/100,Used NSH Proxy Threads: 0/150,Used Client Connections: 0/200,
        # DB Client-Connection-Pool: 0/0/0/100/75/25,DB Job-Connection-Pool: 2/2/0/200/150/50,DB General-Connection-Pool: 1/1/0/100/75/25,Host/Appserver/Version: phx-bladepd-01/phx-bladepd-01-job1/20.02.00.31

        if ( line.returncode != 0 ): 
            print("The exit code was: %d" % line.returncode)
            exit()

        stats = line.stdout.decode('utf-8')

        stats.strip()

        # print ("result is " + stats)
        #print()
        #print()
        #print()

        foo = stats.split(",")
        # print (foo)

        for x in foo:
            if re.search(r"Host/Appserver/Version",x):
                # print ("Host/Appserver/Version: " + x)
                hostarr = re.split('/',x)
                # print(hostarr)
                junk,hostname = hostarr[2].split(' ')
                appserver = hostarr[3]
                version = hostarr[4].strip()
                print("Host: " + hostname + ", Appserver: " + appserver + ", Version: " + version)


        # exit()

        for x in foo:
            if re.search(r"Total JVM",x):
                # print ("Total: " + x)
                totaljvm = re.findall("\d+$",x) 
                # print("TotalJVM: _" + totaljvm[0] + "_")
            elif re.search(r"Used JVM",x):
                # print ("Total: " + x)
                usedjvm = re.findall("\d+$",x) 
                # print("usedjvm: _" + usedjvm[0] + "_")    
            elif re.search(r"\[\d+ \w+ \d+ \d+:\d+:\d+",x):
                print ("date format: " + x)
            elif re.search(r"\d+/\d+",x):
        #        print ("slash numbers: " + x)

                if re.search(r"^Used Work Item Threads",x):
                    wits = re.split(r'[:/]',x)
                    usedwits = wits[1].strip()
                    print ("WorkItemThreads: _" + str(usedwits) + "_")
                    totalwits = wits[2]

                if re.search(r"^Used NSH Proxy Threads",x):
                    nshproxyt = re.split(r'[:/]',x)
                    totalnshproxyt = nshproxyt[2]
                    usednshproxyt = nshproxyt[1].strip()
                    print ("Used NSH Proxy Threads: _" + str(usednshproxyt) + "_")

                #Used Client Connections: 0/200,
                if re.search(r"^Used Client Connections",x):
                    clientconns = re.split(r'[:/]',x)
                    totalclientconns = clientconns[2]
                    usedclientconns = clientconns[1].strip()
                    print ("Used Client Connections: _" + str(usedclientconns) + "_")

            elif re.search(r"(B)",x):
                print ("(B)ytes: " + x)
            elif re.search(r"Used File Descriptors",x):
                filedescarr = re.split(r':',x)
                filedescused = filedescarr[1].strip()
                print ("Used File Descriptors: " + filedescused)
            else:
                print ("Nothing matched: " + x)

        var = 1 

        if( hostname != "" ):
            DataJSON = [
                {
                    "labels": {
                        "metricName": "TotalJVM",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":JavaHeap:TotalJVM", # host, source, entitytypeid, entityName
                        "entityTypeId": "JavaHeap",
                        "entityName": "TotalJVM",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "Bytes",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": totaljvm[0],
                            "timestamp": dt  #dt
                        }
                    ]
                },
                {
                    "labels": {
                        "metricName": "UsedJVM",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":JavaHeap:UsedJVM", # host, source, entitytypeid, entityName
                        "entityTypeId": "JavaHeap",
                        "entityName": "UsedJVM",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "Bytes",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": usedjvm[0],
                            "timestamp": dt  #dt
                        }
                    ]
                },        {
                    "labels": {
                        "metricName": "WorkItemThreadsInUse",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":Threads:WorkItemThreadsInUse", # host, source, entitytypeid, entityName
                        "entityTypeId": "Threads",
                        "entityName": "WorkItemThreadsInUse",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "each",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": usedwits,
                            "timestamp": dt
                        }
                    ]
                },
                {
                    "labels": {
                        "metricName": "NSHProxyThreadsInUse",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":Threads:NSHProxyThreadsInUse",
                        "entityTypeId": "Threads",
                        "entityName": "NSHProxyThreadsInUse",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "each",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": usednshproxyt,
                            "timestamp": dt
                        }
                    ]
                },
                {
                    "labels": {
                        "metricName": "ClientConnections",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":Connections:ClientConnections",
                        "entityTypeId": "Connections",
                        "entityName": "ClientConnections",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "each",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": usedclientconns,
                            "timestamp": dt
                        }
                    ]
                },
                {
                    "labels": {
                        "metricName": "FileDescriptorsUsed",
                        "hostname": hostname,
                        "entityId": "TSSA:" + appserver + ":FileDescriptors:FileDescriptorsUsed", 
                        "entityTypeId": "FileDescriptors",
                        "entityName": "FileDescriptorsUsed",
                        "hostType": "Server",
                        "isKpi": "True",
                        "unit": "each",
                        "source": "TSSA"
                    },
                    "samples": [
                        {
                            "value": filedescused, 
                            "timestamp": dt
                        }
                    ]
                }
            ]
            
            print("Sending to NAME's instance...")
            MyAPIKey = "KEY-GOES-HERE"
            BHOMDataAPI = "https://HOSTNAME-GOES-HERE-trial.bmc.com/metrics-gateway-service/api/v1.0/insert"
            header={'Content-type': 'application/json', 'Authorization': 'Bearer ' + MyAPIKey}
            j = requests.post( BHOMDataAPI, data=json.dumps(DataJSON), headers=header)
            if(j.status_code > 202):
                print("Failed payload %s" % DataJSON)
                print("Status: %s reason %s" % (j.status_code,j.reason))
                print("Details: %s" % j.text)
            else:
                print("Posted, status was: " + str(j.status_code))
                print("Detailed payload %s" % DataJSON)
                # print(j)
