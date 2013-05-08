//
//  interpret.c
//  filagree
//

#include <unistd.h>
#include "vm.h"
#include "compile.h"
#include "interpret.h"

#define FG_MAX_INPUT     256
#define ERROR_USAGE    "usage: filagree [file]"

bool run(struct context *context,
         struct byte_array *program,
         struct map *env,
         bool in_context);

void repl()
{
    char str[FG_MAX_INPUT];
    struct context *context = context_new(true, true, NULL);

    for (;;) {
        fflush(stdin);
        str[0] = 0;
        printf("f> ");
        if (!fgets(str, FG_MAX_INPUT, stdin)) {
            if (feof(stdin))
                return;
            if (ferror(stdin)) {
                printf("unknown error reading stdin\n");
                return;
            }
        }

        struct byte_array *input = byte_array_from_string(str);
        struct byte_array *program = build_string(input);
        if (!setjmp(trying))
            run(context, program, NULL, true);
        byte_array_del(input);
        byte_array_del(program);
    }

    context_del(context);
}

void interpret_file(const struct byte_array *filename, find_c_var *find)
{
    struct byte_array *program = build_file(filename);
    execute(program, find);
    byte_array_del(program);
}

void execute_file(const struct byte_array* filename, find_c_var *find)
{
    struct byte_array *program = read_file(filename);
    execute(program, find);
}

void run_file(const char* str, find_c_var *find, struct map *env)
{
    struct byte_array *filename = byte_array_from_string(str);
    struct byte_array *dotfgbc = byte_array_from_string(EXTENSION_BC);
    struct byte_array *dotfg = byte_array_from_string(EXTENSION_SRC);

    int fgbc = byte_array_find(filename, dotfgbc, 0);
    if (fgbc > 0) {
        execute_file(filename, find);
        return;
    }
    int fg = byte_array_find(filename, dotfg, 0);

    if (fg > 0)
        interpret_file(filename, find);
    else
        fprintf(stderr, "invalid file name\n");

    byte_array_del(filename);
    byte_array_del(dotfg);
    byte_array_del(dotfgbc);
}

void interpret_string(const char *str, find_c_var *find)
{
    struct byte_array *input = byte_array_from_string(str);
    struct byte_array *program = build_string(input);
    execute(program, find);
    byte_array_del(input);
    byte_array_del(program);
}

#ifdef CLI

#include <signal.h>

void sig_handler(const int sig)
{
	printf("\nSIGINT handled.\n");
    exit(1);
}

int main (int argc, char** argv)
{
	struct sigaction act, oact; // for handling ctrl-c
	act.sa_handler = sig_handler;
	sigemptyset(&act.sa_mask);
	act.sa_flags = 0;
	sigaction(SIGINT, &act, &oact);

    //for (;;) {
        switch (argc) {
                case 1:     repl();                         break;
                case 2:     run_file(argv[1], NULL, NULL);  break;
                case 3:     compile_file(argv[1]);          break;
                default:    exit_message(ERROR_USAGE);      break;
        }
    sleep(10);

}

#endif // EXECUTABLE

