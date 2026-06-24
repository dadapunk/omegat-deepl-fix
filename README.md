# OmegaT DeepL Fix

[![CI](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml)

Patches OmegaT's `DeepLTranslate` to use API v2, fixing `403 Forbidden` on Free (`:fx`) keys.

## Quick start

```bash
git clone https://github.com/dadapunk/omegat-deepl-fix.git && cd omegat-deepl-fix
./build.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
```

Then in OmegaT: **Options → Preferences → Machine Translation** → enable DeepL, paste your API key.

See `./build.sh --help` for other paths (macOS, Flatpak) and `--dry-run`.

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
