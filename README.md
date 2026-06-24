# OmegaT DeepL Fix

Patches OmegaT's built-in DeepLTranslate to use the modern DeepL API v2,
fixing `403 Forbidden` errors on Free (`:fx`) API keys.

## Problem

OmegaT 6.x uses the deprecated DeepL v1 API with `auth_key` as a query parameter.
DeepL has deprecated this method and now returns `403 Forbidden` for Free accounts.

## What this patch does

- Changes endpoint from `api.deepl.com/v1` → `api-free.deepl.com/v2`
- Switches from GET with query params to POST with JSON body
- Uses `Authorization: DeepL-Auth-Key` header instead of `auth_key` param
- Sets a browser User-Agent header to avoid CAT tool detection

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

- OmegaT 6.x installed manually (ZIP/tar.gz, not Flatpak)
- Java 11+ (OmegaT requirement)
- DeepL API key (Free or Pro)

## Usage

```bash
# Clone and build
git clone https://github.com/dadapunk/omegat-deepl-fix.git
cd omegat-deepl-fix

# Apply the patch to your OmegaT installation
# (adjust path if OmegaT is installed elsewhere)
./build.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE

# Or use OMEGAT_DIR env var
export OMEGAT_DIR=~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
./build.sh
```

## Files

| File | Description |
|---|---|
| `patch/.../DeepLTranslate.java` | Patched source file (GPL-3.0) |
| `build.sh` | Compile and patch OmegaT.jar script |

## License

GPL-3.0 — same as OmegaT.
