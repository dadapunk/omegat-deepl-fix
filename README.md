# OmegaT DeepL Fix

Patches OmegaT's built-in DeepLTranslate to use the modern DeepL API v2,
fixing `403 Forbidden` errors on Free (`:fx`) API keys.

## Problem

OmegaT 6.x uses the deprecated DeepL v1 API with `auth_key` as a query parameter.
DeepL deprecated this method in November 2025. Free (`:fx`) accounts now get
`403 Forbidden` when using the v1 endpoint.

## What this patch does

- Switches endpoint from `api.deepl.com/v1` → `api-free.deepl.com/v2`
- Changes from GET with query params to POST with JSON body
- Uses `Authorization: DeepL-Auth-Key` header instead of `auth_key` param
- Sets a browser-style User-Agent to avoid CAT tool detection
- Reads `DEEPL_API_HOST` env var (defaults to `api-free.deepl.com`)

## Disclaimer

This patch is provided for **development and experimental purposes only**.
DeepL's Free API (`:fx` keys) is not licensed for CAT tool usage.
If you need DeepL integration with OmegaT for **professional or commercial work**,
please purchase a [DeepL API plan](https://www.deepl.com/pro#developer) that
supports CAT tool integration and use the official OmegaT DeepL plugin without
modifications.

Using this patch with a Free API key may violate DeepL's Terms of Service.
You are responsible for ensuring compliance.

## Requirements

- OmegaT 6.x installed manually (ZIP/tar.gz) — does not work with Flatpak
- Java 11+ installed
- DeepL API key (Free or Pro)

## Usage

### Apply the patch

```bash
# Clone and build
git clone https://github.com/dadapunk/omegat-deepl-fix.git
cd omegat-deepl-fix

# Apply the patch to your OmegaT installation
./build.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE

# Or via env var
export OMEGAT_DIR=~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
./build.sh
```

### Verify the patch

```bash
./verify.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
```

### Restore the original

```bash
./restore.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
```

### Free vs Pro accounts

The patch defaults to `api-free.deepl.com` (Free tier). If you have a **Pro**
account, set the env var before launching OmegaT:

```bash
export DEEPL_API_HOST=api.deepl.com
omegat
```

## After updating OmegaT

OmegaT updates replace `OmegaT.jar`, which removes the patch.
After updating, re-run `./build.sh` to re-apply it.

## Files

| File | Description |
|---|---|
| `patch/.../DeepLTranslate.java` | Patched source file (GPL-3.0) |
| `build.sh` | Compile and patch OmegaT.jar |
| `restore.sh` | Restore OmegaT.jar from backup |
| `verify.sh` | Check if patch is applied and correct |

## License

GPL-3.0 — same as OmegaT.
