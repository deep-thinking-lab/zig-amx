const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const amx_mod = b.addModule("amx", .{
        .root_source_file = b.path("src/amx.zig"),
    });

    // Tests
    const test_step = b.step("test", "Run unit tests");
    const test_mod = b.createModule(.{
        .root_source_file = b.path("src/amx.zig"),
        .target = target,
        .optimize = optimize,
    });
    const tests = b.addTest(.{
        .root_module = test_mod,
    });
    const run_tests = b.addRunArtifact(tests);
    test_step.dependOn(&run_tests.step);

    // Example
    const example_step = b.step("example", "Build the simple example");
    const example_mod = b.createModule(.{
        .root_source_file = b.path("examples/simple.zig"),
        .target = target,
        .optimize = optimize,
    });
    example_mod.addImport("amx", amx_mod);
    const example = b.addExecutable(.{
        .name = "simple",
        .root_module = example_mod,
    });
    const run_example = b.addRunArtifact(example);
    example_step.dependOn(&run_example.step);

    // Benchmark
    const benchmark_step = b.step("benchmark", "Run AMX vs software benchmark");
    const benchmark_mod = b.createModule(.{
        .root_source_file = b.path("benchmarks/matmul.zig"),
        .target = target,
        .optimize = optimize,
    });
    benchmark_mod.addImport("amx", amx_mod);
    const benchmark = b.addExecutable(.{
        .name = "matmul",
        .root_module = benchmark_mod,
    });
    const run_benchmark = b.addRunArtifact(benchmark);
    benchmark_step.dependOn(&run_benchmark.step);
}
