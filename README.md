# OmegaT DeepL Fix

[![CI](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml)

Fixes the "403 Forbidden" error in OmegaT's DeepL translator.

## Quick start

```bash
./build.sh --dry-run          # preview
./build.sh                    # patch OmegaT
```

The script finds OmegaT automatically. Press Enter to start.

## Restore

```bash
./restore.sh                  # undo the patch
./restore.sh --choose         # pick a specific backup
```

## Verify

```bash
./verify.sh                   # check if OmegaT is patched
```

## Files

| File | Purpose |
|---|---|
| `build.sh` | Patch OmegaT |
| `restore.sh` | Restore from backup |
| `verify.sh` | Check patch status |
| `patch/` | Modified source code |
