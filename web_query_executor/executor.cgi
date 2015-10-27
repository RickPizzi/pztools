#!/bin/bash
#
#	web query executor
#	riccardo.pizzi@rumbo.com Jan 2015
#
VERSION="1.1.8"
BASE=/usr/local/executor
#
set -f
post=0
dryrun=0
db=""
kill_backq=0
default_db=""
closing_tags="</FONT></BODY></HTML>"
total_warnings=0
total_errors=0
tmpf=/tmp/executor.$$
warnings_tmpf=/tmp/executor.warn.$$
errors_tmpf=/tmp/executor.err.$$
output_tmpf=/tmp/executor.out.$$
cached_db_tmpf=/tmp/executor.cdb.$$
dump_tmpf=/tmp/executor.dmp.$$
trap 'rm -f $tmpf $warnings_tmpf $errors_tmpf $output_tmpf $cached_db_tmpf $dump_tmpf' 0

unescape_input()
{
	echo "$1" | sed -e "s/%40/@/g" -e "s/%21/!/g" -e "s/%3F/?/g" -e "s/%60/\`/g" -e "s/+/ /g" -e "s/%3D/=/g" -e "s/%2B/+/g" -e "s/%3B/;/g" -e "s/%27/'/g" -e "s/%3A/:/g" -e "s/%28/(/g" -e "s/%29/)/g" -e "s/%2C/,/g" -e "s/%23/#/g" -e "s/%22/\"/g" -e "s/%3C/</g" -e "s/%2F/\//g" -e "s/%3E/>/g" -e "s/%26/\&/g" -e "s/%7B/{/g" -e "s/%7D/}/g" -e "s/%5B/[/g" -e "s/%5D/]/g" -e "s/%5C/\\\/g" -e "s/%25/%/g" -e "s/%7C/|/g" -e "s/%09/ /g" -e "s/%7E/~/g" -e "s/%80/\\x80/g" -e "s/%81/\\x81/g" -e "s/%82/\\x82/g" -e "s/%83/\\x83/g" -e "s/%84/\\x84/g" -e "s/%85/\\x85/g" -e "s/%86/\\x86/g" -e "s/%87/\\x87/g" -e "s/%88/\\x88/g" -e "s/%89/\\x89/g" -e "s/%8A/\\x8A/g" -e "s/%8B/\\x8B/g" -e "s/%8C/\\x8C/g" -e "s/%8D/\\x8D/g" -e "s/%8E/\\x8E/g" -e "s/%8F/\\x8F/g" -e "s/%90/\\x90/g" -e "s/%91/\\x91/g" -e "s/%92/\\x92/g" -e "s/%93/\\x93/g" -e "s/%94/\\x94/g" -e "s/%95/\\x95/g" -e "s/%96/\\x96/g" -e "s/%97/\\x97/g" -e "s/%98/\\x98/g" -e "s/%99/\\x99/g" -e "s/%9A/\\x9A/g" -e "s/%9B/\\x9B/g" -e "s/%9C/\\x9C/g" -e "s/%9D/\\x9D/g" -e "s/%9E/\\x9E/g" -e "s/%9F/\\x9F/g" -e "s/%A0/\\xA0/g" -e "s/%A1/\\xA1/g" -e "s/%A2/\\xA2/g" -e "s/%A3/\\xA3/g" -e "s/%A4/\\xA4/g" -e "s/%A5/\\xA5/g" -e "s/%A6/\\xA6/g" -e "s/%A7/\\xA7/g" -e "s/%A8/\\xA8/g" -e "s/%A9/\\xA9/g" -e "s/%AA/\\xAA/g" -e "s/%AB/\\xAB/g" -e "s/%AC/\\xAC/g" -e "s/%AD/\\xAD/g" -e "s/%AE/\\xAE/g" -e "s/%AF/\\xAF/g" -e "s/%B0/\\xB0/g" -e "s/%B1/\\xB1/g" -e "s/%B2/\\xB2/g" -e "s/%B3/\\xB3/g" -e "s/%B4/\\xB4/g" -e "s/%B5/\\xB5/g" -e "s/%B6/\\xB6/g" -e "s/%B7/\\xB7/g" -e "s/%B8/\\xB8/g" -e "s/%B9/\\xB9/g" -e "s/%BA/\\xBA/g" -e "s/%BB/\\xBB/g" -e "s/%BC/\\xBC/g" -e "s/%BD/\\xBD/g" -e "s/%BE/\\xBE/g" -e "s/%BF/\\xBF/g" -e "s/%C0/\\xC0/g" -e "s/%C1/\\xC1/g" -e "s/%C2/\\xC2/g" -e "s/%C3/\\xC3/g" -e "s/%C4/\\xC4/g" -e "s/%C5/\\xC5/g" -e "s/%C6/\\xC6/g" -e "s/%C7/\\xC7/g" -e "s/%C8/\\xC8/g" -e "s/%C9/\\xC9/g" -e "s/%CA/\\xCA/g" -e "s/%CB/\\xCB/g" -e "s/%CC/\\xCC/g" -e "s/%CD/\\xCD/g" -e "s/%CE/\\xCE/g" -e "s/%CF/\\xCF/g" -e "s/%D0/\\xD0/g" -e "s/%D1/\\xD1/g" -e "s/%D2/\\xD2/g" -e "s/%D3/\\xD3/g" -e "s/%D4/\\xD4/g" -e "s/%D5/\\xD5/g" -e "s/%D6/\\xD6/g" -e "s/%D7/\\xD7/g" -e "s/%D8/\\xD8/g" -e "s/%D9/\\xD9/g" -e "s/%DA/\\xDA/g" -e "s/%DB/\\xDB/g" -e "s/%DC/\\xDC/g" -e "s/%DD/\\xDD/g" -e "s/%DE/\\xDE/g" -e "s/%DF/\\xDF/g" -e "s/%E0/\\xE0/g" -e "s/%E1/\\xE1/g" -e "s/%E2/\\xE2/g" -e "s/%E3/\\xE3/g" -e "s/%E4/\\xE4/g" -e "s/%E5/\\xE5/g" -e "s/%E6/\\xE6/g" -e "s/%E7/\\xE7/g" -e "s/%E8/\\xE8/g" -e "s/%E9/\\xE9/g" -e "s/%EA/\\xEA/g" -e "s/%EB/\\xEB/g" -e "s/%EC/\\xEC/g" -e "s/%ED/\\xED/g" -e "s/%EE/\\xEE/g" -e "s/%EF/\\xEF/g" -e "s/%F0/\\xF0/g" -e "s/%F1/\\xF1/g" -e "s/%F2/\\xF2/g" -e "s/%F3/\\xF3/g" -e "s/%F4/\\xF4/g" -e "s/%F5/\\xF5/g" -e "s/%F6/\\xF6/g" -e "s/%F7/\\xF7/g" -e "s/%F8/\\xF8/g" -e "s/%F9/\\xF9/g" -e "s/%FA/\\xFA/g" -e "s/%FB/\\xFB/g" -e "s/%FC/\\xFC/g" -e "s/%FD/\\xFD/g" -e "s/%FE/\\xFE/g" -e "s/%FF/\\xFF/g" -e "s/&#39;/\\\'/g"
}

