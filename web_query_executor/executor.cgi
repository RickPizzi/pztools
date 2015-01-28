#!/bin/bash
#
#	web query executor
#	riccardo.pizzi@rumbo.com Jan 2015
#
VERSION="0.6.4"
BASE=/usr/local/executor
#
post=0
db=""
closing_tags="</FONT></BODY></HTML>"
message=""
dryrun=0
tmpf=/tmp/executor.$$
trap 'rm -f $tmpf' 0

unescape_query()
{
	echo "$1" | sed -e "s/%40/@/g" -e "s/%60/\`/g" -e "s/+/ /g" -e "s/%3D/=/g" -e "s/%2B/+/g" -e "s/%3B/;/g" -e "s/%27/'/g" -e "s/%3A/:/g" -e "s/%28/(/g" -e "s/%29/)/g" -e "s/%2C/,/g" -e "s/%23/#/g" -e "s/%22/\"/g" -e "s/%3C/</g" -e "s/%2F/\//g" -e "s/%3E/>/g" -e "s/%26/\&/g" -e "s/%7B/{/g" -e "s/%7D/}/g" -e "s/%5B/[/g" -e "s/%5D/]/g" -e "s/%5C/\\\/g" -e "s/%25/%/g" -e "s/%7C/|/g" -e "s/%09/ /g"
}

unescape_textarea()
{
	[ $kill_backq -eq 0 ] && unescape_query "$1" | sed -e "s/%0D%0A/\n/g" || unescape_query "$1" | sed -e "s/%0D%0A/\n/g" -e "s/\`\.\`/./g" -e "s/\`/ /g"
}

unescape_execute()
{
	unescape_query "$1" | sed -e "s/%0D%0A/ /g"
}

escape_html()
{
	echo "$1" | sed -e "s/&/&amp;/g" -e "s/\\\/\&#92;/g"
}

display() {
	escaped=$(echo "$1" | sed -e "s/\%/%%/g")
	case "$2" in
		0) message="$message$escaped<BR>";;
		1) message="$message<FONT COLOR=\"Red\">ERROR: $escaped</FONT><BR>";;
		2) message="$message<FONT COLOR=\"Green\">$escaped</FONT><BR>";;
		3) message="$message<FONT COLOR=\"Orange\">$escaped</FONT><BR>";;
	esac
}

debug() {
	d_text=$(echo "$1" | od -va)
	message="$message<BR>DEBUG:<BR>$d_text<BR>";
	echo "$1" >> /usr/local/executor/log/debug.log
}

show_form()
{
	printf "<FONT SIZE=2>Executor version: $VERSION<BR></FONT><BR>"
	printf "<FORM METHOD=\"POST\" ACTION=\"$SCRIPT_NAME\">\n"
	printf "<TABLE>\n"
	printf "<TR><TD>Host:</TD><TD><INPUT TYPE=TEXT NAME=\"host\" VALUE=\"$host\" MAXLENGTH=36 SIZE=16></TD></TR>\n"
	printf "<TR><TD>User:</TD><TD><INPUT TYPE=TEXT NAME=\"user\" VALUE=\"$user\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Password:</TD><TD><INPUT TYPE=PASSWORD NAME=\"password\" VALUE=\"$password\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Schema:</TD><TD><INPUT TYPE=TEXT NAME=\"schema\" VALUE=\"$db\" MAXLENGTH=32 SIZE=32></TD></TR>\n"
	printf "<TR><TD>Ticket #:</TD><TD><INPUT TYPE=TEXT NAME=\"ticket\" VALUE=\"$ticket\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Remove backquotes:</TD><TD><INPUT TYPE=CHECKBOX NAME=\"backq\" VALUE=\"on\" CHECKED></TD></TR>\n" 
	[ $dryrun -eq 1 ] && textarea=$(escape_html "$(unescape_textarea $query)")
	printf "<TR><TD COLSPAN=2><TEXTAREA NAME=\"query\" ROWS=8 COLS=200>%s</TEXTAREA></TD></TR>\n" "$textarea"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TR><TD COLSPAN=2><B><PRE>$message</PRE></B></TD></TR>\n"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	[ $dryrun -eq 1 ] && checkbox="CHECKED"
	printf "<TR><TD>Dry Run:</TD><TD><INPUT TYPE=CHECKBOX NAME=\"dryrun\" VALUE=\"on\" %s></TD></TR>\n" "$checkbox"
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
	if [ "$(echo "show variables like 'read_only'" | mysql -ANr -u "$user" -p"$password" -h"$host" 2>&1 | cut -f 2)" != "OFF" ]
	then
		display "This instance is READ ONLY" 1
		post_error=1
		return
	fi
	if [ "$db" != "" ]
	then
		res=$(mysql -u "$user" -p"$password" -h"$host" "$db" 2>&1)
		if [ "$res" != "" ]
		then
			display "$res" 1
			post_error=1
		fi
	fi
}

