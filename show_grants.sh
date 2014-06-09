#!/bin/bash
#
# show all grants for a given DB, without having to install percona toolkit 
#
echo -n Password: 
stty -echo
read p
stty echo
echo "SELECT CONCAT('show grants for ',User,'@\'',Host,'\';') from mysql.user" | mysql --skip-column-names -uroot -p$p | mysql -t -uroot -p$p