unescape_textarea()
{
	if [ $kill_backq -eq 0 ]
	then
		unescape_input "$1" | sed -e "s/%0D%0A/\n/g"
	else
		unescape_input "$1" | sed -e "s/%0D%0A/\n/g" -e "s/\`\.\`/./g" -e "s/\`/ /g"
	fi
}

unescape_execute()
{
	unescape_input "$1" | sed -e "s/%0D%0A/ /g"
}

escape_html()
{
	echo "$1" | sed -e "s/&/&amp;/g" -e "s/\\\/\&#92;/g"
}

display() {
	case "$2" in
		0) echo "$1" >> $output_tmpf;;
		1) echo "<FONT COLOR=\"Red\">ERROR: $1</FONT>" >> $output_tmpf;;
		2) echo "<FONT COLOR=\"Green\">$1</FONT>" >> $output_tmpf;;
		3) echo "<FONT COLOR=\"Orange\">$1</FONT>" >> $output_tmpf;;
	esac
}

debug() {
	d_text=$(echo "$1" | od -va)
	echo ="<BR>DEBUG:<BR>$d_text<BR>"  >> $output_tmpf;
	echo "$1" >> /usr/local/executor/log/debug.log
}

mysql_debug()
{
	echo "$1" >> /usr/local/executor/log/mysql_debug.log
}

connection_setup()
{
	coproc mysqlc { mysql -ANnfrvv -u "$user" -p"$password" -h "$host" "$default_db" 2>&1; } 
	mysql_query "BEGIN" > /dev/null
	mysql_query "SET NAMES utf8" > /dev/null
}

mysql_query()
{
	sw=0
	rm -f $errors_tmpf
	thisquery="${1/# /}"
	[ "${1,,}" == "show warnings" ] && sw=1
	skip=0
	error=0
	warning_text=""
	qtype=$(echo ${thisquery,,} | cut -d" " -f 1)
	if [ $sw -eq 0 -a "$2" != "" -a "$2" != "$(cat $cached_db_tmpf 2>/dev/null)" ] 
	then
		echo "use $2;"  >&${mysqlc[1]}
		mysql_debug "mysql>use $2;"
		echo "$2" > $cached_db_tmpf
	fi
	echo "$thisquery;" >&${mysqlc[1]}
	mysql_debug "mysql>$thisquery;"
	while read -u ${mysqlc[0]} row
	do
		if [ "$row" = "--------------" ]
		then
			case $skip in
				0) skip=1;;
				1) skip=0;;
			esac
			continue
		fi
		[ $skip -eq 1 ] && continue
		[ "$row" = "" ] && continue
		#echo "loop: $sw $thisquery  \"$row\"" >> /tmp/loop_debug.log
		case $sw in
			0)
				case "$qtype" in
					'use')
							echo "$row"
							mysql_debug "$row"
							[[ $row == *"Database changed"* ]] && break
							;;
					'update')
							echo "$row"
							mysql_debug "$row"
							[[ $row == *"Rows matched:"* ]] && break
							;;
					'select'|'show')
							[[ $row == *"Empty set"* ]] && break
							[[ $row == *"row"*"in set"* ]] && break
							[[ $row == "ERROR "* ]] && break
							echo "$row"
							mysql_debug "$row"
							;;
					*)
							echo "$row"
							mysql_debug "$row"
							[[ $row == *"row"*"affected"* ]] && break
							;;
				esac
				;;
			1)
				[[ $row == *"Empty set"* ]] && break
				[[ $row == *"row"*"in set"* ]] && break
				echo "$row"
				mysql_debug "$row"
				;;
		esac
		[[ $row == "ERROR "* ]] && break
	done
	#echo "loop: $sw $thisquery  **EXIT**" >> /tmp/loop_debug.log
	if [[ $row == "ERROR "* ]]
	then
		mysql_debug "$row"
		echo "$row" > $errors_tmpf
		error=1
		return
	fi
	if [ $sw -eq 0 -a $error -eq 0 ]
	then
		case "$qtype" in
			'begin'|'use'|'show'|'select'|'set'|'commit'|'rollback'|'create')
				;;
			*)
				qtypebuf="$qtype"
				warning_text=$(mysql_query "SHOW WARNINGS")
				echo $warning_text | grep -v ^Records > $warnings_tmpf
				qtype="$qtypebuf"
				;;
		esac
	fi
}

