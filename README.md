# OmegaT DeepL Fix

Fixes the "403 Forbidden" error in OmegaT's DeepL translator.

## Quick start

```bash
./fix.sh --dry-run          # preview
./fix.sh                    # patch OmegaT
```

The script finds OmegaT automatically if it is in `/Applications/OmegaT.app`.
If you launched OmegaT from a `.dmg` without installing it, drag it to `/Applications` first.
No JDK required.

## Other modes

```bash
./fix.sh --check            # verify if patched
./fix.sh --undo             # restore from latest backup
./fix.sh --undo --choose    # pick a specific backup
```

## Files

| File | Purpose |
|---|---|
| `fix.sh` | Main script (build, check, undo) |
| `patch/` | Modified source + precompiled class |
