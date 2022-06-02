//! This is a basic implementation of a "tail call interpreter"
//!
//! The basic idea is described on this blog post:
//! https://blog.reverberate.org/2021/04/21/musttail-efficient-interpreters.html
//!
//! It is an effective substitute for computed goto.
//! Zig lacks computed goto (for now). See issue #8220 for (accepted) fix.
//!
//! As the blog post describes, this can actually generate not just equivalent code
//! as computed goto, but in many cases much better.
//!
//! This is due to the optimizer prefering small functions with no branches
//! over
//!
//! Regardless of the relative benefits of each approach,
//! zig supports forcing tail calls with @call() and .always_tail, but it
//! does not support computed goto.
//!
//! Unfortunately, right now (as of Jun 1st) I am having
//! an issue using .always_tail
//!
//! It triggers a compiler bug.
//! The Zig compiler outputs malformed LLVM IR.
//!
//! Here is a somewhat minimized version of my tail-call interpreter.
//!
//! It triggers the bug in the compiler.
//!
//! Switching from `.always_tail` to `.auto` avoids the bug,
//! but it would eventually blow the stack in a real interpreter.
//!
//! See `dispatch_direct` for the location of the `.always_tail` call 
const std = @import("std");
const assert = std.debug.assert;

const Opcode = enum(u8) {
    LOAD_IMM,
    POP,
    ADD,
    SUB,
    MUL,
    PRINT,
    RETURN,
};

const BytecodeInsn = packed struct {
    opcode: Opcode,
    oparg: u8 = 0,
};

const Value = union(enum) {
    integer: i32,
};

/// The context for an instruction.
pub const InsnCtx = struct {
    oparg: u8,
    ip: [*]const BytecodeInsn,
    stack_ptr: [*]Value,
    frame_ctx: *const CurrentFrameCtx,

    fn stack_size(self: *InsnCtx) usize {
        const byte_diff = @ptrToInt(self.stack_ptr) - @ptrToInt(self.frame_ctx.stack.ptr);
        return byte_diff / @sizeOf(Value);
    }

    fn push(self: *InsnCtx, val: Value) void {
        assert(self.stack_size() < self.frame_ctx.stack.len);
        self.stack_ptr[0] = val;
        self.stack_ptr += 1;
    }

    fn pop(self: *InsnCtx) Value {
        assert(self.stack_size() > 0);
        self.stack_ptr -= 1;
        return self.stack_ptr[0];
    }
};

/// Marker value
const InsnDone = struct {};

// We unpack the fields of `InsnCtx` so everything is passed in registers
const RawDispatchFn = fn (
    oparg: u8,
    ip: [*]const BytecodeInsn,
    stack_ptr: [*]Value,
    frame_ctx: *const CurrentFrameCtx,
) InsnDone;

/// Extra frame context
///
/// Pretend this structure has a lot of values
const CurrentFrameCtx = struct {
    name: []const u8,
    /// All posisble values on the stack
    stack: []Value,
    bytecode: []const BytecodeInsn,
    ip: u32,
};

inline fn dispatch_next(ctx: *InsnCtx) InsnDone {
    ctx.ip += 1;
    return dispatch_direct(ctx);
}

inline fn dispatch_direct(ctx: *InsnCtx) InsnDone {
    // decode oparg
    ctx.oparg = ctx.ip[0].oparg;
    const tgt: RawDispatchFn = DISPATCH_TABLE[@enumToInt(ctx.ip[0].opcode)];
    return @call(
        // This triggers a bug!
        .{ .modifier = .always_tail },
        tgt,
        .{ ctx.oparg, ctx.ip, ctx.stack_ptr, ctx.frame_ctx },
    );
}

