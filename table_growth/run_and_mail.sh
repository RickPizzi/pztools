#!/bin/bash
#
#
RECIPIENTS="rpizzi@blackbirdit.com"
(
	echo 'From: Health Checks <root@host>'
	echo "To: $RECIPIENTS"
	echo "Subject: table growth statistics"
	echo 'MIME-Version: 1.0'
	echo 'Content-Type: text/html'
	echo 'Content-Disposition: inline'
	echo '<html>'
	echo '<body>'
	echo '<pre style="font: monospace">'
	/root/Table_Growth/pz-schema-growth.sh
	/root/Table_Growth/pz-table-growth.sh size
	/root/Table_Growth/pz-table-growth.sh delta
	/root/Table_Growth/pz-table-growth.sh percent
	echo '</pre>'
	echo '</body>'
	echo '</html>'
) | /usr/sbin/sendmail -t
exit 0
