//! This is a simple example implementation of an interpreter
//!
//! Originally it used a series of tail calls as a substitue for computed goto.
//! See here: https://blog.reverberate.org/2021/04/21/musttail-efficient-interpreters.html
//!
//! It has since been rewritten to use a simple switch statement
const std = @import("std");
const assert = std.debug.assert;

const Opcode = enum(u8) {
    PUSH = 0,
    PUSH_NEG = 1,
    ADD = 2,
    PRINT = 3,
    POP = 4,
    RETURN_VALUE = 5,
};

const BytecodeInsn = packed struct {
    opcode: Opcode,
    oparg: u8 = 0,
};
comptime {
    assert(@sizeOf(BytecodeInsn) == 2);
}

fn interpret_traditional(code: []const BytecodeInsn) i32 {
    var ip = code.ptr;
    var entire_stack: [16]i32 = undefined;
    var stack: [*]i32 = &entire_stack;
    dispatchLoop: while (true) {
        switch (ip[0].opcode) {
            .PUSH => {
                stack[0] = ip[0].oparg;
                stack += 1;
                ip += 1;
                continue :dispatchLoop;
            },
            .PUSH_NEG => {
                stack[0] = -@as(i32, ip[0].oparg);
                stack += 1;
                ip += 1;
                continue :dispatchLoop;
            },
            .ADD => {
                stack -= 1;
                const a = stack[0];
                stack -= 1;
                const b = stack[0];
                stack[0] = a +% b;
                stack += 1;
                ip += 1;
                continue :dispatchLoop;
            },
            .PRINT => {
                stack -= 1;
                const val = stack[0];
                std.debug.print("{}\n", .{val});
                ip += 1;
                continue :dispatchLoop;
            },
            .POP => {
                stack -= 1;
                ip += 1;
                continue :dispatchLoop;
            },
            .RETURN_VALUE => {
                stack -= 1;
                const val = stack[0];
                ip += 1;
                return val;
            },
        }
        @panic("Should handle every instruction");
    }
}

const SAMPLE_BYTECODE: []const BytecodeInsn = &[_]BytecodeInsn{
    .{ .opcode = .PUSH, .oparg = 2 },
    .{ .opcode = .PUSH, .oparg = 40 },
    .{ .opcode = .ADD },
    .{ .opcode = .PRINT },
    // load dummy value for return
    .{ .opcode = .PUSH, .oparg = 0 },
    .{ .opcode = .RETURN_VALUE },
};

fn interpret(code: []const BytecodeInsn) i32 {
    var ip = code.ptr;
    var entire_stack: [16]i32 = undefined;
    var stack: [*]i32 = &entire_stack;
    while (true) {
        dispatchLoop: switch (ip[0].opcode) {
            .PUSH => {
                stack[0] = ip[0].oparg;
                stack += 1;
                ip += 1;
                continue :dispatchLoop ip[0].opcode;
            },
            .PUSH_NEG => {
                stack[0] = -@as(i32, ip[0].oparg);
                stack += 1;
                ip += 1;
                continue :dispatchLoop ip[0].opcode;
            },
            .ADD => {
                stack -= 1;
                const a = stack[0];
                stack -= 1;
                const b = stack[0];
                stack[0] = a +% b;
                stack += 1;
                ip += 1;
                continue :dispatchLoop ip[0].opcode;
            },
            .PRINT => {
                stack -= 1;
                const val = stack[0];
                std.debug.print("{}\n", .{val});
                ip += 1;
                continue :dispatchLoop ip[0].opcode;
            },
            .POP => {
                stack -= 1;
                ip += 1;
                continue :dispatchLoop ip[0].opcode;
            },
            .RETURN_VALUE => {
                stack -= 1;
                const val = stack[0];
                ip += 1;
                return val;
            },
        }
        @panic("should handle every instruction");
    }
}

pub fn main() !void {
    _ = interpret_traditional(SAMPLE_BYTECODE);
    _ = interpret(SAMPLE_BYTECODE);
}