consistent_dump()
{
	mysql_query "SELECT * FROM $1.$2 WHERE $3 /* cdump */" > $dump_tmpf
	if [ -s $dump_tmpf ]
	then
		nl=$(cat $dump_tmpf | wc -l)
		nt=$(cat $dump_tmpf | tr -dc "\t" | wc -c)
		if [ $((nt % nl)) -gt 0 ]
		then
			echo "-- WARNING: column count does not match for all rows in the rollback code below."
			echo "-- WARNING: very likely you have one or more rows with columns containing tabs in it."
		fi
		cat  $dump_tmpf | sed -e "s/	/','/g" -e "s/^/INSERT INTO $2 VALUES ('/g" -e "s/$/');/g" -e "s/'NULL'/NULL/g"
	fi
}

show_form()
{
	printf "<FONT SIZE=2>Executor version: $VERSION<BR></FONT><BR>"
	printf "<FORM METHOD=\"POST\" ACTION=\"$SCRIPT_NAME\" accept-charset=\"UTF-8\">\n"
	printf "<TABLE>\n"
	printf "<TR><TD>Host:</TD><TD><INPUT TYPE=TEXT NAME=\"host\" VALUE=\"$host\" MAXLENGTH=36 SIZE=16></TD></TR>\n"
	printf "<TR><TD>User:</TD><TD><INPUT TYPE=TEXT NAME=\"user\" VALUE=\"$user\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Password:</TD><TD><INPUT TYPE=PASSWORD NAME=\"password\" VALUE=\"$password\" MAXLENGTH=40 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Schema:</TD><TD><INPUT TYPE=TEXT NAME=\"schema\" VALUE=\"$default_db\" MAXLENGTH=32 SIZE=32></TD></TR>\n"
	printf "<TR><TD>Ticket #:</TD><TD><INPUT TYPE=TEXT NAME=\"ticket\" VALUE=\"$ticket\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	if [ $kill_backq -eq 0 ]
	then
		printf "<TR><TD>Remove backquotes:</TD><TD><INPUT TYPE=CHECKBOX NAME=\"backq\"></TD></TR>\n" 
	else
		printf "<TR><TD>Remove backquotes:</TD><TD><INPUT TYPE=CHECKBOX NAME=\"backq\" VALUE=\"on\" CHECKED></TD></TR>\n" 
	fi
	[ $dryrun -eq 1 ] && textarea=$(escape_html "$(unescape_textarea $query)")
	printf "<TR><TD COLSPAN=2><TEXTAREA NAME=\"query\" ROWS=8 COLS=200>%s</TEXTAREA></TD></TR>\n" "$textarea"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TR><TD COLSPAN=2><B><PRE>%s</PRE></B></TD></TR>\n" "$(cat $output_tmpf)"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	[ $dryrun -eq 1 ] && checkbox="CHECKED"
	printf "<TR><TD>Dry Run:</TD><TD ALIGN=LEFT><INPUT TYPE=CHECKBOX NAME=\"dryrun\" VALUE=\"on\" %s></TD></TR>\n" "$checkbox"
	printf "<TR><TD COLSPAN=2><INPUT TYPE=\"SUBMIT\" VALUE=\"Execute\">\n"
	printf "</TABLE>\n"
	printf "</FORM>\n"
}

log()
{
	ts=$(date "+%Y-%m-%d %T")
	printf "%s %-10s %-16s %-10s %-20s %s\n" "$ts" "$ticket" "$user" "$host" "$db" "$1" >> $BASE/log/executor.log
}

post_checks()
{
	post_error=0
	echo "x" > $BASE/log/.fscheck
	x=$(cat $BASE/log/.fscheck)
	if [ "$x" != "x" ] 
	then
		display "FILE SYSTEM FULL, cannot operate" 1
		post_error=1
		return
	fi
	if [ "$host" = "" ] 
	then 
		display "Please specify a server" 1
		post_error=1
		return
	fi
	if [ "$user" = "" ]
	then
		display "Please specify your user" 1
		post_error=1
		return
	fi
	if [ "$user" = "root" ]
	then
		display "Root access is not allowed" 1
		post_error=1
		return
	fi
	if [ "$password" = "" ]
	then
		display "Please specify your password" 1
		post_error=1
		return
	fi
	password=$(unescape_input "$password")
	err=$(mysqladmin -u "$user" -p"$password" -h"$host" ping 2>&1 | fgrep error | cut -d":" -f2-)
	if [ "$err" != "" ]
	then
		display "$err" 1
		post_error=1
		return
	fi
	if [ "$(echo "show variables like 'read_only'" | mysql -ANr -u "$user" -p"$password" -h"$host" 2>&1 | cut -f 2)" != "OFF" ]
	then
		display "This instance is READ ONLY" 1
		post_error=1
		return
	fi
	if [ "$default_db" != "" ]
	then
		res=$(mysql -u "$user" -p"$password" -h"$host" "$default_db" 2>&1)
		if [ "$res" != "" ]
		then
			display "$res" 1
			post_error=1
		fi
	fi
}

run_statement()
{
	error=0
	result=$(mysql_query "$1" "$db")
	warning_text=$(cat $warnings_tmpf)
	error_text=$(cat $errors_tmpf 2>/dev/null)
	[ "$warning_text" != "" ] && total_warnings=$((total_warnings+1))
	if [ "$error_text" != "" ]
	then
		error=1
		total_errors=$((total_errors+1))
	fi
	case $(echo ${1,,} | cut -d" " -f 1) in
		'insert'|'replace') 
			[ $2 -eq 0 -a $auto_increment -eq 1 ] && q_last_id=$(mysql_query "SELECT LAST_INSERT_ID()") || q_last_id=0
			;;
		*)
			q_last_id=0
			;;
	esac	
	if [ $error -eq 1 ]
	then
		case $2 in
			0)
				display "$result" 1
				display "$warnings" 3
				;;
			1) 	
				display "<BR>DRY RUN RESULT: $error_text" 1
				;;
				
		esac
	else
		last_id=$q_last_id
		case $2 in
			0)	display "$result" 2
				display "$warnings" 3
				log "$1"
				;;
			1) 	display "<BR>DRY RUN RESULT:<BR>$result<BR>$warning_text" 3
				;;
		esac
	fi
}

