#include <stdlib.h>
#include <stdio.h>
#include <strings.h>
#include <errno.h>
#include <sys/stat.h>
#include <memory.h>

static void rollback_args();
static void get_columns();
static void index_in_use();
static void pretty_print();
static void insert_vars();
static void check_pk_use();
static void verify_column_names();
static void total_query_count();
static void array_idx();

static char *u_replace_in_string();
static char *u_replace_in_string_eol();
static int u_blank_string();
static int u_quotes_in_string();
static int u_string_is_number();
static int u_words_in_string();
static int u_check_if_match();
static int u_quote_open();

static int debug = 0;

main(argc, argv)
int argc;
char **argv;
{
	if (argc < 2)
		exit(0);
	if (!strcmp(argv[1], "rollback_args")) {
		rollback_args(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "get_columns")) {
		get_columns(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "index_in_use")) {
		index_in_use(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "pretty_print")) {
		pretty_print(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "array_idx")) {
		array_idx(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "total_query_count")) {
		total_query_count(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "insert_vars")) {
		insert_vars(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "check_pk_use")) {
		check_pk_use(argc, argv);
		exit(0);
	}
	if (!strcmp(argv[1], "verify_column_names")) {
		verify_column_names(argc, argv);
		exit(0);
	}
	fprintf(stderr, "Unknown function %s\n", argv[1]);
	exit(1);
}

/*
	ARGS:
	2 > column list
*/

static void rollback_args(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r;
	int c=0;

	if (argc < 3)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = strdup(argv[2]);
	b = r;
	printf("CONCAT(");
	for (p = r; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				*p = 0x00;
				if (!u_blank_string(b)) {
					if (c)
						printf(",',',");
					printf("'%s= ', IF(%s IS NOT NULL, QUOTE(%s),'NULL')", b, b, b);
					c++;
				}
				b = p + 1;
				break;
		}
	}
	if (!u_blank_string(b)) {
		if (c)
			printf(",',',");
		printf("'%s= ', IF(%s IS NOT NULL, QUOTE(%s),'NULL')", b, b, b);
	}
	printf(")\n");
}

/*
	ARGS:
	2 > update set arguments
*/

static void get_columns(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r;
	int qo=0;

	if (argc < 3)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = strdup(argv[2]);
	b = r;
	for (p = r; *p; p++) {
		switch(*p) {
			case '\'':
				if (qo)
					qo=0;
				else
					qo=1;
				break;
			case ',':
				if (!qo)
					b = p + 1;
				break;
			case '=':
				*p = 0x00;
				if (!qo)
					printf("%s ", b);
				b = p + 1;
				break;
		}
	}
	printf("\n");
}

/*
	ARGS:
	2 > cardinfo file
	3 > cols_used
	4 > min_req_cardinality
*/

