#!/bin/bash
#
#	innodb_parser.sh v 1.01 for: MySQL 5.6.13
#	parses saved output of SHOW ENGINE INNODB STATUS and looks at transactions,
#	pretty printing them and highlighting critical locking situations
#	
#	usage: pipe output of the saved sample file(s) into this script
#	(C) rpizzi@blackbirdit.com
#

print_transaction() {
#	echo $transaction >> debug.log
	rlidx=$(echo "$transaction" | fgrep -b -o "row lock(s)" | cut -d":" -f 1)
	if [ "$rlidx" != "" ]
	then
		rlidx=$(expr $rlidx - 10)
		rows_locked=$(echo ${transaction:$rlidx:10} | cut -d"," -f 2)
	else
		rows_locked=0
	fi
	section1=$(echo $transaction | cut -d"|" -f 1)
	section2=$(echo $transaction | cut -d"|" -f 2)
	section3=$(echo $transaction | cut -d"|" -f 3)
	section4=$(echo $transaction | cut -d"|" -f 4)
	section5=$(echo $transaction | cut -d"|" -f 5)
	id=$(echo $section1 | cut -d " " -f 2)
	case "$section1" in
		*"PREPARED"*) 
			tm=$(echo "$section1" | cut -d " " -f 5,6)
			case "$section2" in
				"mysql tables in use"*)
					query="$section5"
					;;
				*)
					query="$section4"
					;;
			esac
			;;
		*) 
			tm=$(echo "$section1" | cut -d " " -f 4,5)
			case "$section2" in
				"mysql tables in use"*)
					query="$section5"
					;;
				*) 
					case "$section3" in
						*" init") 
							query="$section4"
							;;
						*" cleaning up") 
							query="cleaning up"
							;;
						"Trx read view"*) 
							query="cleaning up"
							;;
						*)
							query=""
							;;
					esac
					;;
			esac
			;;
	esac
	alert="OK"
	[ $rows_locked -ge 1000 ] && alert="WARNING"
	[ $rows_locked -ge 10000 ] && alert="CRITICAL"
	echo "sample #$c, id $id time $tm, locked $rows_locked rows ($alert), $query"
} 

IFS="
"
transaction=""
trsection=0
tr_start="---TRANSACTION"
tr_end="--------"
c=1
act=0
timestamp=""
havets=0
not=0
while read row
do
	if [ $trsection -eq 0 -a $havets -eq 0 ]
	then
		case "$row" in
			"END OF INNODB MONITOR"*)
				;;
			*"INNODB MONITOR"*)
				timestamp="${row:0:19}"
				havets=1
				;;
		esac
		continue
	fi
	if [ $trsection -eq  1 -a "$row" = "$tr_end" ]
	then
		if [ -n "$transaction" ]
		then
			print_transaction 
			act=$(expr $act + 1)
		fi
		c=$(expr $c + 1)
		trsection=0
		havets=0
		continue
	fi
	if [ "${row:0:14}" = "$tr_start" ]
	then
		not=0
		case "$row" in
			*"not started"*) not=1;;
		esac
		if [ $trsection -eq 0 ]
		then
			[ $act -gt 0 ] && echo "$act total active"
			echo "========================================="
			echo "Sample #$c $timestamp"
			echo "========================================="
			act=0
			trsection=1
		fi
		if [ -n "$transaction" ]
		then
			print_transaction
			act=$(expr $act + 1)
			transaction=""
		fi
	fi
	[ $trsection -eq 1 -a $not -eq 0 ] && transaction="$transaction$row|"
done
if [ -n "$transaction" ]
then
	print_transaction
	act=$(expr $act + 1)
	[ $act -gt 0 ] && echo "$act total active"
fi
exit 0