array_idx()
{
	idx=-1
	c=0
	a=("$1")
	for arg in ${a[@]}
	do
		if [ "${arg,,}" = "$2" ]
		then
 			idx=$c
			break
		fi
		c=$(($c + 1))
	done
	echo $idx
}

check_key()
{
	c=0
	a=("$1")
	for arg in ${a[@]}
	do
		display "$c $arg" 0
		c=$((c + 1))
	done
}

num_rows()
{
	[ "$nr_cache" = "$db.$table" ] && return
	rows=$(mysql_query  "SELECT TABLE_ROWS FROM information_schema.tables WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'")
	nr_cache="$db.$table"
}

replace_rollback()
{
	saveIFS="$IFS"
	case "$3" in
		0) 	rr_col_names=($(echo "$1" | cut -d "(" -f 2 | cut -d ")" -f 1 | sed -e "s/,/, /g" | tr -d ","))
			rr_q="$1"
			;;
		1) 	
			if [ "$rr_cache1" != "$db.$table" ] 
			then
				rr_col_names_c=$(mysql_query "SELECT GROUP_CONCAT(COLUMN_NAME) FROM information_schema.COLUMNS WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'") 
				rr_cache1="$db.$table"
			fi
			rr_col_names=($(echo $rr_col_names_c | tr "," " "))
			rr_q=$(echo "$1" | sed -e "s/VALUES/($rr_col_names_c) values/gi")
			;;
	esac
	if [ "$rr_cache2" != "$db.$table" ]
	then
		rr_unique=$(mysql_query "SELECT CONSTRAINT_NAME FROM information_schema.TABLE_CONSTRAINTS WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table' AND CONSTRAINT_TYPE='UNIQUE' LIMIT 1")
		if [ "$rr_unique" != "" ]
		then
			rs=$(mysql_query "SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_NAME = '$rr_unique' AND TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'")
			rr_ukeys=($(echo "$rs" | tr "\n" " "))
		else
			unset rr_ukeys
		fi
		rs=$(mysql_query "SELECT COLUMN_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE CONSTRAINT_NAME = 'PRIMARY' AND TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'")
		rr_keys=($(echo "$rs" | tr "\n" " "))
		if [ "$rr_keys" = "" -a "$rr_unique" = "" ]
		then
			echo "-- The table lacks an unique index. Rollback is not possible."
			return
		fi
		IFS="	"
		rr_nkeys=${#rr_keys[@]}
		rr_nukeys=${#rr_ukeys[@]}
		rr_nkeys_used=0
		rr_nukeys_used=0
		for arg in ${rr_col_names[@]}
		do
			nobq="${arg//\`}"
			for arg2 in ${rr_keys[@]} 
			do
				[ "${nobq,,}" = "${arg2,,}" ] && rr_nkeys_used=$((rr_nkeys_used + 1))
			done
			for arg2 in ${rr_ukeys[@]} 
			do
				[ "${nobq,,}" = "${arg2,,}" ] && rr_nukeys_used=$((rr_nukeys_used + 1))
			done
		done
		rr_cache2="$db.$table"
	fi
	echo "-- Rollback instructions for query $qc"
	echo "SET NAMES utf8;"
	if [ $rr_nkeys != $rr_nkeys_used -a $auto_increment -eq 0 ]
	then
		if [ "$rr_unique" = "" ]
		then
			echo "-- $2 is not using primary key fully (cols needed $rr_nkeys, used $rr_nkeys_used). Rollback not possible"
			return
		else
			if [ $rr_nukeys != $rr_nukeys_used ]
			then
				echo "-- $2 is not using unique index fully (cols needed $rr_nukeys, used $rr_nukeys_used). Rollback not possible"
				return
			fi
		fi
	fi
	rr_using_primary=0
	[ $rr_nkeys -eq $rr_nkeys_used ] && rr_using_primary=1
	[ $auto_increment -eq 1  ] && rr_using_primary=1
	# if both primary key and unique index are available, prefer unique index for rollback
	[ $rr_nukeys -gt 0 -a $rr_nukeys -eq $rr_nukeys_used ] && rr_using_primary=0
	#echo "-- DEBUG: keys=$rr_nkeys used=$rr_nkeys_used ukeys=$rr_nukeys used=$rr_nukeys_used using_primary=$rr_using_primary"
	# special case: autoinc pk and no unique index
	if [ $replace -eq 0 -a $rr_using_primary -eq 1 -a $auto_increment -eq 1 ]
	then
		case $dryrun in
			0)
				[ "$db" != "" ] && echo "USE $db" 
				get_pk
				echo "DELETE FROM $table WHERE $pk = '$last_id';"
				return
				;;
			1)
				if [ $dryrun -eq 1 -a $auto_increment -eq 1 ]
				then
					echo "-- auto_increment PK detected, rollback will be available after execution: ${1:0:60}..." 
					return
				fi
				;;
		esac
	fi
	IFS="
