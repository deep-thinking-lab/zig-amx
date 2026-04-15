//! Apple AMX (Apple Matrix Extensions) bindings for Zig.
//!
//! These instructions are undocumented and unsupported by Apple.
//! They are available on Apple Silicon chips (M1/M2/M3/M4 and later).
//!
//! AMX must be enabled with `set()` (or `amx.Guard.init()`) before use.
//! Executing AMX instructions without enabling them first will raise an
//! illegal-instruction exception.
//!
//! Use at your own risk.
//!
//! Reference: https://github.com/corsix/amx

const std = @import("std");

comptime {
    const min_zig = std.SemanticVersion.parse("0.16.0") catch unreachable;
    if (@import("builtin").zig_version.order(min_zig) == .lt) {
        @compileError("zig-amx requires Zig 0.16.0 or later");
    }
}

/// A 64-byte AMX register, viewable in multiple data types.
pub const Reg = extern union {
    u8: [64]u8,
    u16: [32]u16,
    u32: [16]u32,
    u64: [8]u64,
    i8: [64]i8,
    i16: [32]i16,
    i32: [16]i32,
    i64: [8]i64,
    f16: [32]f16,
    f32: [16]f32,
    f64: [8]f64,
    vec: @Vector(64, u8),

    comptime {
        std.debug.assert(@sizeOf(Reg) == 64);
    }
};

/// The complete AMX architectural state.
/// Total size: 5 KiB (8 X regs + 8 Y regs + 64 Z regs).
pub const State = extern struct {
    x: [8]Reg,
    y: [8]Reg,
    z: [64]Reg,

    comptime {
        std.debug.assert(@sizeOf(State) == 512 + 512 + 4096);
    }
};

// ============================================================================
// Low-level instruction wrappers
// ============================================================================

/// All GPR-based AMX instructions use x16 as the operand register.
/// This avoids the need for the `0%%1` assembler trick used in C.
inline fn amx_op_gpr(op: u5, gpr: u64) void {
    comptime {
        if (!std.Target.Cpu.Arch.isAARCH64(@import("builtin").target.cpu.arch)) {
            @compileError("AMX instructions are only available on AArch64");
        }
    }
    const insn: u32 = 0x00201000 | (@as(u32, op) << 5) | 16;
    asm volatile (".word %[insn]"
        :
        : [insn] "i" (insn),
          [gpr] "{x16}" (gpr),
        : .{ .memory = true, .x16 = true }
    );
}

inline fn amx_nop_op_imm5(op: u5, imm5: u5) void {
    comptime {
        if (!std.Target.Cpu.Arch.isAARCH64(@import("builtin").target.cpu.arch)) {
            @compileError("AMX instructions are only available on AArch64");
        }
    }
    const insn: u32 = 0x00201000 | (@as(u32, op) << 5) | @as(u32, imm5);
    asm volatile ("nop\nnop\nnop\n.word %[insn]"
        :
        : [insn] "i" (insn),
        : .{ .memory = true }
    );
}

/// Load 64 bytes from memory into an X register.
pub inline fn ldx(gpr: u64) void {
    amx_op_gpr(0, gpr);
}

/// Load 64 bytes from memory into a Y register.
pub inline fn ldy(gpr: u64) void {
    amx_op_gpr(1, gpr);
}

/// Store 64 bytes from an X register to memory.
pub inline fn stx(gpr: u64) void {
    amx_op_gpr(2, gpr);
}

/// Store 64 bytes from a Y register to memory.
pub inline fn sty(gpr: u64) void {
    amx_op_gpr(3, gpr);
}

/// Load 64 bytes from memory into a Z register row.
pub inline fn ldz(gpr: u64) void {
    amx_op_gpr(4, gpr);
}

/// Store 64 bytes from a Z register row to memory.
pub inline fn stz(gpr: u64) void {
    amx_op_gpr(5, gpr);
}

/// Load interleaved into a Z register pair.
pub inline fn ldzi(gpr: u64) void {
    amx_op_gpr(6, gpr);
}

