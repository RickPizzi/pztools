/*

	binspector - filters a binlog file and shows transactions that took more than X seconds

	gcc -O3 -o binspector binspector.c

	(C) 2022 Rick Pizzi pizzi@leopardus.com


*/

#define _XOPEN_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

static char * pretty_t();

static char *pretty_t(t1, t2)
time_t t1, t2;
{
	static char buf[128];
	char tbuf[64];

	strftime(tbuf, sizeof(tbuf), "%T", gmtime(&t1));
	sprintf(buf, "started %s ", tbuf);
	strftime(tbuf, sizeof(tbuf), "%T", gmtime(&t2));
	strcat(buf, "ended ");
	strcat(buf, tbuf);
	return(buf);
}

main(argc, argv)
int argc;
char **argv;
{
	char buf [1024];
	struct tm tm;
	time_t t, log_t, start_t, min_t;
	int tr=0;
	long pos = 0L, start_p, n;

	if (argv[1] != NULL)
		min_t = atoi(argv[1]);
	else
		min_t = 1;
	while(fgets(buf, 1023, stdin)) {
		*(buf + strlen(buf) - 1) = 0x00;
		if (!strcmp(buf, "START TRANSACTION") || !strcmp(buf, "BEGIN")) {
			tr=1;
			start_t=0;
			start_p=pos;
		}
		if (!strcmp(buf, "COMMIT/*!*/;")) {
			tr=0;
			if (t - start_t >= min_t) {
				if (fgets(buf, 1023, stdin) != NULL) 
					if (sscanf(buf, "# at %ld", &n))
						pos=n;
				printf("%ld - %ld %s runtime %ds\n", start_p, pos, pretty_t(start_t, t), (int)(t - start_t));
				continue;
			}
		}
		if (strptime(buf, "#%y%m%d%t%T%tserver", &tm) != NULL) {
			t=timegm(&tm);
			if (tr && !start_t)
				start_t=t;
		}
		if (sscanf(buf, "# at %ld", &n))
			pos=n;
	}
}
