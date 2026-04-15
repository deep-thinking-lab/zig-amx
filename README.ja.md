# zig-amx

Zig 向け Apple AMX（Apple Matrix Extensions）バインディング。

> **警告：** これらの命令は Apple によって文書化・サポートされていません。Apple Silicon チップ（M1/M2/M3/M4 以降）でのみ利用可能です。自己責任でご利用ください。

*作者：[Jonathan Conway](https://dthink.ai) @ [Deep Thinking](https://dthink.ai)*

**他の言語：** [English](README.md) | [中文](README.zh.md)

---

## 概要

本ライブラリは、Apple Silicon の CPU コアと密接に結合された行列・ベクトル加速器である Apple AMX コプロセッサの Zig バインディングを提供します。[corsix/amx](https://github.com/corsix/amx) のリバースエンジニアリング成果を基に作成されています。

## 動作環境

- Zig 0.16.0+
- Apple Silicon Mac（M1/M2/M3/M4 以降）

## インストール

`build.zig.zon` の依存関係に追加するか、プロジェクトにクローンしてください：

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

その後、`build.zig` で以下のようにインポートします：

```zig
const amx_dep = b.dependency("amx", .{});
exe.root_module.addImport("amx", amx_dep.module("amx"));
```

## 使い方

```zig
const amx = @import("amx");

// 現在のスレッドで AMX を有効化
const guard = amx.Guard.init();
defer guard.deinit();

// データを AMX レジスタにロード
var x_reg: amx.Reg = undefined;
// ... x_reg を埋める ...
amx.ldx(amx.Ldst.ldx(&x_reg, 0, .{}));

// 積和演算（FMA）を実行
amx.fma64(amx.fmaOp(.{
    .x_offset = 0,
    .y_offset = 0,
    .z_row = 0,
}));

// 結果をメモリにストア
var z_row: amx.Reg = undefined;
amx.stz(amx.Ldst.stz(&z_row, 0, false));
```

## ベンチマーク

内蔵のベンチマークにより、AMX と純粋な Zig のソフトウェア実装を比較できます：

```bash
zig build benchmark -Doptimize=ReleaseFast
```

Apple M5 Max での実行例：

```
Benchmarking AMX matrix f64 FMA (8x8)...
AMX: 71.9 GFLOPS
SW:  13.7 GFLOPS
Speedup: 5.3x
```

## API

### 状態型

- `amx.Reg` — 64 バイトの AMX レジスタ（共用体：`u8`/`u16`/`u32`/`u64`/`i8`/`i16`/`i32`/`i64`/`f16`/`f32`/`f64`/`vec`）
- `amx.State` — 完全な 5 KiB の AMX アーキテクチャ状態（`x[8]`、`y[8]`、`z[64]`）

### 制御

- `amx.set()` / `amx.enable()` — AMX を有効化
- `amx.clr()` / `amx.disable()` — AMX を無効化
- `amx.Guard` — スコープ RAII ガード（`init`/`deinit`）

### 命令

すべての命令は `pub inline fn` ラッパーとして提供されます：

| ロード/ストア | 演算 | その他 |
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

### オペランドビルダー

- `amx.Ldst.ldx(ptr, reg, flags)` — `ldx`/`ldy`/`stx`/`sty`/`ldz`/`stz`/`ldzi`/`stzi` のオペランドを構築
- `amx.fmaOp(flags)` — `amx.FmaFlags` から FMA/FMS オペランドを構築
- `amx.mac16Op(flags)` — `amx.Mac16Flags` から `mac16` オペランドを構築
- `amx.extrOp(flags)` — `amx.ExtrFlags` から `extrx`/`extry` オペランドを構築

## 安全性と互換性

- 以下の場合、AMX 命令は **illegal-instruction 例外** を発生させます：
  - 現在のスレッドが `set()` を呼び出していない
  - Apple Silicon 以外のハードウェアで実行している
  - オペレーティングシステムがプロセスに対して AMX を有効にしていない
- 本ライブラリには実行時検出機能は含まれていません。呼び出し側は互換性のあるハードウェア上で実行していることを確認する必要があります。

## 公開

Zig エコシステムで本パッケージを公開する方法は [PUBLISHING.md](PUBLISHING.md) を参照してください。

## ライセンス

MIT ライセンス — 詳細は [LICENSE](LICENSE) をご覧ください。
