#ifndef VM_H
#define VM_H

#include <stdint.h>
#include <inttypes.h>
#include <pthread.h>
#include "struct.h"
#include "util.h"
#include "variable.h"

#define ERROR_NULL  "null pointer"
#define ERROR_INDEX "index out of bounds"

struct context_shared {
    struct array *all_variables;
    uint32_t tick;
    pthread_mutex_t gil;
    pthread_cond_t thread_cond;
    uint32_t num_threads;
    struct variable *callback;
};

struct context {
    struct variable *sys;
    struct variable* error;
    struct stack *program_stack;
    struct stack *operand_stack;
    struct byte_array *program;
    bool runtime;
    uint8_t indent;
#ifdef DEBUG
    char pcbuf[10000]; // todo: check boundary
#endif
    struct context_shared *singleton;
};

struct program_state {
    struct variable *args;
    struct map *named_variables;
    uint32_t pc;
};

enum Opcode {
    VM_NIL, // push nil
    VM_INT, // push an integer
    VM_ADD, // add two values
    VM_SET, // set a variable
    VM_VAR, // push a variable
    VM_FLT, // push a float
    VM_BUL, // push a boolean
    VM_STR, // push a string
    VM_FNC, // push a function
    VM_DST, // done with assignment
    VM_SRC, // push a set of values
    VM_LST, // push a list
    VM_KVP, // push a key-value-pair
    VM_GET, // get an item from a list or map
    VM_PUT, // put an item in a list or map
    VM_SUB, // subtract two values
    VM_MUL, // multiply two values
    VM_DIV, // divide two values
    VM_MOD, // modulo
    VM_BND, // bitwise and
    VM_BOR, // bitwise or
    VM_INV, // bitwise inverse
    VM_XOR, // xor
    VM_LSF, // left shift
    VM_RSF, // right shift
    VM_NEG, // arithmetic negate a value
    VM_NOT, // boolean negate a value
    VM_EQU, // compare
    VM_NEQ, // diff
    VM_GTN, // greater than
    VM_LTN, // less than
    VM_GRQ, // greater than or equal to
    VM_LEQ, // less than or equal to
    VM_AND, // logical and
    VM_ORR, // logical or
    VM_IFF, // if then
    VM_JMP, // jump the program counter
    VM_CAL, // call a function for result
    VM_MET, // call an object method
    VM_RET, // return from a function,
    VM_ITR, // iteration loop
    VM_COM, // comprehension
    VM_TRY, // try.catch
    VM_TRO, // throw
    VM_STX, // assignment in expression
    VM_PTX, // put in expression
};

#define ERROR_OPCODE "unknown opcode"

#ifdef DEBUG
void display_program(struct byte_array* program);
#endif

struct context *context_new(struct context *parent,
                            bool runtime,
                            bool sys_funcs);
void context_del();
void garbage_collect(struct context *context);
void vm_call(struct context *context, struct variable *func, struct variable *arg,...);
void *vm_exit_message(struct context *context, const char *format, ...);
void vm_null_check(struct context *context, const void* p);
void vm_assert(struct context *context, bool assertion, const char *format, ...);
struct variable *lookup(struct context *context, struct variable *indexable, struct variable *index);
void gil_lock(struct context *context, const char *who);
void gil_unlock(struct context *context, const char *who);

void execute(struct byte_array *program);
void execute_with(struct context *context,
                  struct byte_array *program);

#endif // VM_H