/// Store interleaved from a Z register pair.
pub inline fn stzi(gpr: u64) void {
    amx_op_gpr(7, gpr);
}

/// Extract / move data into X registers.
pub inline fn extrx(gpr: u64) void {
    amx_op_gpr(8, gpr);
}

/// Extract / move data into Y registers.
pub inline fn extry(gpr: u64) void {
    amx_op_gpr(9, gpr);
}

/// Fused multiply-add on f64 values.
pub inline fn fma64(gpr: u64) void {
    amx_op_gpr(10, gpr);
}

/// Fused multiply-subtract on f64 values.
pub inline fn fms64(gpr: u64) void {
    amx_op_gpr(11, gpr);
}

/// Fused multiply-add on f32 values.
pub inline fn fma32(gpr: u64) void {
    amx_op_gpr(12, gpr);
}

/// Fused multiply-subtract on f32 values.
pub inline fn fms32(gpr: u64) void {
    amx_op_gpr(13, gpr);
}

/// Integer multiply-accumulate on 16-bit values.
pub inline fn mac16(gpr: u64) void {
    amx_op_gpr(14, gpr);
}

/// Fused multiply-add on f16 values.
pub inline fn fma16(gpr: u64) void {
    amx_op_gpr(15, gpr);
}

/// Fused multiply-subtract on f16 values.
pub inline fn fms16(gpr: u64) void {
    amx_op_gpr(16, gpr);
}

/// Enable AMX for the current thread.
/// Raises an illegal-instruction exception if already enabled.
pub inline fn set() void {
    amx_nop_op_imm5(17, 0);
}

/// Disable AMX for the current thread.
pub inline fn clr() void {
    amx_nop_op_imm5(17, 1);
}

/// Integer vector operations.
pub inline fn vecint(gpr: u64) void {
    amx_op_gpr(18, gpr);
}

/// Floating-point vector operations.
pub inline fn vecfp(gpr: u64) void {
    amx_op_gpr(19, gpr);
}

/// Integer matrix operations.
pub inline fn matint(gpr: u64) void {
    amx_op_gpr(20, gpr);
}

/// Floating-point matrix operations.
pub inline fn matfp(gpr: u64) void {
    amx_op_gpr(21, gpr);
}

/// Generate lookup table / perform indexed load.
pub inline fn genlut(gpr: u64) void {
    amx_op_gpr(22, gpr);
}

// ============================================================================
// Convenience aliases
// ============================================================================

/// Alias for `set()`.
pub inline fn enable() void {
    set();
}

/// Alias for `clr()`.
pub inline fn disable() void {
    clr();
}

/// A scoped guard that enables AMX on initialization and disables it on deinit.
pub const Guard = struct {
    pub fn init() Guard {
        set();
        return .{};
    }
    pub fn deinit(_: Guard) void {
        clr();
    }
};

// ============================================================================
// Operand builders
// ============================================================================

/// Flags for `ldx` and `ldy` operands.
pub const LdFlags = packed struct(u64) {
    /// Load multiple registers.
    multiple: bool = false,
    /// On M2/M3: `multiple` means four registers instead of two.
    multiple_mean_four: bool = false,
    /// On M3: load to non-consecutive registers.
    non_consecutive: bool = false,
    _pad: u61 = 0,
};

