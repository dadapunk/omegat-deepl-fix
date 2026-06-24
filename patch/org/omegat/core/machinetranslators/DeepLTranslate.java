package org.omegat.core.machinetranslators;

import java.awt.Window;
import java.util.Map;
import java.util.TreeMap;

import com.fasterxml.jackson.databind.JsonNode;
import com.fasterxml.jackson.databind.ObjectMapper;
import com.fasterxml.jackson.databind.node.ArrayNode;
import com.fasterxml.jackson.databind.node.ObjectNode;

import org.omegat.core.Core;
import org.omegat.gui.exttrans.MTConfigDialog;
import org.omegat.util.HttpConnectionUtils;
import org.omegat.util.Language;
import org.omegat.util.Log;
import org.omegat.util.OStrings;
import org.omegat.util.Preferences;

public class DeepLTranslate extends BaseCachedTranslate {
    protected static final String PROPERTY_API_KEY = "deepl.api.key";
    protected static final String DEEPL_URL = "https://api-free.deepl.com/v2/translate";
    private final static int MAX_TEXT_LENGTH = 5000;

    @Override
    protected String getPreferenceName() {
        return Preferences.ALLOW_DEEPL_TRANSLATE;
    }

    @Override
    public String getName() {
        return OStrings.getString("MT_ENGINE_DEEPL");
    }

    @Override
    protected String translate(Language sLang, Language tLang, String text) throws Exception {
        String trText = text.length() > MAX_TEXT_LENGTH ? text.substring(0, MAX_TEXT_LENGTH - 3) + "..." :
                text;
        String prev = getFromCache(sLang, tLang, trText);
        if (prev != null) {
            return prev;
        }

        String apiKey = getCredential(PROPERTY_API_KEY);

        if (apiKey == null || apiKey.isEmpty()) {
            throw new Exception(OStrings.getString("DEEPL_API_KEY_NOTFOUND"));
        }

        String splitSentence = Core.getProject().getProjectProperties().isSentenceSegmentingEnabled() ? "1"
                : "0";

        ObjectMapper mapper = new ObjectMapper();
        ArrayNode textArray = mapper.createArrayNode();
        textArray.add(trText);
        ObjectNode root = mapper.createObjectNode();
        root.set("text", textArray);
        root.put("source_lang", sLang.getLanguageCode().toUpperCase());
        root.put("target_lang", tLang.getLanguageCode().toUpperCase());
        root.put("tag_handling", "xml");
        root.put("split_sentences", splitSentence);
        String json = mapper.writeValueAsString(root);

        Map<String, String> headers = new TreeMap<>();
        headers.put("Authorization", "DeepL-Auth-Key " + apiKey);
        headers.put("User-Agent", "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36");

        String v = HttpConnectionUtils.postJSON(DEEPL_URL, json, headers);
        String tr = getJsonResults(v);
        if (tr == null) {
            return null;
        }
        tr = unescapeHTML(tr);
        tr = cleanSpacesAroundTags(tr, trText);
        putToCache(sLang, tLang, trText, tr);
        return tr;
    }

    @SuppressWarnings("unchecked")
    protected String getJsonResults(String json) {
        ObjectMapper mapper = new ObjectMapper();
        try {
            JsonNode rootNode = mapper.readTree(json);
            JsonNode translations = rootNode.get("translations");
            if (translations.has(0)) {
                return translations.get(0).get("text").asText();
            }
        } catch (Exception e) {
            Log.logErrorRB(e, "MT_JSON_ERROR");
            return OStrings.getString("MT_JSON_ERROR");
        }
        return null;
    }

    @Override
    public boolean isConfigurable() {
        return true;
    }

    @Override
    public void showConfigurationUI(Window parent) {

        MTConfigDialog dialog = new MTConfigDialog(parent, getName()) {
            @Override
            protected void onConfirm() {
                String key = panel.valueField1.getText().trim();
                boolean temporary = panel.temporaryCheckBox.isSelected();
                setCredential(PROPERTY_API_KEY, key, temporary);
            }
        };

        dialog.panel.valueLabel1.setText(OStrings.getString("MT_ENGINE_DEEPL_API_KEY_LABEL"));
        dialog.panel.valueField1.setText(getCredential(PROPERTY_API_KEY));

        dialog.panel.valueLabel2.setVisible(false);
        dialog.panel.valueField2.setVisible(false);

        dialog.panel.temporaryCheckBox.setSelected(isCredentialStoredTemporarily(PROPERTY_API_KEY));

        dialog.show();
    }
}
