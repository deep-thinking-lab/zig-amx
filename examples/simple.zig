/// A minimal AMX example: load X and Y, perform fma32, store Z.
///
/// Build with:
///   zig build example -Dtarget=aarch64-macos
const std = @import("std");
const amx = @import("amx");

pub fn main() !void {
    // Enable AMX for this thread.
    const guard = amx.Guard.init();
    defer guard.deinit();

    // Allocate aligned buffers for X, Y, and Z rows.
    var x_buf: [16]f32 align(64) = undefined;
    var y_buf: [16]f32 align(64) = undefined;
    var z_buf: [16]f32 align(64) = undefined;

    // Fill with some data.
    @memset(&x_buf, 1.0);
    @memset(&y_buf, 2.0);
    @memset(&z_buf, 0.0);

    // Load X and Y into AMX registers 0.
    amx.ldx(amx.Ldst.ldx(&x_buf, 0, .{}));
    amx.ldy(amx.Ldst.ldy(&y_buf, 0, .{}));

    // Load initial Z row 0.
    amx.ldz(amx.Ldst.ldz(&z_buf, 0, false));

    // Perform a vector-mode f32 fused multiply-add:
    // z[0][i] += x[i] * y[i]
    amx.fma32(amx.fmaOp(.{
        .x_offset = 0,
        .y_offset = 0,
        .z_row = 0,
        .vector = true,
    }));

    // Store result back.
    amx.stz(amx.Ldst.stz(&z_buf, 0, false));

    // Verify the result (as f32, each lane should be 2.0).
    std.debug.print("z[0] = {d}\n", .{z_buf[0]});
}
