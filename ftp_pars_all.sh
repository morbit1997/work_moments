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
            print "Date: " date " | Time: " time " | Host: " host " | Client: " client " | Status: " status >> "/root/logs/parsed_log.txt"
        }
    }
}' /root/logs/messages
