// Type your code here, or load an example.
#include <stdint.h>
#include <stdio.h>
#include <assert.h>
#include <stdlib.h>
#include <stdbool.h>

#ifdef TRACE_ENABLED
#define TRACE(msg, ...) fprintf(stderr, "TRACE: " msg "\n", ##__VA_ARGS__)
#else
#define TRACE(msg, ...) do {} while(false)
#endif

enum opcode {
    OP_PUSH = 0,
    OP_PUSH_NEG = 1,
    OP_ADD = 2,
    OP_PRINT = 3,
    OP_POP = 4,
    OP_RETURN_VALUE = 5,
    // $EXPAND: extra_opcodes(start=6) 
};
#ifndef NUM_OPCODES
#define NUM_OPCODES 6
#endif

int interpret_traditional(const uint16_t *ip) {
    int entire_stack[16];
    int *stack = &entire_stack[0];
    int oparg, opcode;
    #define DISPATCH() do { \
            ip += 1; \
            DECODE(); \
            goto dispatchLoop; \
        } while(false)
    #define DECODE() do { \
            opcode = *ip & 0xFF; \
            oparg = (uint8_t) (*ip >> 8); \
        } while(false)
    DECODE(); // initial
    while (true) {
        dispatchLoop:
        switch (opcode) {
            case OP_PUSH:
                assert(oparg >= 0);
                TRACE("push: %d", oparg);
                *stack++ = oparg;
                DISPATCH();
            case OP_PUSH_NEG:
                assert(oparg >= 0);
                *stack++ = -oparg;
                DISPATCH();
            case OP_ADD: {
                int a = *--stack;
                int b = *--stack;
                TRACE("add: %d + %d", a, b);
                *stack++ = a + b;
                DISPATCH();
            }
            case OP_PRINT: {
                int val = *--stack;
                printf("%d\n", val);
                DISPATCH();
            }
            case OP_POP: {
                stack -= 1;
                DISPATCH();
            }
            case OP_RETURN_VALUE: {
                int val = *--stack;
                return val;
            }
            // $EXPAND: extra_evals(mode='case')
            default: {
                fprintf(stderr, "Illegal insn: %d", (*ip & 0xFF));
                abort();
            }
        }
    }
    #undef DISPATCH
    #undef DECODE
}


int interpret_nested_switch(const uint16_t *ip) {
    int entire_stack[16];
    int *stack = &entire_stack[0];
    int oparg;
    #define DISPATCH() do { \
            ip += 1; \
            DISPATCH_DIRECT(); \
        } while(false)
    #define DISPATCH_DIRECT() do { \
            int opcode = *ip & 0xFF; \
            oparg = (uint8_t) (*ip >> 8); \
            switch (opcode & 0xF) { \
                case OP_PUSH: goto push; \
                case OP_PUSH_NEG: goto push_neg; \
                case OP_ADD: goto add; \
                case OP_PRINT: goto print; \
                case OP_POP: goto pop; \
                case OP_RETURN_VALUE: goto return_value; \
                // $EXPAND: extra_nested_switch()
                default: goto illegal_insn; \
            } \
        } while(false)
    DISPATCH_DIRECT(); // begin dispatch loop
    while (true) {
        push:
            assert(oparg >= 0);
            TRACE("push: %d", oparg);
            *stack++ = oparg;
            DISPATCH();
        push_neg:
            assert(oparg >= 0);
            *stack++ = -oparg;
            DISPATCH();
        add: {
            int a = *--stack;
            int b = *--stack;
            TRACE("add: %d + %d", a, b);
            *stack++ = a + b;
            DISPATCH();
        }
        print: {
            int val = *--stack;
            printf("%d\n", val);
            DISPATCH();
        }
        pop: {
            stack -= 1;
            DISPATCH();
        }
        return_value: {
            int val = *--stack;
            return val;
        }
        illegal_insn: {
            fprintf(stderr, "Illegal insn: %d", (*ip & 0xFF));
            abort();
        }
        // $EXPAND: extra_evals(mode='goto')
    }
    #undef DISPATCH_DIRECT
    #undef DISPATCH
}

int interpret(const uint16_t *ip) {
    int entire_stack[16];
    int *stack = &entire_stack[0];
    int oparg;
    static void *table[NUM_OPCODES] = {
        &&push,
        &&push_neg,
        &&add,
        &&print,
        &&pop,
        &&return_value,
        // $EXPAND: extra_jump_table()
    };
    #define DISPATCH() do { \
            ip += 1; \
            DISPATCH_DIRECT(); \
        } while(false)
    #define DISPATCH_DIRECT() do { \
            int opcode = *ip & 0xFF; \
            oparg = (uint8_t) (*ip >> 8); \
            goto *table[opcode]; \
        } while(false)
    DISPATCH_DIRECT(); // begin dispatch loop
    while (true) {
        push:
            assert(oparg >= 0);
            TRACE("push: %d", oparg);
            *stack++ = oparg;
            DISPATCH();
        push_neg:
            assert(oparg >= 0);
            *stack++ = -oparg;
            DISPATCH();
        add: {
            int a = *--stack;
            int b = *--stack;
            TRACE("add: %d + %d", a, b);
            *stack++ = a + b;
            DISPATCH();
        }
        print: {
            int val = *--stack;
            printf("%d\n", val);
            DISPATCH();
        }
        pop: {
            stack -= 1;
            DISPATCH();
        }
        return_value: {
            int val = *--stack;
            return val;
        }
        illegal_insn: {
            fprintf(stderr, "Illegal insn: %d", (*ip & 0xFF));
            abort();
        }
        // $EXPAND: extra_evals(mode='goto')
    }
    #undef DISPATCH_DIRECT
    #undef DISPATCH
}

#define BC(op, oparg) (((uint16_t) op) | ((uint16_t) oparg) << 8)
const uint16_t SAMPLE_BYTECODE[6] = {
    BC(OP_PUSH, 2),
    BC(OP_PUSH, 40),
    BC(OP_ADD, 0),
    BC(OP_PRINT, 0),
    // load dummy value for return
    BC(OP_PUSH, 0),
    BC(OP_RETURN_VALUE, 0),
};

int main(int argc, char** argv) {
    interpret_traditional(&SAMPLE_BYTECODE[0]);
    interpret_nested_switch(&SAMPLE_BYTECODE[0]);
    interpret(&SAMPLE_BYTECODE[0]);

    return 0;
}
