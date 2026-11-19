# Vendoring

Vendored C/C++ libraries live under `Sources/`. They are never edited by hand; all local changes are patch files in `Vendor/patches/`.

## How to re-vendor

```bash
scripts/vendor.sh   # copies pinned upstream tags, applies patches, records commits
```

## How to verify

```bash
scripts/check-vendor.sh   # fails if the tree differs from upstream + patches
```

## Adding a patch

1. Make the change inside the relevant `Sources/C*/` tree.
2. Mark the changed lines with `/// PATCH BEGIN` / `/// PATCH END`.
3. Run `git diff > Vendor/patches/NNNN-short-description.patch`.
4. Add a line to `Vendor/PATCHES.md`.
5. Run `scripts/check-vendor.sh` to verify it round-trips cleanly.
