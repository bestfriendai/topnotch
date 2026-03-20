#!/usr/bin/env python3
"""
Translate App Store metadata for Top Notch using Gemini API.
Usage: python3 translate_appstore.py <store_locale> <lang_name>
Example: python3 translate_appstore.py de-DE German
"""

import sys
import json
import os
import re
import shutil
import urllib.request

GEMINI_API_KEY = "AIzaSyAYDXpoyXY2csVMAiRJnA2OagVdo5HlPco"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"
METADATA_DIR = "/Users/iamabillionaire/Downloads/topnotch/fastlane/metadata"
EN_DIR = f"{METADATA_DIR}/en-US"

# Files to translate (not URLs/categories)
TRANSLATE_FILES = ["subtitle.txt", "description.txt", "keywords.txt",
                   "promotional_text.txt", "release_notes.txt"]
# Files to copy as-is
COPY_FILES = ["name.txt", "privacy_url.txt", "support_url.txt",
              "marketing_url.txt", "apple_tv_privacy_policy.txt"]

def read_file(path):
    try:
        with open(path, "r", encoding="utf-8") as f:
            return f.read().strip()
    except FileNotFoundError:
        return ""

def gemini_translate_batch(texts_dict, target_lang, locale):
    """Translate multiple app store text fields at once."""
    items_json = json.dumps(texts_dict, ensure_ascii=False, indent=2)

    prompt = f"""You are a professional App Store copywriter and localizer. Translate the following macOS app store listing texts from English to {target_lang} (App Store locale: {locale}).

STRICT RULES:
- Keep "Top Notch" as the app name (do not translate)
- Keep "YouTube", "Spotify", "Apple Music", "Safari", "Pomodoro", "Mac", "MacBook Pro" as brand names
- Keep feature names like "Shortcuts", "Touch ID" unchanged
- "keywords" field: translate keywords to {target_lang}, keep them relevant for App Store search, comma-separated, max 100 chars total
- "name" field: keep as "Top Notch - Enhance Your Notch" or adapt subtitle part naturally
- ALL_CAPS section headers in description (like "WATCH YOUTUBE WITHOUT OPENING A BROWSER") should be translated and stay ALL CAPS
- Preserve line breaks and paragraph structure in description and release_notes
- Return ONLY a valid JSON object — same keys, translated values
- No markdown, no explanation, no code fences

Input:
{items_json}"""

    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {"temperature": 0.2, "maxOutputTokens": 16384}
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(GEMINI_URL, data=data,
                                  headers={"Content-Type": "application/json"}, method="POST")
    with urllib.request.urlopen(req, timeout=120) as resp:
        result = json.loads(resp.read().decode("utf-8"))

    text = result["candidates"][0]["content"]["parts"][0]["text"].strip()
    text = re.sub(r"^```[a-z]*\n?", "", text)
    text = re.sub(r"\n?```$", "", text).strip()
    return json.loads(text)

def main():
    if len(sys.argv) < 3:
        print("Usage: python3 translate_appstore.py <store_locale> <lang_name>")
        sys.exit(1)

    locale = sys.argv[1]
    lang_name = sys.argv[2]
    target_dir = f"{METADATA_DIR}/{locale}"
    os.makedirs(target_dir, exist_ok=True)

    print(f"[{locale}] Reading English source files...")

    # Build batch of texts to translate
    texts_to_translate = {}
    for fname in TRANSLATE_FILES:
        content = read_file(f"{EN_DIR}/{fname}")
        if content:
            key = fname.replace(".txt", "")
            texts_to_translate[key] = content

    print(f"[{locale}] Translating {len(texts_to_translate)} fields to {lang_name}...")
    translated = gemini_translate_batch(texts_to_translate, lang_name, locale)

    # Write translated files
    for fname in TRANSLATE_FILES:
        key = fname.replace(".txt", "")
        content = translated.get(key, read_file(f"{EN_DIR}/{fname}"))
        out_path = f"{target_dir}/{fname}"
        with open(out_path, "w", encoding="utf-8") as f:
            f.write(content + "\n")
        print(f"[{locale}]   Wrote {fname} ({len(content)} chars)")

    # Copy non-translated files
    for fname in COPY_FILES:
        src = f"{EN_DIR}/{fname}"
        dst = f"{target_dir}/{fname}"
        if os.path.exists(src):
            shutil.copy2(src, dst)

    print(f"[{locale}] DONE.")

if __name__ == "__main__":
    main()
