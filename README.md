# zig-amx

Apple AMX (Apple Matrix Extensions) bindings for Zig.

> **Warning:** These instructions are undocumented and unsupported by Apple. They are available on Apple Silicon chips (M1/M2/M3/M4 and later). Use at your own risk.

*By [Jonathan Conway](https://dthink.ai) @ [Deep Thinking](https://dthink.ai)*

**Translations:** [中文](README.zh.md) | [日本語](README.ja.md)

---

## Overview

This library provides Zig bindings for Apple's AMX coprocessor, a matrix/vector accelerator tightly coupled with the CPU cores on Apple Silicon. It is based on the reverse-engineering work by [corsix/amx](https://github.com/corsix/amx).

## Requirements

- Zig 0.16.0+
- Apple Silicon Mac (M1/M2/M3/M4 or later)

## Installation

Add to your `build.zig.zon` dependencies (or clone into your project):

```zig
.{
    .name = .your_project,
    .version = "0.1.0",
    .dependencies = .{
        .amx = .{
            .path = "path/to/zig-amx",
        },
    },
}
```

Then in `build.zig`:

```zig
const amx_dep = b.dependency("amx", .{});
exe.root_module.addImport("amx", amx_dep.module("amx"));
```

## Usage

```zig
const amx = @import("amx");

// Enable AMX for the current thread.
const guard = amx.Guard.init();
defer guard.deinit();

// Load data into AMX registers.
var x_reg: amx.Reg = undefined;
// ... fill x_reg ...
amx.ldx(amx.Ldst.ldx(&x_reg, 0, .{}));

// Perform a fused multiply-add.
amx.fma64(amx.fmaOp(.{
    .x_offset = 0,
    .y_offset = 0,
    .z_row = 0,
}));

// Store results back.
var z_row: amx.Reg = undefined;
amx.stz(amx.Ldst.stz(&z_row, 0, false));
```

## Benchmark

A built-in benchmark compares AMX against a pure Zig software implementation:

```bash
zig build benchmark -Doptimize=ReleaseFast
```

Example output on Apple M5 Max:

```
Benchmarking AMX matrix f64 FMA (8x8)...
AMX: 71.9 GFLOPS
SW:  13.7 GFLOPS
Speedup: 5.3x
```

## API

### State Types

- `amx.Reg` — A 64-byte AMX register (union of `u8`/`u16`/`u32`/`u64`/`i8`/`i16`/`i32`/`i64`/`f16`/`f32`/`f64`/`vec`)
- `amx.State` — The complete 5 KiB AMX architectural state (`x[8]`, `y[8]`, `z[64]`)

### Control

- `amx.set()` / `amx.enable()` — Enable AMX
- `amx.clr()` / `amx.disable()` — Disable AMX
- `amx.Guard` — Scoped RAII guard (`init`/`deinit`)

### Instructions

All instructions are `pub inline fn` wrappers:

| Load/Store | Compute | Other |
|---|---|---|
| `ldx` | `fma64` | `set` |
| `ldy` | `fms64` | `clr` |
| `stx` | `fma32` | `extrx` |
| `sty` | `fms32` | `extry` |
| `ldz` | `fma16` | `vecint` |
| `stz` | `fms16` | `vecfp` |
| `ldzi` | `mac16` | `matint` |
| `stzi` | | `matfp` |
| | | `genlut` |

### Operand Builders

- `amx.Ldst.ldx(ptr, reg, flags)` — Build `ldx`/`ldy`/`stx`/`sty`/`ldz`/`stz`/`ldzi`/`stzi` operands
- `amx.fmaOp(flags)` — Build FMA/FMS operand from `amx.FmaFlags`
- `amx.mac16Op(flags)` — Build `mac16` operand from `amx.Mac16Flags`
- `amx.extrOp(flags)` — Build `extrx`/`extry` operand from `amx.ExtrFlags`

## Safety & Compatibility

- AMX instructions will raise an **illegal-instruction exception** if:
  - The current thread has not called `set()` first
  - The code runs on non-Apple Silicon hardware
  - The operating system has not enabled AMX for the process
- There is no runtime detection in this library; callers must ensure they are running on compatible hardware.

## Publishing

See [PUBLISHING.md](PUBLISHING.md) for how to release this package in the Zig ecosystem.

## License

MIT License — see [LICENSE](LICENSE).
