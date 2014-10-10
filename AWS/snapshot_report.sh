#!/bin/bash
#
#	reports about snapshots for volumes mounted on the instance 
#	assumes interesting volumes are tagged with $TAG
#	rpizzi@blackbirdit.com
#
TAG="Cluster"
#
yesterday=$(date --date yesterday "+%Y-%m-%d")
today=$(date --date today "+%Y-%m-%d")
instance_id=$(wget -qO- http://169.254.169.254/latest/meta-data/instance-id)
for vol_id in $(ec2-describe-volumes --filter attachment.instance-id=$instance_id | grep ^VOLUME | cut -f 2)
do
	thistag=$(ec2-describe-volumes --filter attachment.instance-id=$instance_id --filter volume-id=$vol_id | grep ^TAG | fgrep "$TAG" | cut -f 5)
	[ "$thistag" = "" ] && continue # assuming root disk since untagged
	last=$(ec2-describe-snapshots -o self --filter "volume-id=$vol_id" --filter "status=completed" | cut -f 5 | sort -r | head -1 | cut -d"T" -f 1)
	case "$last" in
		'') last="NEVER"; status="ERROR";;
		$yesterday) last="YESTERDAY"; status="OK";;
		$today) last="TODAY"; status="OK";;
		*) status="ERROR";;
	esac
	printf "%s: last successful snapshot for %s %s was %s\n" "$status" "$vol_id" "($thistag)" "$last"
done
exit 0
