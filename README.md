# OmegaT DeepL Fix

[![CI](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml/badge.svg)](https://github.com/dadapunk/omegat-deepl-fix/actions/workflows/ci.yml)

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

### Manual patch (no script)

If you prefer to apply the patch by hand:

```bash
# 1. Backup
cp "$OMEGAT_DIR/OmegaT.jar" "$OMEGAT_DIR/OmegaT.jar.bak"

# 2. Build classpath (OmegaT.jar + all jars in lib/)
CLASSPATH="$OMEGAT_DIR/OmegaT.jar"
for jar in "$OMEGAT_DIR"/lib/*.jar; do
    CLASSPATH="$CLASSPATH:$jar"
done

# 3. Compile
javac -cp "$CLASSPATH" patch/org/omegat/core/machinetranslators/DeepLTranslate.java

# 4. Patch the JAR
jar uf "$OMEGAT_DIR/OmegaT.jar" \
  -C patch org/omegat/core/machinetranslators/DeepLTranslate.class

# 5. Verify
jar tf "$OMEGAT_DIR/OmegaT.jar" | grep DeepLTranslate.class
```

**Requirements:** JDK 11+ (`javac` and `jar`)

### Verify the patch

```bash
./verify.sh --omegat-dir ~/.local/opt/omegat/OmegaT_6.0.1_Without_JRE
```

### Configure OmegaT

Once patched, open OmegaT and set your DeepL API key in the GUI:

1. **Options → Preferences → Machine Translation**
2. Tick the **DeepL** checkbox
3. Paste your API key (e.g. `e41c2018-...:fx`)
4. Click **OK**

The key is persisted in OmegaT's config and survives OmegaT updates (the API key
is stored separately from the JAR). Only the patch itself needs to be re-applied
after an update.

To confirm it works, open a project, click a segment, and check the Machine
Translation pane for a translation.

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
