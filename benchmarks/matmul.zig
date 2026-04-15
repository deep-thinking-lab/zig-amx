/// Benchmark: matrix-mode f64 microkernel (8×8 outer product).
///
/// Compares AMX throughput against a pure Zig software implementation.
/// Build with:
///   zig build benchmark -Doptimize=ReleaseFast
const std = @import("std");
const amx = @import("amx");

const benchmark_duration_ns = 500_000_000; // 500 ms

const Timer = struct {
    start: u64,
    numer: u64,
    denom: u64,

    fn init() Timer {
        var info: std.c.mach_timebase_info_data = undefined;
        _ = std.c.mach_timebase_info(&info);
        return .{
            .start = std.c.mach_absolute_time(),
            .numer = info.numer,
            .denom = info.denom,
        };
    }

    fn read(self: Timer) u64 {
        const now = std.c.mach_absolute_time();
        return (now - self.start) * self.numer / self.denom;
    }
};

// For f64 matrix mode, Z rows are spaced by 8: base + 0, 8, 16, 24, 32, 40, 48, 56
const z_rows = [_]u6{ 0, 8, 16, 24, 32, 40, 48, 56 };

fn bench_amx() !f64 {
    const guard = amx.Guard.init();
    defer guard.deinit();

    var x: [8]f64 align(64) = undefined;
    var y: [8]f64 align(64) = undefined;
    var z: [8][8]f64 align(64) = undefined;
    @memset(&x, @as(f64, 1.0));
    @memset(&y, @as(f64, 2.0));

    amx.ldx(amx.Ldst.ldx(&x, 0, .{}));
    amx.ldy(amx.Ldst.ldy(&y, 0, .{}));

    const op = amx.fmaOp(.{
        .x_offset = 0,
        .y_offset = 0,
        .z_row = 0,
        .vector = false,
    });

    for (&z) |*row| @memset(row, @as(f64, 0.0));
    for (z_rows) |row| {
        amx.ldz(amx.Ldst.ldz(&z[row / 8], row, false));
    }

    const timer = Timer.init();
    var iters: usize = 0;
    while (timer.read() < benchmark_duration_ns) {
        // Unroll 4x to amortize loop overhead
        amx.fma64(op);
        amx.fma64(op);
        amx.fma64(op);
        amx.fma64(op);
        iters += 4;
    }
    const elapsed_ns = timer.read();

    for (z_rows) |row| {
        amx.stz(amx.Ldst.stz(&z[row / 8], row, false));
    }

    // Verify correctness
    const expected = @as(f64, @floatFromInt(iters)) * 2.0;
    for (z) |row| {
        for (row, 0..) |val, i| {
            if (@abs(val - expected) > @abs(expected) * 0.01) {
                std.debug.print("AMX mismatch at [{d}]: got {d}, expected {d}\n", .{ i, val, expected });
                return error.AmxResultMismatch;
            }
        }
    }

    // 8×8 = 64 FMAs per iteration = 128 FLOPs
    const flops: f64 = @as(f64, @floatFromInt(iters)) * 64.0 * 2.0;
    return flops / 1e9 / (@as(f64, @floatFromInt(elapsed_ns)) / 1e9);
}

fn bench_sw() !f64 {
    var x: [8]f64 align(64) = undefined;
    var y: [8]f64 align(64) = undefined;
    var z: [8][8]f64 align(64) = undefined;
    @memset(&x, @as(f64, 1.0));
    @memset(&y, @as(f64, 2.0));

    for (&z) |*row| @memset(row, @as(f64, 0.0));

    const timer = Timer.init();
    var iters: usize = 0;
    while (timer.read() < benchmark_duration_ns) {
        for (0..8) |j| {
            for (0..8) |i| {
                z[j][i] = z[j][i] + x[i] * y[j];
            }
        }
        iters += 1;
    }
    const elapsed_ns = timer.read();

    // Verify correctness
    const expected = @as(f64, @floatFromInt(iters)) * 2.0;
    for (z) |row| {
        for (row, 0..) |val, i| {
            if (@abs(val - expected) > @abs(expected) * 0.01) {
                std.debug.print("SW mismatch at [{d}]: got {d}, expected {d}\n", .{ i, val, expected });
                return error.SwResultMismatch;
            }
        }
    }

    const flops: f64 = @as(f64, @floatFromInt(iters)) * 64.0 * 2.0;
    return flops / 1e9 / (@as(f64, @floatFromInt(elapsed_ns)) / 1e9);
}

pub fn main() void {
    std.debug.print("Benchmarking AMX matrix f64 FMA (8x8)...\n", .{});

    const amx_gflops = bench_amx() catch |e| {
        std.debug.panic("AMX benchmark failed: {}\n", .{e});
    };
    const sw_gflops = bench_sw() catch |e| {
        std.debug.panic("SW benchmark failed: {}\n", .{e});
    };

    std.debug.print("AMX: {d:.1} GFLOPS\n", .{amx_gflops});
    std.debug.print("SW:  {d:.1} GFLOPS\n", .{sw_gflops});
    std.debug.print("Speedup: {d:.1}x\n", .{amx_gflops / sw_gflops});
}
