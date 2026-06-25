# OmegaT DeepL Fix

Fixes the "403 Forbidden" error in OmegaT's DeepL translator.

## Quick start

```bash
./fix.sh --dry-run          # preview
./fix.sh                    # patch OmegaT
```

The script finds OmegaT automatically. No JDK required.

## Other modes

```bash
./fix.sh --check            # verify if patched
./fix.sh --undo             # restore from latest backup
./fix.sh --undo --choose    # pick a specific backup
```

## Backward compat

```bash
./build.sh                  # same as ./fix.sh
./verify.sh                 # same as ./fix.sh --check
./restore.sh                # same as ./fix.sh --undo
```

## Files

| File | Purpose |
|---|---|
| `fix.sh` | Main script (build, check, undo) |
| `build.sh` / `verify.sh` / `restore.sh` | Wrappers around fix.sh |
| `patch/` | Modified source + precompiled class |
