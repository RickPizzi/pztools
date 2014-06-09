#include <stdio.h>
#include <unistd.h>
#include <string.h>

// parser for 5.5 Percona
// rpizzi@blackbirdit.com
// compile with: gcc -O3 -o parser parser55.c
// feed collected sample(s) into the executable via stdin pipe

#define	VERSION	"1.0 for Percona 5.5"
#define	LOCK_WARNING	1000
#define LOCK_CRITICAL	10000
#define	RUNTIME_WARNING	3
#define RUNTIME_CRITICAL 10

static void print_transaction();

struct Transaction {
	char id[16];
	char status[256];
	char from[64];
	char user[64];
	char query[16384];
	char lock_info[16384];
	int running_time;
	int rows_locked;
};

static int all_transactions, lock_info;

int main(argc, argv)
int argc;
char **argv;
{
	char buf[1024], buf2[256];
	char *p;
	char timestamp[24];
	int c, sc = 0, tr = 0;
	int queries, views, transactions, history;
	struct Transaction t;
	int opt;
	
	while ((opt = getopt(argc, argv, "alhv")) != -1) {
		switch (opt) {
			case 'a':
                   		all_transactions++;
				break;
			case 'l':
                   		lock_info++;
				break;
			default: 
				fprintf(stderr, "InnoDB parser %s\n", VERSION);
				fprintf(stderr, "by rpizzi@blackbirdit.com\n\n");
				fprintf(stderr, "Usage: %s [-a] [-l]\n", argv[0]);
				fprintf(stderr, "\t-a   show all transactions even those without running queries\n");
				fprintf(stderr, "\t-l   show transaction lock information when available\n");
				exit(1);
				break;
		}
	}
	while (fgets(buf, 1023, stdin)) {
		*(buf + strlen(buf) - 1) = 0x00;
		if (strstr(buf, "INNODB MONITOR OUTPUT") && strstr(buf, "END OF") == NULL) {
			*(buf + 16) = 0x00;
			printf("Sample #%d, %s\n", ++sc, buf);
			tr=0;
			continue;
		}
		if (strstr(buf, "queries inside InnoDB")) {
			*(strchr(buf, 'q')) = 0x00;
			queries = atoi(buf);
			continue;
		}
		if (strstr(buf, "read views open inside InnoDB")) {
			*(strchr(buf, 'r')) = 0x00;
			views  = atoi(buf);
			continue;
		}
		if (strstr(buf, "transactions active inside InnoDB")) {
			*(strchr(buf, 't')) = 0x00;
			transactions  = atoi(buf);
			continue;
		}
		if (strstr(buf, "History list length")) {
			history  = atoi(buf + 19);
			printf("Queries: %d  Views: %d  Transactions: %d  History len: %d\n", 
								queries, views, transactions, history);
			continue;
		}
		if (!strncmp(buf, "---TRANSACTION ", 15)) {
			if (tr) {
				print_transaction(&t);
			}
			else
				printf("--------------------------------------------------------------\n");
			tr = 1;
			memset(&t, 0x00, sizeof(struct Transaction));
			p = strchr(buf + 15, ',');
			*p = 0x00;
			strcpy(t.id, buf + 15);
			strcpy(t.status, p +1);
			*p = ',';
			if ((p = strstr(buf, "ACTIVE "))) {
				*(strchr(p + 7, ' ')) = 0x00;
				t.running_time = atoi(p + 7);
			}
			continue;
		}
 		if (strstr(buf, "MySQL thread id")) {
			strtok(buf, ",");
			while ((p = strtok(NULL, ",")) != NULL)
				strcpy(buf2, p);
			strtok(buf2, " ");
			c = 0;
			while ((p = strtok(NULL, " ")) != NULL) {
				switch(c++) {
					case 2:
						strcpy(t.from, p);
						break;
					case 3:
						strcpy(t.user, p);
						break;
				}
			}
			continue;
		}
		if (!strncmp(buf, "TABLE LOCK ", 11) || !strncmp(buf, "RECORD LOCKS ", 13) || strstr(buf, "TOO MANY LOCKS PRINTED FOR THIS TRX")) {
			if (tr) {
				strcat(t.lock_info, buf);
				strcat(t.lock_info, "\n");
			}
			continue;
		}
 		if (strstr(buf, "row lock(s)")) {
			strtok(buf, ",");
			c=0;
			while ((p = strtok(NULL, ",")) != NULL) {
				switch(c++) {
					case 1:
						*(strchr(p + 1, ' ')) = 0x00;
						t.rows_locked = atoi(p);
						break;
				}
			}
			continue;
		}
 		if (strstr(buf, "mysql tables in use"))
			continue;
 		if (strstr(buf, "Trx read view will not see trx"))
			continue;
		if (tr && !strcmp(buf, "----------------------------")) {
			print_transaction(&t);
			tr=0;
			continue;
		}
		if (tr) {
			strcat(t.query, buf);
			strcat(t.query, "\n");
			continue;
		}
//		printf("NOT INTERESTING -> %s\n", buf);
	}
	exit(0);
}

static void print_transaction(t)
struct Transaction *t;
{
	char *status;

	if (!strlen(t->query) && !all_transactions)
		return;
	if (strstr(t->query, "show engine innodb status") && !all_transactions)
		return;
	status = "OK";
	if (t->running_time >= RUNTIME_WARNING)
		status = "RT_WARNING";
	if (t->running_time >= RUNTIME_CRITICAL)
		status = "RT_CRITICAL";
	if (strpbrk(t->from, ".1234567890"))
		printf("Transaction id %s, runtime %d secs (%s), %s@%s state: %s\n",
						 t->id, t->running_time, status, t->user, t->from, t->status);
	else
		printf("Transaction id %s, runtime %d secs (%s), state: %s %s\n", 
						t->id, t->running_time, status, t->from, t->user);
	if (t->rows_locked) {
		status = "OK";
		if (t->rows_locked >= LOCK_WARNING)
			status = "LOCK_WARNING";
		if (t->rows_locked >= LOCK_CRITICAL)
			status = "LOCK_CRITICAL";
		printf("Rows locked %d (%s)\n", t->rows_locked, status);
	}
	printf("%s\n", t->query);
	if (lock_info)
		printf("%s\n", t->lock_info);
}