static void index_in_use(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r, *idx_col, *idx_name;
	FILE *f;
	char buf[256];
	int i, idx_seq, idx_card, idx_size, mc = 0, msz=0, min_card, done = 0, ocard;
	char oidx[64];
	char ocol[64];
	unsigned char sc;
	int mdebug=0, good_one = 0;

	if (argc < 5)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = strdup(argv[3]);
	min_card = atoi(argv[4]);
	if ((f = fopen(argv[2], "r")) == NULL) {
		if (errno == ENOENT) 
			return;
		fprintf(stderr, "%s: fopen: %s: error %d\n", argv[1], argv[2], errno);
		exit(1);
	}
	*oidx = 0x00;
	while (fgets(buf, 255, f)) {
		*(buf + strlen(buf) - 1) = 0x00;
		b = buf; 
		i=0;
		for (p = buf; *p; p++) {
			if (*p == 0x09) {
				*p = 0x00;
				switch(i) {
					case 0:
						idx_col = strdup(b);
						break;
					case 1:
						idx_seq = atoi(b);
						break;
					case 2:
						idx_card = atoi(b);
						break;
					case 3:
						idx_name = strdup(b);
						break;
				}
				b = p + 1;
				i++;
			}
		}
		idx_size = atoi(b);
		if (mdebug)
			printf("INDEX: col %s seq %d card %d name %s size=%d\n", idx_col, idx_seq, idx_card, idx_name, idx_size);
		if (strcasecmp(idx_name, oidx)) {
			if (msz) {
				if (mdebug) {
					printf("Found usable index %s\n", oidx);
				}
				done++;
				idx_name = oidx;
				idx_card = ocard;
				idx_col = ocol;
				break;
			}
			mc=0;
			strcpy(oidx, idx_name);
			strcpy(ocol, idx_col);
			ocard = idx_card;
		}
		b = r;
		for (p = r; *p; p++) {
			switch(*p) {
				case 0x20:
				case 0x09:
				case 0x0a:
					sc = *p;
					*p = 0x00;
					if (u_check_if_match(b, idx_col, NULL, 0)) {
						if (idx_seq > 1) {
							if (mc < idx_seq -1) {
								if (mdebug)
									printf("Matched but out of seq\n");
							}
							else
								mc++;
						}
						else
							mc++;
						if (mc == idx_seq) {
							msz++;
							if (mdebug)
								printf("POSITIVE  MATCH for %s, %d of %d\n", idx_name, msz, idx_size);
							good_one++;
							if (msz == idx_size) {
								if (mdebug)
									printf("FULL MATCH for %s\n", idx_name);
								done++;
							}
						}
					}
					*p = sc;
					b = p + 1;
					break;
			}
			if (done)
				break;
		}
		if (u_check_if_match(b, idx_col, NULL, 0)) {
			if (idx_seq > 1) {
				if (mc < idx_seq -1) {
					if (mdebug)
						printf("Matched but out of seq\n");
				}
				else
					mc++;
			}
			else
				mc++;
			if (mc == idx_seq) {
				msz++;
				 if (mdebug)
					printf("POSITIVE  MATCH for %s, %d of %d\n", idx_name, msz, idx_size);
				good_one++;
				if (msz == idx_size) {
					if (mdebug)
						printf("FULL MATCH for %s\n", idx_name);
					done++;
				}
			}
		}
		if (done)
			break;
	}
	fclose(f);
	if (done || msz) {
		if (mdebug)
			printf("Satisfying index found %s.\n", idx_name);
		if (strcmp(idx_name, "PRIMARY"))  {
			if (idx_card < min_card) {
				printf("NOTICE: index %s (on %s) has very low cardinality, and will be skipped. Enable <I>ninja mode</I> to use it regardless.\n", idx_name, idx_col);
				if (good_one)
					exit(0);
			}
			else
				exit(0);
		}
		else
			exit(0);
	}
	exit(1);
}

/*
	ARGS:
	2 > string to print
*/

static void pretty_print(argc, argv)
int argc;
char **argv;
{
	int wc = 0;
	char *b, *p, *r;
	unsigned char sc;

	if (argc < 2)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = strdup(argv[2]);
	b = r;
	for (p = r; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				sc = *p;
				*p = 0x00;
				printf("%s", b);
				if (wc++ == 15) {
					printf("<BR>");
					wc=0;
				}
				else
					printf(" ");
				*p = sc;
				b = p + 1;
				break;
		}
	}
	printf("%s", b);
}

/*
	ARGS:
	2 > where condition
	3 > string to search for
*/

static void array_idx(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r;
	unsigned char sc;
	int idx = -1;

	if (argc < 3)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = strdup(argv[2]);
	b = r;
	for (p = r; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				sc = *p;
				*p = 0x00;
				if (!u_blank_string(b)) {
					if (u_check_if_match(b, argv[3], NULL, 0)) {
						printf("%d\n", idx);
						return;
					}
				}
				idx++;
				*p = sc;
				b = p + 1;
				break;
		}
	}
	if (!u_blank_string(b)) {
		if (u_check_if_match(b, argv[3], NULL, 0)) {
			printf("%d\n", idx);
			return;
		}
	}
	printf("-1\n");
}

/*
	ARGS:
	2 > query filename
*/

static void total_query_count(argc, argv)
int argc;
char **argv;
{
	char *p;
	int q = 0;
	int c=0;
	FILE *f;
	char *wb;
	struct stat s;

	if (argc < 2)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	if (stat(argv[2], &s) == -1) {
		fprintf(stderr, "%s: stat : %s: error %d\n", argv[1], argv[2], errno);
		exit(1);
	}
	if ((wb = calloc(s.st_size, 1)) == NULL) {
		fprintf(stderr, "out of memory\n");
		exit(1);
	}
	if ((f = fopen(argv[2], "r")) != NULL) {
		fread(wb, s.st_size, 1, f);
		fclose(f);
	}
	for (p = wb; *p; p++) {
		if (*p == 0x27) {
			if (p > wb  && *(p - 1) != 0x5c)
				q = !q;
		}
		if (*p == ';' && !q)
			c++;
	}
	printf("%d\n", c);
}

/*
	ARGS:
	2 > where condition
	3 > columns list
*/

