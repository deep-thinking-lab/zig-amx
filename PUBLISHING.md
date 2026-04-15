# Publishing zig-amx

The Zig package manager does not use a central registry like npm or crates.io. Instead, packages are distributed as plain URLs (git repositories or tarballs). Anyone with the URL can fetch and verify the package using its cryptographic hash.

## Prerequisites

- A valid `build.zig.zon` (already present)
- The package hosted in a public git repository (e.g., GitHub)

## Step-by-step: publish on GitHub

### 1. Push the repository

```bash
git init
git add .
git commit -m "Initial release"
git remote add origin https://github.com/YOUR_USERNAME/zig-amx.git
git push -u origin main
```

### 2. Create a git tag

```bash
git tag v0.1.0
git push origin v0.1.0
```

### 3. (Optional) Create a GitHub Release

Go to **GitHub → Releases → Draft a new release**, choose tag `v0.1.0`, and publish. This gives you a stable tarball URL.

## How users consume the package

### Option A: fetch from tarball

```bash
zig fetch --save https://github.com/YOUR_USERNAME/zig-amx/archive/refs/tags/v0.1.0.tar.gz
```

### Option B: fetch from git

```bash
zig fetch --save git+https://github.com/YOUR_USERNAME/zig-amx.git
```

Both commands will:
1. Download the package
2. Compute its hash
3. Append an entry to the user's `build.zig.zon`

## Example `build.zig.zon` for consumers

After running `zig fetch --save`, the user's `build.zig.zon` will look like:

```zig
.{
    .name = .my_project,
    .version = "0.1.0",
    .dependencies = .{
        .amx = .{
            .url = "https://github.com/YOUR_USERNAME/zig-amx/archive/refs/tags/v0.1.0.tar.gz",
            .hash = "1220xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx",
        },
    },
}
```

## Keeping the fingerprint stable

The `fingerprint` field in `build.zig.zon` acts as a persistent package identity. **Never change it** once the package has been published, or consumers will treat it as a completely different package.

## Community listings (optional)

You can also list the package on community indexes for discoverability:

- [astrolabe.pm](https://astrolabe.pm) — Zig package index
- [zigistry.dev](https://zigistry.dev) — Zig package registry

For these, you usually just point them to your GitHub repository URL.
