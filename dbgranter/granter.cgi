#!/bin/bash
#
VERSION="0.4.4"
#
# NOTICE: CONFIG FILE
# Config file /etc/dbgranter.conf should contain the following:
#	user=tool_user
#	password=tool_password
# this user needs SELECT privileges on all schemas from the machine the tool runs on
#
service_user=$(grep ^user /etc/dbgranter.conf | cut -d"=" -f 2)
service_password=$(grep ^password /etc/dbgranter.conf | cut -d"=" -f 2)
#
closing_tags="</FONT></BODY></HTML>"
genprivs="USAGE|FILE|PROCESS"
lgrant=""
rgrant=""
grants=""
changes=0
tmpf=/tmp/dbgranter.$$
trap 'rm -f $tmpf' 0
set -f
vpn_mask="$(echo $REMOTE_ADDR | cut -d"." -f 1-3).%"
#

unescape_input()
{
	echo "$1" | sed -e "s/%40/@/g" -e "s/%21/!/g" -e "s/%60/\`/g" -e "s/+/ /g" -e "s/%3D/=/g" -e "s/%2B/+/g" -e "s/%3B/;/g" -e "s/%27/'/g" -e "s/%3A/:/g" -e "s/%28/(/g" -e "s/%29/)/g" -e "s/%2C/,/g" -e "s/%23/#/g" -e "s/%22/\"/g" -e "s/%3C/</g" -e "s/%2F/\//g" -e "s/%3E/>/g" -e "s/%26/\&/g" -e "s/%7B/{/g" -e "s/%7D/}/g" -e "s/%5B/[/g" -e "s/%5D/]/g" -e "s/%5C/\\\/g" -e "s/%25/%/g" -e "s/%7C/|/g" -e "s/%09/ /g" -e "s/%7E/~/g" -e "s/%80/\\x80/g" -e "s/%81/\\x81/g" -e "s/%82/\\x82/g" -e "s/%83/\\x83/g" -e "s/%84/\\x84/g" -e "s/%85/\\x85/g" -e "s/%86/\\x86/g" -e "s/%87/\\x87/g" -e "s/%88/\\x88/g" -e "s/%89/\\x89/g" -e "s/%8A/\\x8A/g" -e "s/%8B/\\x8B/g" -e "s/%8C/\\x8C/g" -e "s/%8D/\\x8D/g" -e "s/%8E/\\x8E/g" -e "s/%8F/\\x8F/g" -e "s/%90/\\x90/g" -e "s/%91/\\x91/g" -e "s/%92/\\x92/g" -e "s/%93/\\x93/g" -e "s/%94/\\x94/g" -e "s/%95/\\x95/g" -e "s/%96/\\x96/g" -e "s/%97/\\x97/g" -e "s/%98/\\x98/g" -e "s/%99/\\x99/g" -e "s/%9A/\\x9A/g" -e "s/%9B/\\x9B/g" -e "s/%9C/\\x9C/g" -e "s/%9D/\\x9D/g" -e "s/%9E/\\x9E/g" -e "s/%9F/\\x9F/g" -e "s/%A0/\\xA0/g" -e "s/%A1/\\xA1/g" -e "s/%A2/\\xA2/g" -e "s/%A3/\\xA3/g" -e "s/%A4/\\xA4/g" -e "s/%A5/\\xA5/g" -e "s/%A6/\\xA6/g" -e "s/%A7/\\xA7/g" -e "s/%A8/\\xA8/g" -e "s/%A9/\\xA9/g" -e "s/%AA/\\xAA/g" -e "s/%AB/\\xAB/g" -e "s/%AC/\\xAC/g" -e "s/%AD/\\xAD/g" -e "s/%AE/\\xAE/g" -e "s/%AF/\\xAF/g" -e "s/%B0/\\xB0/g" -e "s/%B1/\\xB1/g" -e "s/%B2/\\xB2/g" -e "s/%B3/\\xB3/g" -e "s/%B4/\\xB4/g" -e "s/%B5/\\xB5/g" -e "s/%B6/\\xB6/g" -e "s/%B7/\\xB7/g" -e "s/%B8/\\xB8/g" -e "s/%B9/\\xB9/g" -e "s/%BA/\\xBA/g" -e "s/%BB/\\xBB/g" -e "s/%BC/\\xBC/g" -e "s/%BD/\\xBD/g" -e "s/%BE/\\xBE/g" -e "s/%BF/\\xBF/g" -e "s/%C0/\\xC0/g" -e "s/%C1/\\xC1/g" -e "s/%C2/\\xC2/g" -e "s/%C3/\\xC3/g" -e "s/%C4/\\xC4/g" -e "s/%C5/\\xC5/g" -e "s/%C6/\\xC6/g" -e "s/%C7/\\xC7/g" -e "s/%C8/\\xC8/g" -e "s/%C9/\\xC9/g" -e "s/%CA/\\xCA/g" -e "s/%CB/\\xCB/g" -e "s/%CC/\\xCC/g" -e "s/%CD/\\xCD/g" -e "s/%CE/\\xCE/g" -e "s/%CF/\\xCF/g" -e "s/%D0/\\xD0/g" -e "s/%D1/\\xD1/g" -e "s/%D2/\\xD2/g" -e "s/%D3/\\xD3/g" -e "s/%D4/\\xD4/g" -e "s/%D5/\\xD5/g" -e "s/%D6/\\xD6/g" -e "s/%D7/\\xD7/g" -e "s/%D8/\\xD8/g" -e "s/%D9/\\xD9/g" -e "s/%DA/\\xDA/g" -e "s/%DB/\\xDB/g" -e "s/%DC/\\xDC/g" -e "s/%DD/\\xDD/g" -e "s/%DE/\\xDE/g" -e "s/%DF/\\xDF/g" -e "s/%E0/\\xE0/g" -e "s/%E1/\\xE1/g" -e "s/%E2/\\xE2/g" -e "s/%E3/\\xE3/g" -e "s/%E4/\\xE4/g" -e "s/%E5/\\xE5/g" -e "s/%E6/\\xE6/g" -e "s/%E7/\\xE7/g" -e "s/%E8/\\xE8/g" -e "s/%E9/\\xE9/g" -e "s/%EA/\\xEA/g" -e "s/%EB/\\xEB/g" -e "s/%EC/\\xEC/g" -e "s/%ED/\\xED/g" -e "s/%EE/\\xEE/g" -e "s/%EF/\\xEF/g" -e "s/%F0/\\xF0/g" -e "s/%F1/\\xF1/g" -e "s/%F2/\\xF2/g" -e "s/%F3/\\xF3/g" -e "s/%F4/\\xF4/g" -e "s/%F5/\\xF5/g" -e "s/%F6/\\xF6/g" -e "s/%F7/\\xF7/g" -e "s/%F8/\\xF8/g" -e "s/%F9/\\xF9/g" -e "s/%FA/\\xFA/g" -e "s/%FB/\\xFB/g" -e "s/%FC/\\xFC/g" -e "s/%FD/\\xFD/g" -e "s/%FE/\\xFE/g" -e "s/%FF/\\xFF/g" -e "s/&#39;/\\\'/g"
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
        err=$(mysqladmin -u "$service_user" -p"$service_password" -h"$host" ping 2>&1 | fgrep error | cut -d":" -f2-)
        if [ "$err" != "" ]
        then
                display "$err" 1
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
	pass_ok=$(echo "select if(password('$password') =  password, 1, 0) from mysql.user where user = '$user'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>/dev/null)
	if [ $pass_ok -eq 0 ]
	then
		display "username/password combination is incorrect" 1
		post_error=1
		return
	fi
	can_grant=$(echo "select if(Grant_priv = 'Y', 1, 0) from mysql.user where user = '$user'" | mysql -ANr -u "$user" -p"$password" -h"$host" 2>/dev/null)
	[ "$can_grant" = "" ] && can_grant=0

	if [ "$(echo "show variables like 'read_only'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>&1 | cut -f 2)" != "OFF" ]
	then
		if [ $can_grant -eq 1 ]
		then
			display "This instance is READ ONLY" 1
			post_error=1
			return
		fi
	fi
	if [ "$lgrant" = "" ]
	then
		display "Please specify the grant" 0
		post_error=2
		return
	fi
	if [ $can_grant -eq 0 -a "$lgrant" != "$user" ]
	then
		display "You are allowed to see our own grants only" 1
		post_error=2
		return
	fi
	rgrant=$(unescape_input "$rgrant")
	if [ "$rgrant" = "" ]
	then
		display "Please specify the grant" 0
		post_error=2
		return
	fi
	if [ "$schema" = "" ]
	then
		display "Please specify schema name" 0
		post_error=2
		return
	fi
	res=$(echo "show databases like '$schema'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>&1)
	if [ "$res" != "$schema" ]
	then
		display "No such schema $schema" 1
		post_error=2
		return
        fi
	grants=$(echo "show grants for '$lgrant'@'$rgrant'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>/dev/null | tr -d "[\`]" | egrep "$genprivs")
	if [ "$grants" = "" ]
	then
		display "No USAGE for '$lgrant'@'$rgrant'" 1
		post_error=2
		return
	fi
	grants=$(echo "show grants for '$lgrant'@'$rgrant'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>/dev/null | tr -d "[\`]" | fgrep "ON $schema.")
	if [ "$grants" = "" ]
	then
		display "WARNING: no grants found for '$lgrant'@'$rgrant'" 2
	fi
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

show_form()
{
	printf "<FONT SIZE=2>DBGranter version: $VERSION<BR></FONT><BR>" 
	printf "<!-- %s -->\n" "$vpn_mask" 
	printf "<FORM METHOD=\"POST\" ACTION=\"$SCRIPT_NAME\" accept-charset=\"UTF-8\">\n"
	printf "<TABLE>\n"
	printf "<TR><TD>Host:</TD><TD><INPUT TYPE=TEXT NAME=\"host\" VALUE=\"$host\" MAXLENGTH=36 SIZE=16></TD></TR>\n"
	printf "<TR><TD>User:</TD><TD><INPUT TYPE=TEXT NAME=\"user\" VALUE=\"$user\" MAXLENGTH=16 SIZE=16></TD></TR>\n"
	printf "<TR><TD>Password:</TD><TD><INPUT TYPE=PASSWORD NAME=\"password\" VALUE=\"$password\" MAXLENGTH=40 SIZE=16></TD></TR>\n"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TR><TD COLSPAN=2><INPUT TYPE=\"SUBMIT\" VALUE=\"GO\">\n"
	printf "<TR><TD COLSPAN=2><DIV ID=\"grant\" STYLE=\"display:%s\">\n" "$1"
	printf "<TABLE>\n"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	if [ $can_grant -eq 1 ]
	then
		printf "<TR><TD>Grant:</TD><TD><INPUT TYPE=TEXT NAME=\"lgrant\" VALUE=\"%s\" MAXLENGTH=64 SIZE=16>@<INPUT TYPE=TEXT NAME=\"rgrant\" VALUE=\"%s\" MAXLENGTH=16 SIZE=16></TD></TR>\n" "$lgrant" "$rgrant"
	else
		printf "<TR><TD>Grant:</TD><TD><INPUT TYPE=TEXT NAME=\"lgrant\" VALUE=\"%s\" MAXLENGTH=64 SIZE=16 readonly=\"readonly\">@<INPUT TYPE=TEXT NAME=\"rgrant\" VALUE=\"%s\" MAXLENGTH=16 SIZE=16 readonly=\"readonly\"></TD></TR>\n" "$user" "$vpn_mask"
	fi
	printf "<TR><TD>Schema:</TD><TD><INPUT TYPE=TEXT NAME=\"schema\" VALUE=\"$schema\" MAXLENGTH=32 SIZE=16></TD></TR>\n"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TR><TD><INPUT TYPE=\"SUBMIT\" VALUE=\"SHOW GRANTS\">\n"
	printf "</TD><TD ALIGN=RIGHT><FONT SIZE=2><A HREF=\"%s\"><B>START OVER</B></FONT></TD></TR>\n" "$SCRIPT_NAME"
	printf "</TABLE>\n"
	printf "</DIV></TD></TR>\n"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TR><TD COLSPAN=2><B><PRE>$message</PRE></B></TD></TR>\n"
	printf "</TABLE>\n"
}

format()
{
	s=""
	u=""
	i=""
	d=""
	if [[ $2 == *"SELECT"* ]] 
	then
		s=" CHECKED"
		[ $can_grant -eq 1 ] && printf "<INPUT TYPE=HIDDEN NAME=\"%s\" VALUE=\"oselect\">\n" "$1" 
	fi
	if [[ $2 == *"INSERT"* ]] 
	then
		i=" CHECKED"
		[ $can_grant -eq 1 ] && printf "<INPUT TYPE=HIDDEN NAME=\"%s\" VALUE=\"oinsert\">\n" "$1" 
	fi
	if [[ $2 == *"UPDATE"* ]] 
	then
		u=" CHECKED"
		[ $can_grant -eq 1 ] && printf "<INPUT TYPE=HIDDEN NAME=\"%s\" VALUE=\"oupdate\">\n" "$1" 
	fi
	if [[ $2 == *"DELETE"* ]] 
	then
		d=" CHECKED"
		[ $can_grant -eq 1 ] && printf "<INPUT TYPE=HIDDEN NAME=\"%s\" VALUE=\"odelete\">\n" "$1" 
	fi
	[ $can_grant -eq 0 ] && disabled=" disabled=\"disabled\"" || disabled=""
	printf "S <INPUT TYPE=CHECKBOX NAME=\"%s\" VALUE=\"select\"%s%s>\n" "$1" "$s" "$disabled"
	printf "I <INPUT TYPE=CHECKBOX NAME=\"%s\" VALUE=\"insert\"%s%s>\n" "$1" "$i""$disabled"
	printf "U <INPUT TYPE=CHECKBOX NAME=\"%s\" VALUE=\"update\"%s%s>\n" "$1" "$u""$disabled"
	printf "D <INPUT TYPE=CHECKBOX NAME=\"%s\" VALUE=\"delete\"%s%s>\n" "$1" "$d""$disabled"
}

generate_grants()
{
	[ $can_grant -eq 0 ] && return
	t=$1
	s=$2
	os=$3
	i=$4
	oi=$5
	u=$6
	ou=$7
	d=$8
	od=$9
	grant=""
	[ $os -eq 0 -a $s -eq 1 ] && grant="$grant, SELECT"
	[ $oi -eq 0 -a $i -eq 1 ] && grant="$grant, INSERT"
	[ $ou -eq 0 -a $u -eq 1 ] && grant="$grant, UPDATE"
	[ $od -eq 0 -a $d -eq 1 ] && grant="$grant, DELETE"
	if [ "$grant" ]
	then
		cg=$(echo $grant | sed -e "s/,//")
		printf "GRANT %s ON %s TO '%s'@'%s'; <BR>\n" $cg $t $lgrant $rgrant | mysql -ANr -u "$user" -p"$password" -h"$host" 2>/dev/null
		display "Granted $cg on $t" 2
		changes=1
	fi
	grant=""
	[ $os -eq 1 -a $s -eq 0 ] && grant="$grant, SELECT"
	[ $oi -eq 1 -a $i -eq 0 ] && grant="$grant, INSERT"
	[ $ou -eq 1 -a $u -eq 0 ] && grant="$grant, UPDATE"
	[ $od -eq 1 -a $d -eq 0 ] && grant="$grant, DELETE"
	if [ "$grant" ]
	then 
		cg=$(echo $grant | sed -e "s/,//")
		printf "REVOKE %s ON %s FROM '%s'@'%s'; <BR>\n" $cg $t $lgrant $rgrant | mysql -ANr -u "$user" -p"$password" -h"$host" 2>/dev/null
		display "Revoked $cg on $t" 3
		changes=1
	fi
}

parse_grants()
{
#	display "$1" 0
	(
		IFS="
"
		for row in $1
		do
			IFS=" "
			ga=($row)
			idx=0
			for w in ${ga[@]}
			do
				[ "${ga[$idx]}" = "ON" ] && break
				idx=$((idx + 1))
			done
			idx=$((idx - 1))
			what=$(echo ${ga[@]:1:$idx} | tr -d "[ ]")
			[ "$what" = "ALLPRIVILEGES" ] && continue
			w=$(($idx + 2))
			tschema=$(echo ${ga[$w]} | cut -d "." -f 1)
			table=$(echo ${ga[$w]} | cut -d "." -f 2)
			echo "$tschema $table $what"
		done 
		echo "$schema * .none"
		echo "select concat('$schema', ' ', table_name, ' .none') from information_schema.tables where table_schema  = '$schema'" | mysql -ANr -u "$service_user" -p"$service_password" -h"$host" 2>/dev/null 
	) | sort > $tmpf
	printf "<TABLE>\n" 
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	printf "<TH COLSPAN=2><FONT FACE=\"Arial\" SIZE=3>$schema grants for '%s'@'%s'</FONT></TH>\n"  $lgrant $rgrant
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	prev01=""
	prev2=""
	for row in $(cat $tmpf)
	do
		IFS=" "
		ga=($row)
		gn=$((${#ga[@]} - 2))
		if [ "${ga[0]}.${ga[1]}" != "$prev01" ]
		then
			[ "$prev01" != "" ] && printf "<TR><TD><FONT FACE=\"Arial\" SIZE=2>%s</FONT><TD><TD><FONT FACE=\"Arial\" SIZE=2>%s</FONT></TD></TR>\n" "$prev01" "$(format $prev01 $prev2)"
		fi
		prev01="${ga[0]}.${ga[1]}"
		prev2="${ga[2]}"
	done
	printf "<TR><TD><FONT FACE=\"Arial\" SIZE=2>%s</FONT><TD><TD><FONT FACE=\"Arial\" SIZE=2>%s</FONT></TD></TR>\n" "$prev01" "$(format $prev01 $prev2)"
	printf "<TR><TD COLSPAN=2>&nbsp;</TD></TR>\n"
	[ $can_grant -eq 1 ] && printf "<TR><TD COLSPAN=2 ALIGN=CENTER><INPUT TYPE=\"SUBMIT\" VALUE=\"UPDATE\">\n"
	printf "</TABLE>\n"
}

printf "Content-Type: text/html; charset=utf-8\n\n"
printf "<HTML>\n"
printf "<HEAD>\n"
printf "<TITLE>DBGranter v%s</TITLE>\n" "$VERSION"
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
	pname=""
	for row in $(tr "[&]" "[\n]")
	do
		name=$(echo $row | cut -d"=" -f 1)
		value=$(echo $row | cut -d"=" -f 2)
		value=$(unescape_input "$value")
		case "$name" in
			'user') user="$value";;
			'password') password="$value";;
			'host') host="$value";;
			'lgrant') lgrant="$value";;
			'rgrant') rgrant="$value";;
			'schema') schema="$value";;
			*)
				if [ "$pname" != "$name" ]
				then
					if [ "$pname" != "" ]
					then
						generate_grants $pname $s $os $i $oi $u $ou $d $od
					fi
					s=0
					os=0
					i=0
					oi=0
					u=0
					ou=0
					d=0
					od=0
				fi
				case "$value" in
					'select') s=1;;
					'oselect') os=1;;
					'insert') i=1;;
					'oinsert') oi=1;;
					'update') u=1;;
					'oupdate') ou=1;;
					'delete') d=1;;
					'odelete') od=1;;
				esac
				pname=$name
				;;
		esac
	done
	generate_grants $pname $s $os $i $oi $u $ou $d $od
fi
if [ $post -eq 1 ]
then
	post_checks
	case $post_error in
		0)	show_form block
			[ $changes -eq 0 ] && parse_grants "$grants"
			;;
		1)	show_form none;;
		2)	show_form block;;
	esac
else
	if [ "$service_user" = "" -o "$service_password" = "" ]
	then
		echo "Please ensure config file exists and contains required information"
		exit 0
	fi
	show_form none
fi
printf "</FORM>\n"
printf "$closing_tags\n"
exit 0
