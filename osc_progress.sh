#!/bin/bash
#
#   shows real progress of an online schema change session
#   works when PK is a numeric autoinc column
#   uses current user to log to the DB; you can specify the user running the OSC as an argument,
#   if different than the user running this script (eg. if you want to run this on a slave)
#
#   Author: rick.pizzi@mariadb.com
#
#   March 2020: added ETA indicator (and it works properly, unlike the pt-osc one!)
#
#
EST_PREC=30
#
[ "$1" != "" ] && OSC_USER=$1 || OSC_USER=$USER
#
echo -n "Getting OSC information... "
while true
do
	row=$(echo "select * from information_schema.processlist where user = '"$OSC_USER"' and info like 'INSERT LOW%'" | mysql -AN -u $USER 2>/dev/null | sed -e "s/\`//g")
	[ "$row" != "" ] && break
	sleep 1
done
echo "done."
table=$(echo $row | grep -oP '(?<=FROM\s)\w+\.\w+' | uniq)
table_schema=$(echo $table | cut -d"." -f1)
table_name=$(echo $table | cut -d"." -f2)
pk=$(echo $row | grep -oP '(?<=WHERE\s\(\()\w+' | uniq)
pksize=$(echo "select count(*)  from information_schema.columns where table_schema = '"$table_schema"' and table_name = '"$table_name"' and column_key = 'PRI'" | mysql -AN -u $USER 2>/dev/null)
coltype=$(echo "select data_type from information_schema.columns where table_schema = '"$table_schema"' and table_name = '"$table_name"' and column_name = '"$pk"'" | mysql -AN -u $USER 2>/dev/null)
case "$coltype" in
        'int'|'bigint') ;;
        *) echo "sorry, this script only works when PK is an integer"; exit 1;;
esac
pval=0
declare -a speed
while true
do
        target=$(echo "select $pk from $table order by 1 desc limit 1" | mysql -AN -u $USER 2>/dev/null)
        if [ $pksize -eq 1 ]
        then
		curr=$(echo "select  substring_index(substring_index(right(info, 100), '<= \'', -1), '\')', 1)  from information_schema.processlist where user = '"$OSC_USER"' and info like 'INSERT LOW%'" | mysql -AN -u $USER 2>/dev/null)
        else
        	curr=$(echo "select  substring_index(substring_index(right(info, 200), '= \'', -2), '\')', 1)  from information_schema.processlist where user = '"$OSC_USER"' and info like 'INSERT LOW%'" | mysql -AN -u $USER 2>/dev/null | cut -d"'" -f 1)
        fi
        if [ "$curr" = "" ]
        then
            sleep 2
        else
            percd=$(echo "scale=6; $curr / $target " | bc)
	    perc=$(echo "scale=2; $percd * 100" | bc)
	    cval=$(expr $(echo $percd | tr -d ".") + 0)
	    if [ $pval -gt 0 ]
	    then
	    	pmin=$(((cval-pval)*2))
		if [ "${speed[$((EST_PREC-1))]}" != "" ]
		then
		    n=0
		    avg=$(for i in $(seq 0 1 $((EST_PREC-1)))
		    do
		        [ $i -eq 0 ] && echo -n "scale=4; (0"
		        if [ "${speed[$i]}" != "" ]
		        then
			    echo -n "+${speed[$i]}"
			    n=$((n+1))
		        fi
		        [ $i -eq $((EST_PREC-1)) ] && echo ")/$n"
		    done | bc)
		fi
		if [ "$avg" != "" ]
		then
		    tr=$(echo "(1000000-$cval)/$avg" | bc)
		    #echo "curr $pmin avg $avg tr $tr cval $cval"
		    ed=$((tr/1440))
		    eh=$(((tr-ed*1440)/60))
		    em=$((tr-eh*60-ed*1440))
		    /usr/bin/printf "%s: %s/%s (%.2f%%) ETA: %dd%02dh%02dm\n" $table $curr $target $perc $ed $eh $em
		else
            	    /usr/bin/printf "%s: %s/%s (%.2f%%) ETA: estimating...\n" $table $curr $target $perc $ed $eh $em
		fi
		for i in $(seq 0 1 $((EST_PREC-2)))
		do
			speed[$i]=${speed[$((i+1))]}
		done
	        speed[$((EST_PREC-1))]=$pmin
	    else
            	    /usr/bin/printf "%s: %s/%s (%.2f%%) ETA: estimating...\n" $table $curr $target $perc $ed $eh $em
	    fi
	    pval=$cval
            sleep 30
        fi
done
exit 0