run_statement()
{
	statement_error=0
	q_warning=""
	q_last_id=""
	last_id=""
	case $2 in
		0)
			my_err=$(echo "$1; show warnings; select last_insert_id();" | mysql -u "$user" -p"$password" -h "$host" -vv "$db" 2>&1 | fgrep -v Bye)
			;;
		1)
			my_err=$(echo "begin; $1; show warnings; select last_insert_id(); rollback" | mysql -u "$user" -p"$password" -h "$host" -vv "$db" 2>&1 | fgrep -v Bye)
			;;
	esac
	c=0
	saveIFS="$IFS"
	IFS="
"
	for row in $(echo "$my_err")
	do
		if [ "$row" = "--------------" ]
		then
			c=$(($c + 1))
			continue
		fi
		case $2 in
			0)	case $c in
					0) q_error="$row";;
					2) q_result="$row";;
					4) q_warning="$q_warning$(echo $row | fgrep Warning)";;
					6) q_last_id="$q_last_id$(echo $row | egrep -v "last|row")";;
				esac
				;;
			1)	case $c in
					0) q_error="$row";;
					4) q_result="$row";;
					6) q_warning="$q_warning$(echo $row | fgrep Warning)";;
					8) q_last_id="$q_last_id$(echo $row | egrep -v "last|row")";;
				esac
				;;
		esac
		#display "$c $row" 0
	done
	IFS="$saveIFS"
	if [ $(echo "$my_err" | fgrep -c "ERROR ") -eq 1 ]
	then
		case $2 in
			0) 	display "$q_error $q_result" 1
				statement_error=1
				;;
			1) 	display "DRY RUN RESULT: $q_error" 3
				;;
		esac
	else
		case $2 in
			0)	last_id=$q_last_id
				display "$q_result" 2
				display "$q_warning" 3
				log "$1"
				;;
			1) 	display "DRY RUN RESULT:<BR>$q_result<BR>$q_warning" 3
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
	echo "select TABLE_ROWS from information_schema.tables where TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table';" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db"
}