"
	for rr_row in $(echo "$rr_q" | cut -d ")" -f2- | sed -e "s/ VALUES //ig" -e "s/ VALUES(/(/ig" -e "s/ VALUES$//ig" -e "s/),(/\x0a/g"  -e "s/^ *(//g"  -e "s/), *(/\x0a/g" -e "s/) *, *(/\x0a/g" -e "s/) *;*$//g" | tr "," "\t")
	do
		IFS="	"
		rr_col_values=($rr_row)
		rr_idx=0
		rr_kc=0
		rr_where=""
		while true
		do
			[ $rr_idx -eq ${#rr_col_names[@]} ] && break
			case $rr_using_primary in
				0)
					for arg in ${rr_ukeys[@]} 
					do
						nobq="${rr_col_names[$rr_idx]//\`}"
						if [ "${nobq,,}" = "${arg,,}" ]
						then
							[ $rr_kc -gt 0 ] && rr_where="$rr_where AND"
							rr_where="$rr_where ${rr_col_names[$rr_idx]} = ${rr_col_values[$rr_idx]}"
							rr_kc=$((rr_kc + 1))
						fi
					done
					;;
				1)
					for arg in ${rr_keys[@]} 
					do
						nobq="${rr_col_names[$rr_idx]//\`}"
						if [ "${nobq,,}" = "${arg,,}" ]
						then
							[ $rr_kc -gt 0 ] && rr_where="$rr_where AND"
							rr_where="$rr_where ${rr_col_names[$rr_idx]} = ${rr_col_values[$rr_idx]}"
							rr_kc=$((rr_kc + 1))
						fi
					done
					;;
			esac
			rr_idx=$((rr_idx + 1))
		done
		echo "DELETE FROM $table WHERE $rr_where;"
		[ $replace -eq 1 ] && consistent_dump "$db" "$table" "$rr_where" 0
		IFS="
"
	done
}

get_pk()
{
	[ "$pk_cache" = "$db.$table" ] && return
	rs=$(mysql_query "SHOW INDEX FROM $db.$table WHERE KEY_NAME = 'PRIMARY'" "$db")
	pk=$(echo "$rs" | cut -f 5 | tr "\n" " " | sed -e "s/ $//g")
	pk_cache="$db.$table"
}
			
check_autoincrement()
{
	[ "$ai_cache" = "$db.$table" ] && return
	auto_increment=$(mysql_query "SELECT IF(COUNT(*) = 1, 1, 0) FROM information_schema.columns WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table' AND EXTRA = 'auto_increment'")
	ai_cache="$db.$table"
}
			
index_name()
{
	[ "$in_cache" = "$db.$table.$1" ] && return
	idxname=$(mysql_query "SELECT CONSTRAINT_NAME FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table' AND COLUMN_NAME = '$1' AND REFERENCED_COLUMN_NAME IS NULL")
	in_cache="$db.$table.$1"
}

index_parts()
{
	[ "$ip_cache" = "$db.$table.$1" ] && return
	idxcount=$(mysql_query "SELECT COUNT(*) FROM information_schema.KEY_COLUMN_USAGE WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table' AND CONSTRAINT_NAME = '$1'")
	ip_cache="$db.$table.$1"
}

check_pk_use()
{
	pk_in_use=1
	wa=($(echo "$1" | sed -e "s/, /,/g"))
	c=0
	for arg in ${wa[@]}
	do
		warg=$(echo $arg | cut -d"=" -f 1)
		for parg in $pk
		do
			if [ "${parg,,}" = "${warg,,}" ]
			then
				c=$(($c + 1))
				break
			fi
		done
	done
	[ $c -lt $2 ] && pk_in_use=0
}

check_table_presence()
{
	table_present=1
	if [ $(echo $table | fgrep -c "." ) -eq 0 ]
	then
		if [ "$default_db" = "" ]
		then
			display "Default schema not set" 1
			table_present=0
			return
		else
			db=$default_db
		fi
	else
		st=$table	
		db=$(echo $st | cut -d"." -f 1)
		table=$(echo $st | cut -d"." -f 2)
	fi
	[ "$ctp_cache" = "$db.$table" ] && return
	there=$(mysql_query "SELECT COUNT(*) FROM information_schema.tables WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME= '$table'")
	if [ $there -eq 0 ]
	then
		display "No table named \"$table\" in schema \"$db\"" 1
		table_present=0
		return
	else
		ctp_cache="$db.$table"
	fi
}

check_columns()
{
	[ "$cc_cache" = "$db.$table.$1" ] && return
	columns_ok=1
	for arg in $1
	do
		[ $(echo $arg | fgrep -c ".") -gt 0 ] && arg=$(echo $arg | cut -d"." -f 2)
		cc=$(mysql_query "SELECT COUNT(*) FROM information_schema.columns WHERE TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table' AND COLUMN_NAME = '$arg'")
		if [ $cc -eq 0 ]
		then
			display "Column \"$arg\" does not exist" 1
			columns_ok=0
			return
		fi
	done
	cc_cache="$db.$table.$1"
}

rollback_args()
{
	echo -n "CONCAT("
	c=0
	for arg in $1
	do
		[ $c -gt 0 ] && echo -n ",',',"
		#echo -n "'$arg=','\\\'',IF($arg IS NOT NULL,TRIM(BOTH '\'' FROM QUOTE($arg)),'NULL'),'\\\''"
		echo -n "'$arg= ', IF($arg IS NOT NULL, QUOTE($arg),'NULL')"
		c=$(($c + 1))
	done
	echo ")"
}

rollback_pkwhere()
{
	echo -n "CONCAT("
	c=0
	for arg in $1
	do
		[ $c -gt 0 ] && echo -n ",' AND ',"
		echo -n "'$arg=\'',\`$arg\`,'\''"
		c=$(($c + 1))
	done
	echo ")"
}