/// Construct operands for load/store instructions.
pub const Ldst = struct {
    /// Build an operand for `ldx`.
    pub fn ldx(ptr: *const anyopaque, reg: u3, flags: LdFlags) u64 {
        var op: u64 = @intFromPtr(ptr) & 0x00FFFFFFFFFFFFFF;
        op |= @as(u64, reg) << 56;
        if (flags.multiple) op |= @as(u64, 1) << 62;
        if (flags.multiple_mean_four) op |= @as(u64, 1) << 60;
        if (flags.non_consecutive) op |= @as(u64, 1) << 61;
        return op;
    }

    /// Build an operand for `ldy`.
    pub fn ldy(ptr: *const anyopaque, reg: u3, flags: LdFlags) u64 {
        return Ldst.ldx(ptr, reg, flags);
    }

    /// Build an operand for `stx`.
    pub fn stx(ptr: *anyopaque, reg: u3, pair: bool) u64 {
        var op: u64 = @intFromPtr(ptr) & 0x00FFFFFFFFFFFFFF;
        op |= @as(u64, reg) << 56;
        if (pair) op |= @as(u64, 1) << 62;
        return op;
    }

    /// Build an operand for `sty`.
    pub fn sty(ptr: *anyopaque, reg: u3, pair: bool) u64 {
        return Ldst.stx(ptr, reg, pair);
    }

    /// Build an operand for `ldz`.
    pub fn ldz(ptr: *const anyopaque, row: u6, pair: bool) u64 {
        var op: u64 = @intFromPtr(ptr) & 0x00FFFFFFFFFFFFFF;
        op |= @as(u64, row) << 56;
        if (pair) op |= @as(u64, 1) << 62;
        return op;
    }

    /// Build an operand for `stz`.
    pub fn stz(ptr: *anyopaque, row: u6, pair: bool) u64 {
        return Ldst.ldz(ptr, row, pair);
    }

    /// Build an operand for `ldzi`.
    pub fn ldzi(ptr: *const anyopaque, row: u5, right_half: bool) u64 {
        var op: u64 = @intFromPtr(ptr) & 0x00FFFFFFFFFFFFFF;
        op |= @as(u64, row) << 57;
        if (right_half) op |= @as(u64, 1) << 56;
        return op;
    }

    /// Build an operand for `stzi`.
    pub fn stzi(ptr: *anyopaque, row: u5, right_half: bool) u64 {
        return Ldst.ldzi(ptr, row, right_half);
    }
};

/// Flags for FMA/FMS operations.
pub const FmaFlags = packed struct(u64) {
    /// Y offset in bytes (bits 0-8).
    y_offset: u9 = 0,
    /// Ignored (bit 9).
    _pad0: u1 = 0,
    /// X offset in bytes (bits 10-18).
    x_offset: u9 = 0,
    /// Ignored (bit 19).
    _pad1: u1 = 0,
    /// Z row (bits 20-25).
    z_row: u6 = 0,
    /// Ignored (bit 26).
    _pad2: u1 = 0,
    /// Skip Z input (bit 27).
    skip_z: bool = false,
    /// Skip Y input (bit 28).
    skip_y: bool = false,
    /// Skip X input (bit 29).
    skip_x: bool = false,
    /// Ignored (bits 30-31).
    _pad3: u2 = 0,
    /// Y enable value (bits 32-36).
    y_enable_value: u5 = 0,
    /// Y enable mode (bits 37-38). Ignored in vector mode.
    y_enable_mode: u2 = 0,
    /// Ignored (bits 39-40).
    _pad4: u2 = 0,
    /// X enable value (bits 41-45).
    x_enable_value: u5 = 0,
    /// X enable mode (bits 46-47).
    x_enable_mode: u2 = 0,
    /// Ignored (bits 48-59).
    _pad5: u12 = 0,
    /// Y is f16 (bit 60). Only used by `fma32`.
    y_f16: bool = false,
    /// X is f16 (bit 61). Only used by `fma32`.
    x_f16: bool = false,
    /// Z is f32 (bit 62). Only used by `fma16` in matrix mode.
    z_f32: bool = false,
    /// Vector mode (bit 63).
    vector: bool = false,
};

/// Build a 64-bit operand for FMA/FMS instructions from flags.
pub inline fn fmaOp(flags: FmaFlags) u64 {
    return @bitCast(flags);
}