replace_rollback()
{
	saveIFS="$IFS"
	rr_cols=($(echo "$1" | cut -d "(" -f 2 | cut -d ")" -f 1 | sed -e "s/,/, /g" | tr -d "[,]"))
	rr_ncols=${#rr_cols[@]}
	rr_maxidx=$(($rr_ncols - 1))
	rr_rows=$(echo "$1" | cut -d ")" -f2- | sed -e "s/ VALUES //ig" -e "s/ VALUES$//ig" -e "s/),(/\\\n/g"  -e "s/^ *(//g"  -e "s/), *(/\\\n/g" -e "s/) *;*$//g")
	echo "$rr_rows" >> /tmp/zap
	declare -A rr_iskey
	IFS=" "; for rr_pos in $(echo "select REPLACE(GROUP_CONCAT(ORDINAL_POSITION), ',', ' ') from information_schema.KEY_COLUMN_USAGE where CONSTRAINT_NAME = 'PRIMARY' AND TABLE_SCHEMA = '$db' AND TABLE_NAME = '$table'" | mysql -ANr -h "$host" -u "$user" -p"$password")
	do
		rr_iskey[$(($rr_pos -1))]="y"
	done
	IFS="
"
	for rr_row in $(echo -e "$rr_rows")
	do
		rr_saveIFS="$IFS"
		IFS=","
		rr_vals=($rr_row)
		if [ ${#rr_vals[@]} -ne $rr_ncols ] 
		then
			echo "-- Cannot create rollback, columns mismatch (${#rr_vals[@]} != $rr_ncols ) for row: \"replace into $table (${rr_cols[@]}) values($rr_row)\""
			IFS="$rr_saveIFS"
			break
		fi
		IFS="$rr_saveIFS"
		rr_kc=0
		rr_where=$(for rr_s in $(seq 0 1 $rr_maxidx)
		do
			if [ "${rr_iskey[$rr_s]}" != "" ]
			then
				[ $rr_kc -gt 0 ] && echo -n " AND "
				echo -n "${rr_cols[$rr_s]} = ${rr_vals[$rr_s]}"
				rr_kc=$(($rr_kc + 1))
			fi
		done)
		#echo "DEBUG: where=\"$rr_where\"<br>"
		rr_ins=$(
			( 
				echo -n "SET NAMES utf8; SELECT CONCAT_WS(',', "
				for rr_s in $(seq 0 1 $rr_maxidx)
				do
					echo -n "IF(${rr_cols[$rr_s]} IS NULL,'NULL',CONCAT('\'', ${rr_cols[$rr_s]}, '\''))"
					[ $rr_s -lt $rr_maxidx ] && echo -n ", "
				done 
				echo ") FROM $table WHERE $rr_where"
			) | mysql -ANr -h "$host" -u "$user" -p"$password" "$db"
		)
		#echo "DEBUG: ins=\"$rr_ins\"<br>"
		[ "$db" != "" ] && echo "USE $db"
		echo "DELETE FROM $table WHERE $rr_where;"
		for rr_row in $rr_ins
		do
			echo "INSERT INTO $table VALUES ($rr_row);"
		done
	done
	IFS="$saveIFS"
}

get_pk()
{
	echo "show index from $table where Key_name = 'PRIMARY'" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db" | cut -f 5 | tr "[\n]" "[ ]" | sed -e "s/ $//g"
}
			
is_autoinc()
{
	pk=$(get_pk)
	echo "select extra from information_schema.columns where table_schema = '$db' and table_name = '$table' and column_name = '$pk'" | mysql -ANr -h "$host" -u "$user" -p"$password" | fgrep -c auto_increment
}
			
is_index()
{
	echo "show index from $table where Column_name = '$1' and Seq_in_index = 1" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db" | wc -l
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
	savedb=$db
	if [ $(echo $table | fgrep -c "." ) -eq 0 ]
	then
		if [ "$db" = "" ]
		then
			display "Default schema not set" 1
			table_present=0
			return
		fi
	else
		st=$table	
		db=$(echo $st | cut -d"." -f 1)
		table=$(echo $st | cut -d"." -f 2)
	fi
	there=$(echo "select count(*) from information_schema.tables where table_schema = '$db' and table_name= '$table'" | mysql -ANr -h "$host" -u "$user" -p"$password")
	if [ $there -eq 0 ]
	then
		display "No table named \"$table\" in schema \"$db\"" 1
		db=$savedb
		table_present=0
		return
	fi
	[ "$savedb" != "" ] && db=$savedb
}

check_columns()
{
	columns_ok=1
	for arg in $1
	do
		[ $(echo $arg | fgrep -c ".") -gt 0 ] && arg=$(echo $arg | cut -d"." -f 2)
		if [ $(echo "select count(*) from information_schema.columns where table_schema = '$db' and table_name = '$table' and column_name = '$arg'" | mysql -ANr -h "$host" -u "$user" -p"$password") -eq 0 ]
		then
			display "Column \"$arg\" does not exist" 1
			columns_ok=0
			return
		fi
	done
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
		echo -n "'$arg=\'',$arg,'\''"
		c=$(($c + 1))
	done
	echo ")"
}

query_delete()
{
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
	using_index=0
	wa=$(echo $where | sed -e "s/ AND /\\\n/gI" -e "s/ in /=/gI")
	for row in $(echo -e $wa)
	do
		fld=$(echo $row | cut -d"=" -f 1 | tr -d "[ ]")
		display "DEBUG: $fld" 0
		if [ $(is_index $fld) -eq 1 ] 
		then
			using_index=1
			break
		fi
	done
	if [ $using_index -eq 0 ]
	then
		display "no indexed columns found in WHERE condition, query cannot be executed" 1
		return
	fi
	if [ $(echo $table | fgrep -c "." ) -ne 0 ]
	then
		parsed_db=$(echo $table | cut -d"." -f 1)	
		parsed_table=$(echo $table | cut -d"." -f 2)	
		mysqldump --skip-opt --skip-trigger --compact --no-create-info --single-transaction --user "$user" --password="$password" --where "$where" --host "$host" "$parsed_db" "$parsed_table" > $tmpf
		if [ -s $tmpf ] 
		then
			echo "USE $parsed_db" >> $rollback_file
			cat $tmpf >> $rollback_file
		fi
	else
		mysqldump --skip-opt --skip-trigger --compact --no-create-info --single-transaction --user "$user" --password="$password" --where "$where" --host "$host" "$db" "$table" > $tmpf
		if [ -s $tmpf ] 
		then
			echo "USE $db" >> $rollback_file
			cat $tmpf >> $rollback_file
		fi
	fi
	run_statement "$1" $dryrun
}

query_insert()
{
	display "Query type: ${3^^}" 0
	IFS=" " q=($1)
	query_id=$2
	if [ "${q[1],,}" != "into" ]
	then
		display "Syntax error near \"${q[1]}\"" 1
		return
	fi
	table="${q[2]}"
	check_table_presence
	[ $table_present -ne 1 ] && return
	run_statement "$1" $dryrun
	if [ $dryrun -eq 0 ]
	then
		if [ $statement_error -eq 0 ]
		then
			if [ "${3,,}" != "replace" ]
			then
				if [  $last_id -gt 0 ]
				then
					pk=$(get_pk)
					[ "$db" != "" ] && echo "USE $db" >> $rollback_file
					echo "DELETE FROM $table WHERE $pk = '$last_id';" >> $rollback_file
					display "AUTO-INC value assigned:  $last_id, rollback available" 3
				else
					echo "-- rollback not supported for: $1" >> $rollback_file
				fi
			else
				replace_rollback "$1" >> $rollback_file
			fi
		fi
	else
		if [ "${3,,}" != "replace" ]
		then
			if [ $(is_autoinc) -eq 1 ]
			then
				echo "-- auto_increment PK detected, rollback will be available after execution: $1" >> $rollback_file
			else
				echo "-- rollback not supported for: $1" >> $rollback_file
			fi
		else
			if [ $(echo "$1" | cut -d ")" -f 1 | fgrep -ic "VALUES") -eq 1 ]
			then
				echo "-- rollback not supported for: $1" >> $rollback_file
			else
				replace_rollback "$1"  >> $rollback_file
			fi
		fi
	fi
}

query_update()
{
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
	cs=($(echo $dml | tr "[,]" "[\t]" | tr -d "[ ]"))
	saveIFS="$IFS"
	IFS="	"
	for arg in ${cs[@]}
	do
		[ $(echo $arg | fgrep -c "=") -eq 1 ] && cols="$cols$(echo $arg | cut -d"=" -f 1) "
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
	if [ $(array_idx "$where" "not") -ge 0 ]
	then
		display "NOT condition in WHERE is not supported as indexes would not be used" 1
		return
	fi
	rollback=0
	wa=($(echo "$where" | sed -e "s/, /,/g"))
	pk=$(get_pk "$where")
	pkc=$(echo $pk | wc -w)
	pkwa=0
	check_pk_use "$where" $pkc
	if [ $pk_in_use -eq 0 ]
	then
		display "NOTICE: WHERE condition not using PK, switching to PK for safe rollback" 0
		t_rows=$(num_rows)
		if [ $t_rows -gt 1000000 ]
		then
			display "WARNING: large table $table: $t_rows rows, and query not using PK. Rollback generation will take some time" 3
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
		c=$(($in + 1))
		IFS="," in_set=($(echo "${wa[@]:$c}" | tr -d "[()]"))
		#
		#	WHERE key IN (....)
		#
		[ "$db" != "" ] && echo "USE $db" >> $rollback_file	
		for arg in ${in_set[@]}
		do
			saveIFS="$IFS"
			IFS=" "
			rbs=$(rollback_args "$cols")
			IFS="$saveIFS"
			naked_arg=$(echo $arg | tr -d "[']")
			if [ $pkwa -eq 1 ]
			then
				saveIFS="$IFS"
				if [ $pkc -gt 1 ]
				then
					IFS=" "
					rbw=$(rollback_pkwhere "$pk")
					IFS="$saveIFS"
					echo -e "SELECT CONCAT('UPDATE $table SET ', $rbs, ' WHERE ', $rbw, ';') FROM  $table WHERE $where" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db" >> $rollback_file
				else
					IFS="
"
					for row in $(echo "SELECT $pk FROM $table WHERE ${wa[0]}='$naked_arg'" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db")
                                	do
                                        	res=$(echo -e "SET NAMES utf8; SELECT $rbs FROM $table WHERE $pk = '$row';" | mysql -ANr -h $host -u "$user" -p"$password" "$db" | sed -e "s/'NULL'/NULL/g")
                                        	echo "UPDATE $table SET $res WHERE $pk = '$row';" >> $rollback_file
                                	done
					IFS="$saveIFS"
				fi
			else
				res=$(echo -e "SET NAMES utf8; SELECT $rbs FROM $table WHERE ${wa[0]}='$naked_arg'" | mysql -ANr -h $host -u "$user" -p"$password" "$db" | sed -e "s/'NULL'/NULL/g")
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
		if [ $pkwa -eq 1 ]
		then
			rbs=$(rollback_args "$cols")
			if [ $pkc -gt 1 ]
			then
				rbw=$(rollback_pkwhere "$pk")
				echo -e "SELECT CONCAT('UPDATE $table SET ', $rbs, ' WHERE ', $rbw, ';') FROM  $table WHERE $where" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db" >> $rollback_file
			else
				saveIFS="$IFS"
				IFS="
"
				[ "$db" != "" ] && echo "USE $db" >> $rollback_file	
				for row in $(echo "SELECT $pk FROM $table WHERE $where" | mysql -ANr -h "$host" -u "$user" -p"$password" "$db")
				do
					res=$(echo -e "SET NAMES utf8; SELECT $rbs FROM $table WHERE $pk = '$row';" | mysql -ANr -h $host -u "$user" -p"$password" "$db" | sed -e "s/'NULL'/NULL/g")
					echo "UPDATE $table SET $res WHERE $pk = '$row';" >> $rollback_file
				done
				IFS="$saveIFS"
			fi
		else
			count=$(echo "SELECT COUNT(*) FROM $table WHERE $where" | mysql -ANr -h $host -u "$user" -p"$password" "$db")
			if [ $count -gt 1 ]
			then
				# assumes small table, add a check
				rollback=1
				mysqldump --no-create-info --skip-trigger --single-transaction --user "$user" --password="$password" --host "$host" "$db" "$table" | gzip  > ${rollback_file}_${query_id}_dump.gz
				echo "-- Reimport table $table using ${rollback_file}_${query_id}_dump.gz" >> $rollback_file
			else
				rbs=$(rollback_args "$cols")
				res=$(echo -e "SET NAMES utf8; SELECT $rbs FROM $table WHERE $where" | mysql -ANr -h $host -u "$user" -p"$password" "$db" | sed -e "s/'NULL'/NULL/g")
				if [ "$res" != "" ]
				then
					rollback=1
					[ "$db" != "" ] && echo "USE $db" >> $rollback_file	
					echo "UPDATE $table SET $res WHERE $where;" >> $rollback_file
				fi
			fi
		fi
	fi
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

process_query() {
	IFS=" " q=($(echo "$1" | sed -e "s/^ *//") )
	display "----- Processing query #$2 ------" 2
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

printf "Content-Type: text/html\n\n"
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
	for row in $(tr "[&]" "[\n]")
	do
		name=$(echo $row | cut -d"=" -f 1)
		value=$(echo $row | cut -d"=" -f 2)
		case "$name" in
			'user') user="$value";;
			'password') password="$value";;
			'host') host="$value";;
			'schema') db="$value";;
			'query') query="$value";;
			'ticket') ticket="$value";;
			'dryrun') dryrun=0
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
				IFS=";"
				qc=1
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
					[ "$(echo -n $q | tr -d '[ ]')" = "" ] && continue
					if [ $(printf "%d %% 2\n" ${#${q//[^\']}} | bc) -eq 1 ]
					then
						if [ $qo -eq 0 ]
						then
							qo=1
							lq="$lq$q"
							continue
						else
							qo=0
							q="$lq$q"
							lq=""
						fi
					else
						if [ $qo -eq 1 ]
						then
							lq="$lq$q"
							continue
						fi
					fi
					process_query "$q" $qc
					qc=$(($qc + 1))
				done
				echo "COMMIT;" >> $rollback_file
			fi
			if [ $dryrun -eq 1 ]
			then
				show_rollback $rollback_file
				display "This was a dry run. Please verify the rollback code above, then remove the flag to execute the query." 2
				rm -f $rollback_file ${rollback_file}_*_dump.gz 
			else
				display "Done. Rollback statements saved in $rollback_file on $(hostname)". 0
			fi
		fi
	fi
else
	dryrun=1
fi
show_form
printf "$closing_tags\n"
exit 0
