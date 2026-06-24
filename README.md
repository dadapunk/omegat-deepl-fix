# OmegaT DeepL Fix

[![CI](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml)

Patches OmegaT's `DeepLTranslate` to use API v2, fixing `403 Forbidden` on Free (`:fx`) keys.

## Quick start

```bash
git clone https://github.com/dadapunk/omegat-deepl-fix.git && cd omegat-deepl-fix
./build.sh --dry-run            # preview (auto-detects OmegaT)
./build.sh                      # apply the patch
```

If auto-detect fails, pass the path manually:
```bash
./build.sh --omegat-dir /Applications/OmegaT.app/Contents/Java
```

Then in OmegaT: **Options → Preferences → Machine Translation** → enable DeepL, paste your API key.

Run `./build.sh --help` for all options. Add `--install-jdk` to auto-install Java if missing.

## Disclaimer

Dev/experimental only. Free (`:fx`) keys aren't licensed for CAT tools —
purchase a [DeepL plan](https://www.deepl.com/pro#developer) for professional use.

## Files

| File | Purpose |
|---|---|
| `build.sh` | Apply the patch (creates backup, compiles, patches, verifies) |
| `restore.sh` | Restore `OmegaT.jar` from backup |
| `verify.sh` | Confirm the patch is applied |
| `patch/.../DeepLTranslate.java` | Modified source (GPL-3.0) |

## License

GPL-3.0 — same as OmegaT.
