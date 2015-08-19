#!/bin/bash
#
#	move grants for a specified user from one network to another
#	then optionally drop old grants
#
#	(c) 2015 riccardo.pizzi@rumbo.com
#
echo -n "User to clone: "
read user
echo -n "From network: "
read from_net
echo -n "To network: "
read to_net
echo -n "Password: "
stty -echo
read password
stty echo
echo
echo "show grants for '$user'@'$from_net'" | mysql -ANr -p$password | sed -e "s/'$user'@'$from_net'/'$user'@'$to_net'/g" -e "s/$/;/g" | mysql -f -A -p$password
while true
do
	echo -n "Drop user '$user'@'$from_net'? y/N "
	read yn
	case "${yn,,}" in
		'n'|'')	break;;
		'y') 	echo "drop user '$user'@'$from_net'" | mysql -A -p$password
			break;;
	esac
done
exit 0