static void verify_column_names(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r, *i;
	unsigned char sc;
	static char cl[1048576];
	static char *ign_list = "= IS NOT NULL LIKE AND OR > < BETWEEN <= >= IN ( ) , <>";

	if (argc < 3)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	r = u_replace_in_string(argv[2], "=", " = ");
	r = u_replace_in_string(r, "(", " ( ");
	r = u_replace_in_string(r, ")", " ) ");
	r = u_replace_in_string(r, ",", " , ");
	if (debug)
		printf("verify_column: input string 1 --%s--\n", r);
	r = u_replace_in_string(r, "`.`.", ".");
	if (debug)
		printf("verify_column: input string 2 --%s--\n", r);
	r = u_replace_in_string(r, "`", " ");
	b = r;
	i = strdup(ign_list);
	if (debug)
		printf("verify_column: input string --%s--\n", r);
	for (p = r; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				sc = *p;
				*p = 0x00;
				if (!u_blank_string(b))
					if (!u_quote_open(r))
						if (*b != '@')
							if (!u_string_is_number(b))
								if (!u_quotes_in_string(b))
									if (!u_check_if_match(b, i, NULL, 0))
										if (!u_check_if_match(b, argv[3], cl, 0)) {
											printf("%s\n", b);
											exit(1);
										}
				*p = sc;
				b = p + 1;
				break;
		}
	}
	if (!u_blank_string(b))
		if (!u_quote_open(r))
			if (*b != '@')
				if (!u_string_is_number(b))
					if (!u_quotes_in_string(b))
						if (!u_check_if_match(b, i, NULL, 0))
							if (!u_check_if_match(b, argv[3], cl, 0)) {
								printf("%s\n", b);
								exit(1);
							}
	printf("%s\n", cl);
}

/*
	ARGS:
	2 > where condition
	3 > primary key
*/

static void check_pk_use(argc, argv)
int argc;
char **argv;
{
	char *b, *p, *r;
	int c = 0, n;

	if (argc < 3)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	n = u_words_in_string(argv[3]);
	r = u_replace_in_string(argv[2], ", ", ",");
	b = r;
	for (p = r; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				*p = 0x00;
				if (!u_blank_string(b))
					c += u_check_if_match(b, argv[3], NULL, 1);
				b = p + 1;
				break;
		}
	}
	if (!u_blank_string(b))
		c += u_check_if_match(b, argv[3], NULL, 1);
	printf("%d\n", c == n);
}

static int u_check_if_match(s, ml, cl, sp)
char *s, *ml;
char *cl;
int sp;	// special case
{
	char *b, *p, *dn;

	if (debug)
		printf("Checking --%s--\n", s);
	b = ml;
	dn = strdup(s);
	if (sp) {
		if ((p = strchr(dn, '=')) != NULL)
			if (strlen(dn) > 1)
				*p = 0x00;
		s = dn;
		if ((p = strrchr(dn, '.')) != NULL)
			s = ++p;
	}
	for (p = ml; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				*p = 0x00;
				if (debug)
					printf("Comparing %s with %s\n", s, b);
				if (!strcasecmp(s, b)) {
					*p = 0x20;
					if (debug)
						printf("MATCH\n");
					if (cl) {
						strcat(cl, s);
						strcat(cl, " ");
					}
					free(dn);
					return(1);
				}
				*p = 0x20;
				b = ++p;
				break;
		}
	}
	if (debug)
		printf("Comparing %s with %s\n", s, b);
	if (!strcasecmp(s, b)) {
		if (debug)
			printf("MATCH\n");
		if (cl) {
			strcat(cl, s);
			strcat(cl, " ");
		}
		free(dn);
		return(1);
	}
	free(dn);
	return(0);
}

/*
	ARGS:
	2 > $vars_tmpf
	3 > query
	4 > $last_id
*/

#define MAX_VAR_VAL_LENGTH	65536

