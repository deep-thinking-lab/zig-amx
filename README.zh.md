# zig-amx

适用于 Zig 的 Apple AMX（Apple Matrix Extensions）绑定库。

> **警告：** 这些指令未经 Apple 官方文档记录和支持。它们仅在 Apple 芯片（M1/M2/M3/M4 及更新机型）上可用。请自行承担使用风险。

*作者：[Jonathan Conway](https://dthink.ai) @ [Deep Thinking](https://dthink.ai)*

**其他语言：** [English](README.md) | [日本語](README.ja.md)

---

## 简介

本库为 Apple 的 AMX 协处理器提供 Zig 绑定。AMX 是一款与 Apple Silicon CPU 核心紧密集成的矩阵/向量加速器。本库基于 [corsix/amx](https://github.com/corsix/amx) 的逆向工程成果。

## 环境要求

- Zig 0.16.0+
- Apple Silicon Mac（M1/M2/M3/M4 或更新机型）

## 安装

在 `build.zig.zon` 中添加依赖（或克隆到项目中）：

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

然后在 `build.zig` 中：

```zig
const amx_dep = b.dependency("amx", .{});
exe.root_module.addImport("amx", amx_dep.module("amx"));
```

## 用法

```zig
const amx = @import("amx");

// 为当前线程启用 AMX
const guard = amx.Guard.init();
defer guard.deinit();

// 将数据加载到 AMX 寄存器
var x_reg: amx.Reg = undefined;
// ... 填充 x_reg ...
amx.ldx(amx.Ldst.ldx(&x_reg, 0, .{}));

// 执行 fused multiply-add
amx.fma64(amx.fmaOp(.{
    .x_offset = 0,
    .y_offset = 0,
    .z_row = 0,
}));

// 将结果存回内存
var z_row: amx.Reg = undefined;
amx.stz(amx.Ldst.stz(&z_row, 0, false));
```

## 基准测试

内置基准测试可将 AMX 与纯 Zig 软件实现进行对比：

```bash
zig build benchmark -Doptimize=ReleaseFast
```

在 Apple M5 Max 上的示例输出：

```
Benchmarking AMX matrix f64 FMA (8x8)...
AMX: 71.9 GFLOPS
SW:  13.7 GFLOPS
Speedup: 5.3x
```

## API

### 状态类型

- `amx.Reg` — 64 字节 AMX 寄存器（联合体：`u8`/`u16`/`u32`/`u64`/`i8`/`i16`/`i32`/`i64`/`f16`/`f32`/`f64`/`vec`）
- `amx.State` — 完整的 5 KiB AMX 架构状态（`x[8]`、`y[8]`、`z[64]`）

### 控制

- `amx.set()` / `amx.enable()` — 启用 AMX
- `amx.clr()` / `amx.disable()` — 禁用 AMX
- `amx.Guard` — 作用域 RAII 守卫（`init`/`deinit`）

### 指令

所有指令均为 `pub inline fn` 包装器：

| 加载/存储 | 计算 | 其他 |
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

### 操作数构造器

- `amx.Ldst.ldx(ptr, reg, flags)` — 构造 `ldx`/`ldy`/`stx`/`sty`/`ldz`/`stz`/`ldzi`/`stzi` 操作数
- `amx.fmaOp(flags)` — 从 `amx.FmaFlags` 构造 FMA/FMS 操作数
- `amx.mac16Op(flags)` — 从 `amx.Mac16Flags` 构造 `mac16` 操作数
- `amx.extrOp(flags)` — 从 `amx.ExtrFlags` 构造 `extrx`/`extry` 操作数

## 安全与兼容性

- 在以下情况下，AMX 指令会触发 **illegal-instruction 异常**：
  - 当前线程未先调用 `set()`
  - 代码运行在非 Apple Silicon 硬件上
  - 操作系统未为当前进程启用 AMX
- 本库不包含运行时检测；调用方必须确保在兼容硬件上运行。

## 发布

请参阅 [PUBLISHING.md](PUBLISHING.md) 了解如何在 Zig 生态系统中发布本包。

## 许可证

MIT 许可证 — 详见 [LICENSE](LICENSE)。
