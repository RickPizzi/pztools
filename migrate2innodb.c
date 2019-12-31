/*

	migrate to InnoDB
	converts MyISAM and Aria and whatever else you may have as engine, to InnoDB
	It replaces Engine=... in CREATE TABLE, and also converts any (var)char longer than
	the specified length to a (TINY)TEXT. This to avoid the row too large error.

	usage:

	gcc -O3 -o migrate2innodb migrate2innodb.c
	cat yourdump.sql | ./migrate2innodb maxcharlen logfile | mysql -A -u... schema

	the logfile will contain a list of the converted columns, if any

	Note: do NOT include the "mysql" schema in the dump, that should not be converted
*/

#include <stdlib.h>
#include <stdio.h>
#include <string.h>
#include <malloc.h>

#define MAX_SKIPS	512
#define MAX_LINE_SIZE	16777216
#define TMPFILE	"/tmp/migrate2innodb.XXXXXX"

static char *xtract_cols();
static void read_create_table();
static void replace_log();

static struct SkipCol {
	char columns[512];
	char keytype[32];
} skipcol[MAX_SKIPS];

static int skidx;

main(argc, argv)
int argc;
char **argv;
{
	static char buf[MAX_LINE_SIZE];
	char *p1;
	int ct = 0;
	FILE *f;
	char t[256];
	char tmpl[256];
	char *tmpfn;

	if (argc != 3) {
		fprintf(stderr, "usage: %s <max_char_len> <logfile>\n", argv[0]);
		exit(1);
	}
	while(fgets(buf, MAX_LINE_SIZE -1, stdin)) {
		*(buf + strlen(buf) -1 ) = 0x00;
		if (!strncmp(buf, "CREATE TABLE ", 13)) {
			ct++;
			skidx=0;
			strcpy(t, buf + 12);
			*(strchr(t, '(')) = 0x00;
			strcpy(tmpl, TMPFILE);
			tmpfn = mktemp(tmpl);
			f = fopen(tmpfn, "w");
		}
		if (ct) {
			if (!strncmp(buf, "  PRIMARY KEY ", 14)) {
				if ((p1 = xtract_cols(buf)) != NULL) {
					strcpy(skipcol[skidx].columns, p1);
					strcpy(skipcol[skidx++].keytype, "PRIMARY KEY");
				}
			}
			if (!strncmp(buf, "  UNIQUE KEY ", 13)) {
				if ((p1 = xtract_cols(buf)) != NULL) {
					strcpy(skipcol[skidx].columns, p1);
					strcpy(skipcol[skidx++].keytype, "UNIQUE KEY");
				}
			}
			if (!strncmp(buf, "  KEY ", 6)) {
				if ((p1 = xtract_cols(buf)) != NULL) {
					strcpy(skipcol[skidx].columns, p1);
					strcpy(skipcol[skidx++].keytype, "INDEX");
				}
			}
			if (skidx == MAX_SKIPS) {
				fprintf(stderr, "out of memory - please increase MAX_SKIPS and recompile\n");
				exit(1);
			}
			fprintf(f, "%s\n", buf);
			if (*(buf + strlen(buf) - 1) == ';') {
				ct--;
				fclose(f);
				read_create_table(t, atoi(argv[1]), argv[2], tmpfn);
				unlink(tmpfn);
				skidx=0;
			}
			continue;
		}
		printf(" %s\n", buf);
	}
}

static void read_create_table(t, maxlen, l, fn)
char *t;
int maxlen;
char *l;
char *fn;
{
	static char buf[MAX_LINE_SIZE];
	char *p0, *p1,*p2,*p3, *p4;
	FILE *f;
	int i, len;
	int skip=0;
	char r[256];

	f = fopen(fn, "r");
	while (fgets(buf, MAX_LINE_SIZE - 1, f)) {
		*(buf + strlen(buf) -1 ) = 0x00;
		if ((p0 = strstr(buf, " char(")) != NULL) {
			p2 = strchr(p0, ')');
			*p2 = 0x00;
			len=atoi(p0+6);
			*p2=')';
			if (len >= maxlen) {
				for (i = 0; i < skidx; i++) {
					if ((p1 = strchr(buf + 2, ' ')) != NULL) {
						*p1 = 0x00;
						if (strstr(skipcol[i].columns, buf + 2)) {
							sprintf(r, "%s, used in %s(%s)", buf + 2, skipcol[i].keytype, skipcol[i].columns);
							replace_log(l, t, "skipped", r);
							skip++;
						}
						*p1 = 0x20;
					}
				}
				if (!skip) {
					if ((p3 = strchr(buf + 2, ' ')) != NULL)
						if ((p4 = strchr(++p3, ' ')) != NULL)
							*p4=0x00;
					replace_log(l, t, "replaced", buf + 2);
					if (p4)
						*p4 = 0x20;
					*p0 = 0x00;
					printf("%s%s%s\n", buf, len < 256 ? " tinytext" : " text", ++p2);
					continue;
				}
				else
					skip=0;
			}
		}
		if ((p0 = strstr(buf, " varchar(")) != NULL) {
			p2 = strchr(p0, ')');
			*p2 = 0x00;
			len=atoi(p0+9);
			*p2=')';
			if (len >= maxlen) {
				for (i = 0; i < skidx; i++) {
					if ((p1 = strchr(buf + 2, ' ')) != NULL) {
						*p1 = 0x00;
						if (strstr(skipcol[i].columns, buf + 2)) {
							sprintf(r, "%s, used in %s(%s)", buf + 2, skipcol[i].keytype, skipcol[i].columns);
							replace_log(l, t, "skipped", r);
							skip++;
						}
						*p1 = 0x20;
					}
				}
				if (!skip) {
					if ((p3 = strchr(buf + 2, ' ')) != NULL)
						if ((p4 = strchr(++p3, ' ')) != NULL)
							*p4=0x00;
					replace_log(l, t, "replaced", buf + 2);
					if (p4)
						*p4 = 0x20;
					*p0 = 0x00;
					printf("%s%s%s\n", buf, len < 256 ? " tinytext" : " text", ++p2);
					continue;
				}
				else
					skip=0;
			}
		}
		if (!strncmp(buf, ") ENGINE=", 9)) {
			if ((p1 = strchr(buf + 9, 0x20)) != NULL)
				printf(") ENGINE=InnoDB %s\n", p1);
		}
		else
			printf("%s\n", buf);
		skip=0;
	}
	fclose(f);
}

static void replace_log(l, t, w, d)
char *l, *t, *w, *d;
{
	FILE *f;

	if ((f = fopen(l, "a")) != NULL) {
		fprintf(f, "%s: %s %s\n", t, w, d);
		fclose(f);
	}
}

static char *xtract_cols(s)
char *s;
{
	char *p;
	static char buf[MAX_LINE_SIZE];
	static char ldef[256];

	strcpy(buf, s);
	if ((p = strrchr(buf, ')')) != NULL)
		*p = 0x00;
	else
		return(NULL);
	if ((p = strrchr(buf, '(')) != NULL)
		strcpy(ldef, ++p);
	else
		return(NULL);
	return(ldef);
}