static void insert_vars(argc, argv)
int argc;
char **argv;
{
	FILE *f;
	char buf[MAX_VAR_VAL_LENGTH], replace_this[64], replace_with[MAX_VAR_VAL_LENGTH];
	char *r, *p, *var_name, *var_value;

	if (argc < 4)  {
		fprintf(stderr, "%s: not enough arguments\n", argv[1]);
		exit(1);
	}	
	if (argc == 5)
		r = u_replace_in_string(argv[3], "@last_insert_id", argv[4]);
	else
		r = argv[3];
	if ((f = fopen(argv[2], "r")) == NULL) {
		if (errno == ENOENT) {		// file may be non existent if no vars in use
			printf("%s\n", r);
			return;
		}
		fprintf(stderr, "%s: fopen: %s: error %d\n", argv[1], argv[2], errno);
		exit(1);
	}
	while (fgets(buf, MAX_VAR_VAL_LENGTH - 1, f)) {
		*(buf + strlen(buf) - 1) = 0x00;
		if ((p = strchr(buf, 0x09)) == NULL) {
			fprintf(stderr, "%s: %s: format error\n", argv[1], argv[2]);
			exit(1);
		}
		*p = 0x00;
		var_name = buf;
		var_value = ++p;
		sprintf(replace_this, "@%s,", var_name);
		sprintf(replace_with, "'%s',", var_value);
		r = u_replace_in_string(r, replace_this, replace_with);
		sprintf(replace_this, "@%s)", var_name);
		sprintf(replace_with, "'%s')", var_value);
		r = u_replace_in_string(r, replace_this, replace_with);
		sprintf(replace_this, "@%s ", var_name);
		sprintf(replace_with, "'%s' ", var_value);
		r = u_replace_in_string(r, replace_this, replace_with);
		sprintf(replace_this, "@%s", var_name); // fine riga
		sprintf(replace_with, "'%s'", var_value);
		r = u_replace_in_string_eol(r, replace_this, replace_with);
		sprintf(replace_this, "@%s+", var_name);
		sprintf(replace_with, "'%s'+", var_value);
		r = u_replace_in_string(r, replace_this, replace_with);
		sprintf(replace_this, "@%s-", var_name);
		sprintf(replace_with, "'%s'-", var_value);
		r = u_replace_in_string(r, replace_this, replace_with);
	}
	fclose(f);
	printf("%s\n", r);
}

/*
	search in s1 for s2 and replace with s3
*/

static char *u_replace_in_string(s1, s2, s3)
char *s1, *s2, *s3;
{
	char *b, *p, *p2, *p3;

	if ((b = malloc(strlen(s1) *16)) == NULL) {
		fprintf(stderr, "out of memory!\n");
		exit(1);
	}
	memset(b, 0x00, strlen(s1) * 16);
	p2 = b;
	for (p = s1; *p; p++) {
		if (!strncasecmp(p, s2, strlen(s2))) {
			for (p3 = s3; *p3; p3++)
				*p2++ = *p3;
			p += strlen(s2) - 1;
		}
		else
			*p2++ = *p;	
	}
	return(b);
}

static char *u_replace_in_string_eol(s1, s2, s3)
char *s1, *s2, *s3;
{
	char *b, *p, *p2, *p3;

	if ((b = malloc(strlen(s1) * 16)) == NULL) {
		fprintf(stderr, "out of memory!\n");
		exit(1);
	}
	memset(b, 0x00, strlen(s1) * 16);
	p2 = b;
	for (p = s1; *p; p++) {
		if (!strncasecmp(p, s2, strlen(s2))) {
			if (*(p + strlen(s2)) == 0x00) {
				for (p3 = s3; *p3; p3++)
					*p2++ = *p3;
				break;
			}
			else
				*p2++ = *p;	
		}
		else
			*p2++ = *p;	
	}
	return(b);
}

static int u_blank_string(s)
char *s;
{
	char *p;

	for (p = s; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				break;
			default:
				return(0);
		}
	}
	return(1);
}

static int u_quotes_in_string(s)
char *s;
{
	char *p; 

	for (p = s; *p; p++)
		if (*p == 0x27)
			return(1);
	return(0);
}

static int u_words_in_string(s)
char *s;
{
	int c = 0;
	char *b, *p;
	unsigned char sc;

	b = s;
	for (p = s; *p; p++) {
		switch(*p) {
			case 0x20:
			case 0x09:
			case 0x0a:
				sc = *p;
				*p = 0x00;
				if (!u_blank_string(b))
					c++;
				*p = sc;
				b = ++p;
				break;
		}
	}
	if (!u_blank_string(b))
		c++;
	return(c);
}

static int u_quote_open(s)
char *s;
{
	char *p;
	int c = 0;

	for (p = s; *p; p++) {
		if (*p == 0x27) {
			//if (p == s)
				//continue;
			if (p == s || *(p - 1) != 0x5c)
				c++;
		}
	}
	return(c%2);
}

static int u_string_is_number(s)
char *s;
{
	char *p;

	for (p = s; *p; p++) {
		switch(*p) {
			case '0':
			case '1':
			case '2':
			case '3':
			case '4':
			case '5':
			case '6':
			case '7':
			case '8':
			case '9':
			case '.':
			case '-':
				break;
		default:
			return(0);
		}
	}
	return(1);
}