/// Flags for MAC16 operations.
pub const Mac16Flags = packed struct(u64) {
    /// Y offset in bytes (bits 0-8).
    y_offset: u9 = 0,
    /// Ignored (bit 9).
    _pad0: u1 = 0,
    /// X offset in bytes (bits 10-18).
    x_offset: u9 = 0,
    /// Ignored (bit 19).
    _pad1: u1 = 0,
    /// Z row (bits 20-25).
    z_row: u6 = 0,
    /// Ignored (bit 26).
    _pad2: u1 = 0,
    /// Skip Z input (bit 27).
    skip_z: bool = false,
    /// Skip Y input (bit 28).
    skip_y: bool = false,
    /// Skip X input (bit 29).
    skip_x: bool = false,
    /// Ignored (bits 30-31).
    _pad3: u2 = 0,
    /// Y enable value (bits 32-36).
    y_enable_value: u5 = 0,
    /// Y enable mode (bits 37-38). Ignored in vector mode.
    y_enable_mode: u2 = 0,
    /// Ignored (bits 39-40).
    _pad4: u2 = 0,
    /// X enable value (bits 41-45).
    x_enable_value: u5 = 0,
    /// X enable mode (bits 46-47).
    x_enable_mode: u2 = 0,
    /// Ignored (bits 48-54).
    _pad5: u7 = 0,
    /// Right shift amount (bits 55-59).
    right_shift: u5 = 0,
    /// Y is i8 (bit 60).
    y_i8: bool = false,
    /// X is i8 (bit 61).
    x_i8: bool = false,
    /// Z is i32 (bit 62). Ignored in vector mode.
    z_i32: bool = false,
    /// Vector mode (bit 63).
    vector: bool = false,
};

/// Build a 64-bit operand for `mac16` from flags.
pub inline fn mac16Op(flags: Mac16Flags) u64 {
    return @bitCast(flags);
}

/// Flags for `extrx` / `extry` operations.
pub const ExtrFlags = packed struct(u64) {
    /// Ignored (bits 0-15).
    _pad0: u16 = 0,
    /// X register index (bits 16-18).
    x_reg: u3 = 0,
    /// Ignored (bit 19).
    _pad1: u1 = 0,
    /// Y register index (bits 20-22).
    y_reg: u3 = 0,
    /// Ignored (bits 23-25).
    _pad2: u3 = 0,
    /// Must be 0 for `extrx`/`extry` (bits 26-27).
    _pad3: u2 = 0,
    /// Ignored (bits 28-63).
    _pad4: u36 = 0,
};

/// Build a 64-bit operand for `extrx` / `extry` from flags.
pub inline fn extrOp(flags: ExtrFlags) u64 {
    return @bitCast(flags);
}

// ============================================================================
// Tests
// ============================================================================

test "sizes" {
    try std.testing.expectEqual(64, @sizeOf(Reg));
    try std.testing.expectEqual(5120, @sizeOf(State));
}

test "ldst operand builders" {
    const ptr: *const u8 = @ptrFromInt(0x1234_5678_9ABC_DEF0);
    const op = Ldst.ldx(ptr, 3, .{ .multiple = true });
    const expected = (@intFromPtr(ptr) & 0x00FFFFFFFFFFFFFF) |
        (@as(u64, 3) << 56) |
        (@as(u64, 1) << 62);
    try std.testing.expectEqual(expected, op);
}

test "fma flags bitcast" {
    const flags = FmaFlags{
        .x_offset = 64,
        .y_offset = 128,
        .z_row = 7,
        .vector = true,
    };
    const op = fmaOp(flags);
    try std.testing.expectEqual(@as(u64, 64) << 10 | @as(u64, 128) | @as(u64, 7) << 20 | (@as(u64, 1) << 63), op);
}

test "mac16 flags bitcast" {
    const flags = Mac16Flags{
        .x_offset = 64,
        .y_offset = 128,
        .z_row = 7,
        .right_shift = 5,
        .vector = true,
    };
    const op = mac16Op(flags);
    try std.testing.expectEqual(@as(u64, 64) << 10 | @as(u64, 128) | @as(u64, 7) << 20 | (@as(u64, 5) << 55) | (@as(u64, 1) << 63), op);
}

test "extr flags bitcast" {
    const flags = ExtrFlags{
        .x_reg = 2,
        .y_reg = 5,
    };
    const op = extrOp(flags);
    try std.testing.expectEqual(@as(u64, 2) << 16 | (@as(u64, 5) << 20), op);
}