query_delete()
{
	total_errors=$((total_errors+1))
	display "Query type: DELETE" 0
	IFS=" " q=($1)
	query_id=$2
	if [ "${q[1],,}" != 'from'  ]
	then
		display "Syntax error near \"${q[1]}\"" 1
		return
	fi
	table="${q[2]}"
	check_table_presence
	[ $table_present -ne 1 ] && return
	c=0
	w=0
	dml=""
	for arg in ${q[@]}
	do
		if [ $c -ge 3 ]
		then
			if [ "${arg,,}" = "where" ]
			then
				w=$c
				break
			fi
			dml="$dml$arg"
		fi
		c=$(($c + 1))
	done
	if [ $w -eq 0 ]
	then
		display "DELETE without WHERE is not allowed" 1
		return
	fi
	c=0
	where=""
	for arg in ${q[@]}
	do
		if [ $c -gt $w ]
		then
			where="$where $arg"
		fi
		c=$(($c + 1))
	done
	display "Schema: $db" 0
	display "Table: $table" 0
	whd=$(pretty_print "$where")
	display "WHERE condition: \"$whd\"" 0
	if [ $(array_idx "$where" "or") -ge 0 ]
	then
		display "OR condition in WHERE is not supported" 1
		return
	fi
	IFS="
"
	wa=$(echo $where | sed -e "s/ AND /\\\n/gI" -e "s/ in /=/gI")
	using_index=1
	prvidxname=""
	c=1
	# this should be modified to look for leftmost parts of PK and index
	for row in $(echo -e $wa)
	do
		fld=$(echo $row | cut -d"=" -f 1 | tr -d " ")
		index_name $fld
		index_parts $idxname
		if [ "$prvidxname" != "$idxname" ]
		then
			if [ "$prvidxname" = "" ]
			then
				prvidxname="$idxname"
			else
				[ $c -le $idxcount ] && using_index=0
				break	
			fi
		fi
		c=$((c + 1))
	done
	if [ $using_index -eq 0 ]
	then
		num_rows
		if [ $rows -ge 100000 ]
		then
			display "WHERE condition not using an index and table is large, query cannot be executed" 1
			return
		fi
	fi
	echo "-- Rollback instructions for query $qc" >> $rollback_file
	if [ $(echo $table | fgrep -c "." ) -ne 0 ]
	then
		parsed_db=$(echo $table | cut -d"." -f 1)	
		parsed_table=$(echo $table | cut -d"." -f 2)	
		consistent_dump "$parsed_db" "$parsed_table" "$where" 0 > $tmpf
		if [ -s $tmpf ] 
		then
			echo "USE $parsed_db" >> $rollback_file
			cat $tmpf >> $rollback_file
		fi
	else
		consistent_dump "$db" "$table" "$where" 0 > $tmpf
		if [ -s $tmpf ] 
		then
			echo "USE $db" >> $rollback_file
			cat $tmpf >> $rollback_file
		fi
	fi
	total_errors=$((total_errors-1))
	run_statement "$1" $dryrun
}

query_insert()
{
	total_errors=$((total_errors+1))
	display "Query type: ${3^^}" 0
	[ "${3,,}" = "replace" ] && replace=1 || replace=0
	IFS=" " q=($(echo $1 | sed -e "s/(/ (/ig"))
	query_id=$2
	if [ "${q[1],,}" != "into" ]
	then
		display "Syntax error near \"${q[1]}\"" 1
		return
	fi
	table="${q[2]}"
	[ "${q[3],,}" = "values" ] && nocols=1 || nocols=0
	echo $table | fgrep -q "(" && table=$(echo $table | cut -d "(" -f 1)
	check_table_presence
	[ $table_present -ne 1 ] && return
	check_autoincrement
	display "Schema: $db" 0
	display "Table: $table" 0
	total_errors=$((total_errors-1))
	case $replace in
		0) 
			run_statement "$1" $dryrun
			[ $error -eq 0 ] && replace_rollback "$1" "${3,,}" $nocols >> $rollback_file
			;;
		1)
			# if using REPLACE, rollback code needs to be executed before the actual statement
			replace_rollback "$1" "${3,,}" $nocols >> $rollback_file
			run_statement "$1" $dryrun
			;;
	esac
	if [ $dryrun -eq 0 ]
	then
		[ $replace -eq 0 -a $auto_increment -eq 1 ] && display "AUTO-INC value assigned:  $last_id" 3
	fi
}

