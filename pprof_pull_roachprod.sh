#!/bin/bash
# run this script with node IDs or `all` as an argumemt
#

if [[ $# -eq 0 ]]; then
	echo "arugment must be one or more NODE numbers. Or all for all nodes"
	echo "examples: "
	echo "single node: 1"
	echo "more than one: 1 2 3 4"
	echo "or all: all"
    exit 2
fi

sleep 1800
export PATH=./:$PATH

#token=$(cockroach auth-session login root --format=records 2>&1 | grep "authentication cookie" | sed 's/authentication cookie |//')

STARTDATE=$(date +%Y-%m-%d_%H.%M)
outputdir=pprof_files\_$STARTDATE
for nodeID in "$@"
do
	if [[ "$nodeID" = "all" ]]; then
		nodeID=""
		echo "pulling pprof for ALL nodes"
	fi
	for line in $(cockroach node status $nodeID --insecure | awk '{ OFS = "," ; split($2,addr,":") ; split($9,loc,",")  ; print $1 , addr[1] , addr[2] , loc[2] }')
	do
		IFS="," read node ipaddr port loc<<< "$line"
		if [[ ! $node =~ ^[0-9]+$ ]]
		then
			mkdir -pv ./$outputdir
			continue
		fi
		now=$(date +"%Y%m%d_%H%M")
		# comment out one or the other if necessary
		echo "pulling cpu profile for node $node ($ipaddr)"
		ssh -oLogLevel=ERROR -oUserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ipaddr "curl --output -  http://127.0.0.1:26258/debug/pprof/profile?seconds=15" > ./$outputdir/cpu_prof_n$node\_$now.pprof
		echo "pulling heap for node $node ($ipaddr)"
		ssh -oLogLevel=ERROR -oUserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ipaddr "curl -s --output -  http://127.0.0.1:26258/debug/pprof/heap" > ./$outputdir/heap_n$node\_$now.pprof
		echo "pulling go routines for node $node ($ipaddr)"
		ssh -oLogLevel=ERROR -oUserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ipaddr "curl -s --output -  http://127.0.0.1:26258/debug/pprof/goroutine?debug=2" > ./$outputdir/go_routines_n$node\_$now.pprof
#		echo "pulling closedts sender from node : $node"
#		ssh -oLogLevel=ERROR -oUserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ipaddr "curl -s --output - -k --cookie \"$token\" https://127.0.0.1:26258/debug/closedts-sender" > ./$outputdir/closed_tssender_n$node\_$now
#		echo "pulling range reports for $node ($ipaddr)"	
#		ssh -oLogLevel=ERROR -oUserKnownHostsFile=/dev/null -o StrictHostKeyChecking=no ubuntu@$ipaddr "curl -s --output - -k --cookie \"$token\" https://127.0.0.1:26258/_status/ranges/local" > ./$outputdir/range_report_n$node\_$now
	done
done
tar czvf ./cluster_pprofs_$now.tar.gz ./$outputdir
echo "created ./cluster_pprofs_$now.tar.gz" 
rm -rfv ./$outputdir
