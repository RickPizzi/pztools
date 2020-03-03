#include <errno.h>
#include <stdio.h>
#include <stdlib.h>
#include <unistd.h>
#include <string.h>

int main(argc, argv)
int argc;
char **argv;
{
	char buf[16384];
	char *p;
	int t;
	int c=0;
	FILE *f = NULL;
	char fn[32];

	if (argc != 2) {
		fprintf(stderr, "Usage: %s <target folder>\n", argv[0]);
		exit(1);
	}
	if (chdir(argv[1]) != 0) {
		perror(argv[1]);
		exit(1);
	}
	while(fgets(buf, sizeof(buf) - 1, stdin)) {
		c++;
		printf("%d\n", c); fflush(stdout);
		*(buf + strlen(buf) -1) = 0x00;
		if (!strncmp(buf + 8, " Query", 6) || !strncmp(buf + 8, " Connect", 8) || 
			!strncmp(buf + 8, " Quit", 5) || !strncmp(buf + 8, " Init DB", 8)) {
			*(buf + 8) = 0x00;
			t = atoi(buf + 2);
			printf("Thread %d\n", t);
			sprintf(fn, "%d.thread", t);
			if (f)
				fclose(f);
			if ((f = fopen(fn, "a")) == NULL) {
				perror(fn);
				exit(1);
			}
			*(buf + 8) = 0x20;
			fprintf(f, "%s\n", buf);
			continue;
		}
		if (!strncmp(buf + 22, " Query", 6) || !strncmp(buf + 22, " Connect", 8) || 
			!strncmp(buf + 22, " Quit", 5) || !strncmp(buf + 22, " Init DB", 8)) {
			*(buf + 22) = 0x00;
			t = atoi(buf + 16);
			printf("Thread %d\n", t);
			sprintf(fn, "%d.thread", t);
			if (f)
				fclose(f);
			if ((f = fopen(fn, "a")) == NULL) {
				perror(fn);
				exit(1);
			}
			*(buf + 22) = 0x20;
			fprintf(f, "%s\n", buf);
			continue;
		}
		if (f)
			fprintf(f, "%s\n", buf);
	}
	if (f)
		fclose(f);
	exit(0);
}
