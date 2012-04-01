#ifndef SYS_H
#define SYS_H

#include "vm.h"

void print();
void save();
void load();
void rm();

struct string_func
{
    const char* name;
    bridge* func;
};

struct variable *func_map(struct Context *context);

struct variable *builtin_method(struct Context *context,
								struct variable *indexable,
                                const struct variable *index);

#endif // SYS_H