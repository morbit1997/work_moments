#!/bin/bash

awk '{
    for (i=1; i<=NF; i++) {
	if ($i == "pure-ftpd:") {
    	    date = $1 " " $2
            time = $3
            host = $4
            client = $(i+1)
            status = $(i+3)
            for (j=i+5; j<=NF; j++) {
        	status = status " " $j
            }
            logs[client] = logs[client] date " | Time: " time " | Host: " host " | Status: " status "\n"
        }
    }
}
END {
    for (client in logs) {
	print "Client: " client "\n" logs[client] > "/root/logs/" client ".txt"
    }
}' /root/logs/messages
                                                                            