/// Wrap a `fn(*InsnCtx) InsnDone` -> RawDispatchFn
///
/// This is needed to get the correct signature
/// (which is needed to pass things in registers)
fn wrap_eval_func(comptime tgt: fn (*InsnCtx) InsnDone) RawDispatchFn {
    const wrapper = struct {
        fn wrapped(
            oparg: u8,
            ip: [*]const BytecodeInsn,
            stack_ptr: [*]Value,
            frame_ctx: *const CurrentFrameCtx,
        ) InsnDone {
            var ctx = InsnCtx{
                .oparg = oparg,
                .ip = ip,
                .stack_ptr = stack_ptr,
                .frame_ctx = frame_ctx,
            };
            return @call(
                .{ .modifier = .always_inline },
                tgt,
                .{&ctx},
            );
        }
    };
    return wrapper.wrapped;
}

const OPCODE_IMPLS = std.enums.EnumFieldStruct(Opcode, fn (*InsnCtx) InsnDone, null){
    .LOAD_IMM = load_imm,
    .POP = pop,
    .ADD = arithop,
    .SUB = arithop,
    .MUL = arithop,
    .PRINT = print,
    .RETURN = @"return",
};
const DISPATCH_TABLE: [256]RawDispatchFn = buildTable: {
    var res: [256]RawDispatchFn = undefined;
    std.mem.set(RawDispatchFn, &res, wrap_eval_func(unimpl_opcode));
    inline for (std.enums.values(Opcode)) |opcode| {
        res[@enumToInt(opcode)] = wrap_eval_func(@field(OPCODE_IMPLS, @tagName(opcode)));
    }
    break :buildTable res;
};

fn load_imm(
    ctx: *InsnCtx,
) InsnDone {
    ctx.push(Value{ .integer = @bitCast(i8, ctx.oparg) });
    return dispatch_next(ctx);
}

fn pop(
    ctx: *InsnCtx,
) InsnDone {
    _ = ctx.pop();
    return dispatch_next(ctx);
}

/// One unified function for all arithmetic operations.
///
/// This is because I'm lazy ;)
fn arithop(
    ctx: *InsnCtx,
) InsnDone {
    const opcode = ctx.ip[0].opcode;
    const a = ctx.pop();
    const b = ctx.pop();
    const res: Value = switch (a) {
        .integer => |aval| switch (b) {
            .integer => |bval| handleInt: {
                const res = switch (opcode) {
                    .ADD => aval +% bval,
                    .SUB => aval -% bval,
                    .MUL => aval *% bval,
                    else => unreachable,
                };
                break :handleInt Value{ .integer = res };
            },
        },
    };
    ctx.push(res);
    return dispatch_next(ctx);
}

fn print(
    ctx: *InsnCtx,
) InsnDone {
    const a = ctx.pop();
    switch (a) {
        .integer => |val| {
            std.debug.print("{}\n", .{val});
        },
    }
    return dispatch_next(ctx);
}

fn @"return"(
    ctx: *InsnCtx,
) InsnDone {
    // done with retrned
    _ = ctx.pop();
    return InsnDone{};
}

fn unimpl_opcode(
    ctx: *InsnCtx,
) InsnDone {
    std.debug.panic("Unimplemented opcode: `{s}`", .{@tagName(ctx.ip[0].opcode)});
}

const SAMPLE_BYTECODE: []const BytecodeInsn = &[_]BytecodeInsn{
    .{ .opcode = .LOAD_IMM, .oparg = 2 },
    .{ .opcode = .LOAD_IMM, .oparg = 40 },
    .{ .opcode = .ADD },
    .{ .opcode = .PRINT },
    // load dummy value for return
    .{ .opcode = .LOAD_IMM, .oparg = 0 },
    .{ .opcode = .RETURN },
};

fn interpret(name: []const u8, bytecode: []const BytecodeInsn) void {
    var stack: [8]Value = undefined;
    var frame = CurrentFrameCtx{
        .stack = &stack,
        .bytecode = bytecode,
        .ip = 0, // start here
        .name = name,
    };
    var ctx = InsnCtx{
        .oparg = 0,
        .ip = bytecode.ptr,
        .stack_ptr = frame.stack.ptr,
        .frame_ctx = &frame,
    };
    // begin dispatch loop (starting at first insn)
    _ = dispatch_direct(&ctx);
}

pub fn main() !void {
    interpret("sample", SAMPLE_BYTECODE);
}