query_update()
{
	total_errors=$((total_errors+1))
	display "Query type: UPDATE" 0
	IFS=" " q=($1)
	query_id=$2
	table="${q[1]}"
	if [ "${q[2],,}" != "set" ]
	then
		display "Syntax error near \"${q[2]}\"" 1
		return
	fi
	check_table_presence
	[ $table_present -ne 1 ] && return
	c=0
	w=0
	dml=""
	for arg in ${q[@]}
	do
		if [ $c -ge 3 ]
		then
			if [ "${arg,,}" = "where" ]
			then
				w=$c
				break
			fi
			dml="$dml $arg"
		fi
		c=$(($c + 1))
	done
	if [ $w -eq 0 ]
	then
		display "UPDATE without WHERE is not allowed" 1
		return
	fi
	c=0
	where=""
	for arg in ${q[@]}
	do
		if [ $c -gt $w ]
		then
			where="$where $arg"
		fi
		c=$(($c + 1))
	done
	cols=""
	cs=($(echo $dml | tr "," "\t" | tr -d " "))
	saveIFS="$IFS"
	IFS="	"
	for arg in ${cs[@]}
	do
		# TODO: need to find a way to detect whether the equal sign is inside a string or not...
		[ $(echo $arg | fgrep -v '=\"' | fgrep -c "=") -eq 1 ] && cols="$cols$(echo $arg | cut -d"=" -f 1) "
	done
	IFS="$saveIFS"
	#display "Cols: $cols" 0
	check_columns "$cols"
	[ $columns_ok -eq 0 ] && return
	display "Schema: $db" 0
	display "Table: $table" 0
	d_text=$(escape_html "$dml")
	display "Set: $d_text" 0
	whd=$(pretty_print "$where")
	display "WHERE condition: \"$whd\"" 0
	if [ $(array_idx "$where" "or") -ge 0 ]
	then
		display "OR condition in WHERE is not supported" 1
		return
	fi
	notsrch=$(array_idx "$where" "not")
	if [ $notsrch -ge 0 ]
	then
		nullsrch=$(array_idx "$where" "null")
		nullsrch=$((nullsrch - 1))
		if [ $nullsrch -ne $notsrch ]
		then
			display "NOT condition in WHERE is not supported as indexes would not be used" 1
			return
		fi
	fi
	rollback=0
	wa=($(echo "$where" | sed -e "s/, /,/g"))
	get_pk
	pkc=$(echo $pk | wc -w)
	pkwa=0
	check_pk_use "$where" $pkc
	if [ $pk_in_use -eq 0 ]
	then
		display "NOTICE: WHERE condition not using PK, switching to PK for safe rollback" 0
		num_rows
		if [ $rows -gt 1000000 -a $dryrun -eq 1 ]
		then
			display "WARNING: large table $table: $rows rows, and query not using PK. Rollback generation could take some time" 3
		fi
		pkwa=1
	fi
	in=$(array_idx "$where" "in")
	if [ $in -ge 0 ]
	then
		if [ $(echo $where | fgrep -c "=") -ne 0 ]
		then
			display "Sorry, this tool does not support WHERE conditions with a mix of \"=\" and IN() at this time" 1
			return
		fi
		if [ $(echo $where | fgrep -ic " and ") -ne 0 ]
		then
			display "Sorry, this tool does not support WHERE conditions with multiple IN()s at this time" 1
			return
		fi
		c=$(($in + 1))
		IFS="," in_set=($(echo "${wa[@]:$c}" | tr -d "()"))
		#
		#	WHERE key IN (....)
		#
		echo "-- Rollback instructions for query $qc" >> $rollback_file
		[ "$db" != "" ] && echo "USE $db" >> $rollback_file	
		for arg in ${in_set[@]}
		do
			saveIFS="$IFS"
			IFS=" "
			rbs=$(rollback_args "$cols")
			IFS="$saveIFS"
			naked_arg=$(echo $arg | tr -d "'")
			if [ $pkwa -eq 1 ]
			then
				saveIFS="$IFS"
				if [ $pkc -gt 1 ]
				then
					IFS=" "
					rbw=$(rollback_pkwhere "$pk")
					IFS="$saveIFS"
					mysql_query "SELECT CONCAT('UPDATE $table SET ', $rbs, ' WHERE ', $rbw, ';') FROM  $table WHERE ${wa[0]}='$naked_arg' /* update 1 */" "$db" >> $rollback_file
				else
					IFS="
"
					for row in $(mysql_query "SELECT $pk FROM $table WHERE ${wa[0]}='$naked_arg' /* update 2 */" "$db")
                                	do
                                        	res=$(mysql_query "SELECT $rbs FROM $table WHERE $pk = '$row' /* update 3 */" "$db")
                                        	res=$(echo "$res" | sed -e "s/'NULL'/NULL/g")
                                        	echo "UPDATE $table SET $res WHERE $pk = '$row';" >> $rollback_file
                                	done
					IFS="$saveIFS"
				fi
			else
				res=$(mysql_query "SELECT $rbs FROM $table WHERE ${wa[0]}='$naked_arg' /* update 4 */" "$db")
				res=$(echo "$res" | sed -e "s/'NULL'/NULL/g")
				if [ "$res" != "" ]
				then
					rollback=1
					echo "UPDATE $table SET $res WHERE ${wa[0]}='$naked_arg';" >> $rollback_file
				fi
			fi
		done
	else
		#
		#	WHERE key = ....
		#
		echo "-- Rollback instructions for query $qc" >> $rollback_file
		[ "$db" != "" ] && echo "USE $db" >> $rollback_file	
		if [ $pkwa -eq 1 ]
		then
			rbs=$(rollback_args "$cols")
			if [ $pkc -gt 1 ]
			then
				rbw=$(rollback_pkwhere "$pk")
				mysql_query "SELECT CONCAT('UPDATE $table SET ', $rbs, ' WHERE ', $rbw, ';') FROM  $table WHERE $where /* update 5 */" "$db" >> $rollback_file
			else
				saveIFS="$IFS"
				IFS="
"
				for row in $(mysql_query "SELECT $pk FROM $table WHERE $where /* update 6 */" "$db")
				do
					res=$(mysql_query "SELECT $rbs FROM $table WHERE $pk = '$row' /* update 7 */" "$db")
					res=$(echo "$res" | sed -e "s/'NULL'/NULL/g")
					echo "UPDATE $table SET $res WHERE $pk = '$row';" >> $rollback_file
				done
				IFS="$saveIFS"
			fi
		else
			count=$(mysql_query "SELECT COUNT(*) FROM $table WHERE $where /* update 8 */" "$db")
			if [ $count -gt 1 ]
			then
				# assumes small table, add a check
				rollback=1
				consistent_dump "$db" "$table" "$where" | gzip  > ${rollback_file}_${query_id}_dump.gz
				echo "-- Run this script ${rollback_file}_${query_id}_dump.gz" >> $rollback_file
			else
				rbs=$(rollback_args "$cols")
				res=$(mysql_query "SELECT $rbs FROM $table WHERE $where /* update 9 */" "$db")
				res=$(echo "$res" | sed -e "s/'NULL'/NULL/g")
				if [ "$res" != "" ]
				then
					rollback=1
					echo "UPDATE $table SET $res WHERE $where;" >> $rollback_file
				fi
			fi
		fi
	fi
	total_errors=$((total_errors-1))
	run_statement "$1" $dryrun
}

show_rollback()
{
	display "<font size=2>---- start of rollback instructions ----" 0
	d_text=$(escape_html "$(cat $1)")
	display "$d_text" 0
	display "---- end of rollback instructions ----</font>" 0
	display "" 0
}

