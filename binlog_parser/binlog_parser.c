#
#	binlog_parser.c - ROW format compatible 
#	Rick Pizzi - pizzi@leopardus.com
#	
#	compile with: gcc -O3 -o binlog_parser binlog_parser.c
#
#	galera cluster compatible - must run on all nodes, will only
#	track deletes that happen on the master node
#
#	conf file is just a list of schema qualified table names 
#	that you want to track


/*
	create tracking table as follows:

	create table deletions (
		id bigint non null auto_increment priamry key,
		binlog_name varchar(100),
		event_date datetime,
		schema_name varchar (100),
		table_name varchar(100),
		where_condition varchar(200),
		key idx1(schema_name, table_name)
	);

*/

#define _GNU_SOURCE
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>

#define CONFIG_FILE     "/etc/binlog_parser.conf"
#define TRACKING_SCHEMA	"bi_tracking"
#define	TRACKING_TABLE	"deletions"
#define MAX_TABLES      100

#define TIMESTAMP_ENTRY "SET TIMESTAMP="

#define DELETE_ENTRY    "# DELETE FROM "
#define MAP_ENTRY       "Table_map: "
#define SERVER_ID	"server id"

static char *escape();
static void load_config();
static int table_configured();
void exit();

struct FilterT {
        char *table_schema;
        char *table_name;
};

static struct FilterT filtered_tables[MAX_TABLES];


int main(argc, argv)
int argc;
char **argv;
{
        char *p;
        char *q;
        char *z;
	char *k, *k2;
        time_t last_ts;
	char serverid[4096];
        char where[4096];
        char buf[8192];
        char st[256];
        char table[256], schema[256];
	int delete = 0;
        
	if (argc != 2) {
                fprintf(stderr, "usage: binlog_parser <binlog_name>\n");
                exit(1);
        }
        load_config();
	memset(serverid,0x00,sizeof(serverid));
        while(fgets(buf, sizeof(buf) - 1, stdin)) {
                *(buf + strlen(buf) - 1) = 0x00;
               // printf("DEBUG: %s\n", buf);
                if (!strncasecmp(buf, TIMESTAMP_ENTRY, strlen(TIMESTAMP_ENTRY))) {
                        if ((p = strchr(buf, '/')) == NULL)
                                fprintf(stderr, "unparsable timestamp\n");
                        else
                                *p = 0x00;
                        last_ts = (time_t) atol(buf + strlen(TIMESTAMP_ENTRY));
                        continue;
                }



                if (!strncasecmp(buf, DELETE_ENTRY, strlen(DELETE_ENTRY))) {
                        if ((p = strcasestr(buf, "where ")) != NULL) {
                                strcpy(where, escape(p + 6));
                                delete++;
                                continue;
                        }
                        else {
                                fprintf(stderr, "Unexpected error looking for where\n");
                                exit(1);
                        }
                }




              if ((k = strcasestr(buf, "server id")) != NULL) {
                        strcpy(serverid, k + 10);
			if ((k2 = strchr(serverid, ' ')) != NULL)
				*k2 = 0x00;
               }








                if (delete && (q = strcasestr(buf, MAP_ENTRY))!= NULL) {
                        if ((z = strchr(q + 11, ' ')) != NULL) {
                                *z = 0x00;
                                memset(st, 0x00, 256);
                                z=st;
                                for (p = q + 11; *p; p++)
                                        if (*p != '`')
                                                *z++ = *p;
                                if ((p = strchr(st, '.')) != NULL) {
                                        *p=0x00;
                                        strcpy(schema, st);
                                        strcpy(table, ++p);
                                }
                                else {
                                        fprintf(stderr, "Unexpected error parsing schema table\n");
                                        exit(1);
                                }
                                if (table_configured(schema, table))
                                        printf("INSERT INTO %s.%s  values (NULL,'%s', FROM_UNIXTIME(%u), '%s', '%s', '%s'); // galeraserverid=%s\n",
                                                                TRACKING_SCHEMA, TRACKING_TABLE, argv[1],(unsigned int)last_ts, schema, table, where, serverid);
                                delete--;

                        }
                        else {
                                fprintf(stderr, "Unexpected error looking for end of table map\n");
                                exit(1);
                        }
                }
        }
}


static char *escape(s)
char *s;
{
	static char buf[8192];
	char *p, *sp;
	
	memset(buf, 0x00, sizeof(buf));
	sp = buf;
	for (p = s; *p; p++) {
		if (*p == '\'' || *p == '\\')
			*sp++ = '\\';
		*sp++ = *p;
	}
	return(buf);
}

static void load_config()
{
        FILE *f;
        char buf[1024];
        char *p;
        int i = 0;

        if ((f = fopen(CONFIG_FILE, "r")) == NULL) {
                perror(CONFIG_FILE);
                exit(1);
        }
        while (fgets(buf, 1023, f)) {
                if (i == MAX_TABLES) {
                        fprintf(stderr, "More than %d tables configured, ignoring the extra ones\n", MAX_TABLES);
                        break;
                }
                *(buf + strlen(buf) - 1) = 0x00;
                if ((p = strchr(buf, '.')) == NULL) {
                        fprintf(stderr, "Syntax error near line '%s'\n", buf);
                        exit(1);
                }
                else
                        *p = 0x00;
                filtered_tables[i].table_schema  = strdup(buf);
                filtered_tables[i++].table_name  = strdup(++p);
        }
        fclose(f);
}

static int table_configured(s, n)
char *s;
char *n;
{
        int i;

        for (i = 0; i < MAX_TABLES; i ++) {
                if (filtered_tables[i].table_name == NULL)
                        break;
                if (!strcasecmp(s, filtered_tables[i].table_schema) && !strcasecmp(n, filtered_tables[i].table_name))
                        return(1);
        }
        return(0);
}