pretty_print()
{
	c=1
	for arg in $1
	do
		if [ $c -eq 10 ]
		then
			echo -n "$arg<br>"	
			c=1
		else
			echo -n "$arg "
		fi
		c=$((c + 1))
	done
}

open_quotes()
{
	niq=$(echo "$1" | sed -e "s/\\\'//g")
	# this triggers a bash bug in some circumstances... nniq=${niq//[^\']}
	nniq=$(echo "$niq" | tr -dc "'")
	printf "%d %% 2\n" ${#nniq} | bc
}

process_query() {
	q_nb=$(echo "$1" | sed -e "s/^ *//")
	IFS=" " q=($q_nb)
	display "----- Processing query #$2 ------" 2
	mysql_debug "-- Query #$2"
	dq="${q[@]}"
	dqq=$(pretty_print "$dq")
	display "$dqq" 2
	case "${q[0],,}" in
		'update') 
			query_update "$1" "$2"
			;;
		'delete') 
			query_delete "$1" "$2"
			;;
		'insert'|'replace') 
			query_insert "$1" "$2" "${q[0]}"
			;;
		'select'|'show'|'create'|'drop'|'alter'|'truncate'|'grant'|'drop'|'revoke') 
			display "Sorry, ${q[0]} not supported by this tool. This query will not be executed." 1
			;;
		*) display "Syntax error near \"${q[0]}\"" 1
			;;
	esac
	display "" 0
}

printf "Content-Type: text/html; charset=utf-8\n\n"
printf "<HTML>\n"
printf "<HEAD>\n"
printf "<TITLE>Query Executor v%s</TITLE>\n" "$VERSION"
printf "</HEAD>\n"
printf "<BODY BGCOLOR=\"#ffffff\">\n"
printf "<FONT FACE=\"Arial\" SIZE=3>\n"
case "$REQUEST_METHOD" in
	'GET');;
	'POST');;
	*) 	printf "Unsupported HTTP method $REQUEST_METHOD";
		printf "$closing_tags\n"
		exit 0;;
esac
if [ "$REQUEST_METHOD" = "POST" ]
then
	post=1
	IFS="
"
	for row in $(tr "&" "\n")
	do
		name=$(echo $row | cut -d"=" -f 1)
		value=$(echo $row | cut -d"=" -f 2)
		case "$name" in
			'user') user="$value";;
			'password') password="$value";;
			'host') host="$value";;
			'schema') default_db="$value";;
			'query') query="$value";;
			'ticket') ticket="$value";;
			'dryrun') 
				[ "$value" = "on" ] && dryrun=1
				;;
			'backq') kill_backq=0
				[ "$value" = "on" ] && kill_backq=1
				;;
		esac
	done
fi
if [ $post -eq 1 ]
then
	post_checks
	if [ $post_error -eq 0 ]
	then
		myerr=$(mysqladmin -u "$user" -p"$password" -h "$host" ping 2>&1)
		connected=$(echo "$myerr" | fgrep -c alive)
		if [ $connected -ne 1 ]
		then
			display "$(echo "$myerr" | tail -1)" 1
		else
			if [ "$query" = "" ]
			then
				display "Connected to $host" 0
				display "$(mysqladmin -u "$user" -p"$password" -h "$host" version | tail -7)" 0
			else
				connection_setup 
				IFS=";"
				qc=0
				if [ "$ticket" != "" ]
				then
					rollback_file="$BASE/rollback/${user}_${host}_${ticket}_$$.sql"
				else
					rollback_file="$BASE/rollback/${user}_${host}_$(date "+%Y%m%d_%T")_$$.sql"
				fi
				echo "BEGIN;" > $rollback_file
				# the following code also checks for presence of query delimiter inside quotes
				# by keeping track of quotes open and not closed (qo = 1)
				qo=0
				lq=""
				for q in $(unescape_execute "$query")
				do
					[ "$(echo -n $q | tr -d ' ')" = "" ] && continue
					if [ $(open_quotes "$q") -eq 1 ]
					then
						if [ $qo -eq 0 ]
						then
							qo=1
							lq="$lq$q;"
							continue
						else
							qo=0
							q="$lq$q"
							lq=""
						fi
					else
						if [ $qo -eq 1 ]
						then
							lq="$lq$q;"
							continue
						fi
					fi
					qc=$(($qc + 1))
					process_query "$q" $qc
				done
				echo "COMMIT;" >> $rollback_file
			fi
			if [ $dryrun -eq 1 ]
			then
				show_rollback $rollback_file
				display "Dry run results:" 2
				display "Errors: $total_errors  Warnings: $total_warnings<BR>" 2
				if [ $total_errors -gt 0 -o $total_warnings -gt 0 ] 
				then
					display "There are errors or warnings. Please resolve the problem(s) and retry the dry run." 2
				else
					display "This was a dry run. Please verify the rollback code above, then remove the flag to execute the query." 2
				fi
				mysql_query "ROLLBACK" > /dev/null
				rm -f $rollback_file ${rollback_file}_*_dump.gz 
			else
				if [ $qc -gt 0 ]
				then
					if [ $total_errors -gt 0 -o $total_warnings -gt 0 ] 
					then
						mysql_query "ROLLBACK" > /dev/null
						rm -f $rollback_file ${rollback_file}_*_dump.gz 
						display "Execution failed!  Your changes have been rolled back.  Errors: $total_errors  Warnings: $total_warnings" 1
					else
						mysql_query "COMMIT" > /dev/null
						display "Done. Rollback statements saved in $rollback_file on $(hostname)." 0
					fi
				fi
			fi
		fi
	fi
else
	dryrun=1
fi
show_form
printf "$closing_tags\n"
exit 0
