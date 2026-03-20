#!/usr/bin/env python3
"""Batch translate missing Localizable.strings using Gemini API."""

import json
import os
import re
import sys
import time
import urllib.request
import urllib.error

GEMINI_API_KEY = "AIzaSyAweXE3Qz3T_1bzO7T6j7Cjkn7UFRMkH9Y"
GEMINI_URL = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={GEMINI_API_KEY}"

BASE_DIR = "MyDynamicIsland"
EN_FILE = os.path.join(BASE_DIR, "en.lproj", "Localizable.strings")

# Map lproj folder names to language names for the prompt
LANG_MAP = {
    "ar": "Arabic",
    "cs": "Czech",
    "da": "Danish",
    "de": "German",
    "el": "Greek",
    "es": "Spanish",
    "fi": "Finnish",
    "fr": "French",
    "he": "Hebrew",
    "hu": "Hungarian",
    "id": "Indonesian",
    "it": "Italian",
    "ja": "Japanese",
    "ko": "Korean",
    "ms": "Malay",
    "nb": "Norwegian Bokmål",
    "nl": "Dutch",
    "pl": "Polish",
    "pt-BR": "Brazilian Portuguese",
    "pt-PT": "European Portuguese",
    "ro": "Romanian",
    "ru": "Russian",
    "sk": "Slovak",
    "sv": "Swedish",
    "th": "Thai",
    "tr": "Turkish",
    "uk": "Ukrainian",
    "vi": "Vietnamese",
    "zh-Hans": "Simplified Chinese",
    "zh-Hant": "Traditional Chinese",
}


def parse_strings_file(filepath):
    """Parse a .strings file and return dict of key -> value."""
    keys = {}
    if not os.path.exists(filepath):
        return keys
    with open(filepath, "r", encoding="utf-8") as f:
        content = f.read()
    pattern = re.compile(r'"([^"]+)"\s*=\s*"([^"]*)"')
    for match in pattern.finditer(content):
        key, value = match.group(1), match.group(2)
        keys[key] = value
    return keys


def parse_strings_file_ordered(filepath):
    """Parse preserving order and structure (comments + entries)."""
    entries = []
    if not os.path.exists(filepath):
        return entries
    with open(filepath, "r", encoding="utf-8") as f:
        for line in f:
            line_stripped = line.strip()
            if not line_stripped:
                entries.append(("blank", ""))
            elif line_stripped.startswith("/*") or line_stripped.startswith("//"):
                entries.append(("comment", line.rstrip("\n")))
            else:
                m = re.match(r'"([^"]+)"\s*=\s*"([^"]*)"', line_stripped)
                if m:
                    entries.append(("entry", (m.group(1), m.group(2))))
                else:
                    entries.append(("other", line.rstrip("\n")))
    return entries


def call_gemini(prompt, retries=3):
    """Call Gemini API and return the text response."""
    payload = {
        "contents": [{"parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.1,
            "maxOutputTokens": 8192,
        }
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        GEMINI_URL,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    for attempt in range(retries):
        try:
            with urllib.request.urlopen(req, timeout=60) as resp:
                result = json.loads(resp.read().decode("utf-8"))
                return result["candidates"][0]["content"]["parts"][0]["text"]
        except (urllib.error.HTTPError, urllib.error.URLError, KeyError) as e:
            print(f"  Attempt {attempt+1} failed: {e}")
            if attempt < retries - 1:
                time.sleep(2 ** attempt)
    return None


def translate_batch(missing_strings, lang_name, existing_samples):
    """Translate a batch of missing strings to the target language."""
    sample_lines = ""
    for k, v in list(existing_samples.items())[:15]:
        sample_lines += f'  "{k}" = "{v}";\n'

    missing_lines = ""
    for k, v in missing_strings.items():
        missing_lines += f'  "{k}" = "{v}";\n'

    prompt = f"""You are a professional app localizer. Translate the following iOS Localizable.strings entries from English to {lang_name}.

RULES:
- Keep the keys exactly as they are (left side of =)
- Only translate the values (right side of =)
- Keep format specifiers like %@, %d, %lld exactly as they are
- Keep emoji exactly as they are
- Keep brand names (Top Notch, YouTube, Safari, Spotify, Mac, Touch ID, Claude) unchanged
- Keep keyboard shortcuts like ⌘⇧Y unchanged
- Keep "H:" and "L:" as weather abbreviations appropriate for the language
- Output ONLY valid .strings format lines, no explanations
- Use natural, concise translations appropriate for a macOS app UI
- Match the tone and style of these existing translations in {lang_name}:

{sample_lines}

Now translate these English strings to {lang_name}:

{missing_lines}

Output ONLY the translated .strings lines, one per line, in the exact format:
"key" = "translated value";"""

    response = call_gemini(prompt)
    if not response:
        return {}

    translations = {}
    pattern = re.compile(r'"([^"]+)"\s*=\s*"([^"]*)"')
    for match in pattern.finditer(response):
        key, value = match.group(1), match.group(2)
        if key in missing_strings:
            translations[key] = value
    return translations


def rebuild_file(en_entries, existing_translations, new_translations):
    """Rebuild the .strings file using English structure, filling in translations."""
    all_translations = {**existing_translations, **new_translations}
    lines = []
    seen_keys = set()
    for entry_type, data in en_entries:
        if entry_type == "blank":
            lines.append("")
        elif entry_type == "comment":
            lines.append(data)
        elif entry_type == "entry":
            key, _ = data
            if key in all_translations and key not in seen_keys:
                lines.append(f'"{key}" = "{all_translations[key]}";')
                seen_keys.add(key)
        elif entry_type == "other":
            lines.append(data)
    return "\n".join(lines) + "\n"


def main():
    print("=== Top Notch Localization Script ===\n")

    en_keys = parse_strings_file(EN_FILE)
    en_entries = parse_strings_file_ordered(EN_FILE)
    print(f"English file: {len(en_keys)} keys\n")

    for lang_code, lang_name in sorted(LANG_MAP.items()):
        lang_dir = os.path.join(BASE_DIR, f"{lang_code}.lproj")
        lang_file = os.path.join(lang_dir, "Localizable.strings")

        existing = parse_strings_file(lang_file)
        missing_keys = {k: v for k, v in en_keys.items() if k not in existing}

        if not missing_keys:
            print(f"[{lang_code}] {lang_name}: All {len(en_keys)} keys present ✓")
            continue

        print(f"[{lang_code}] {lang_name}: {len(existing)} existing, {len(missing_keys)} missing — translating...", end=" ", flush=True)

        translations = translate_batch(missing_keys, lang_name, existing)

        if translations:
            full_content = rebuild_file(en_entries, existing, translations)
            os.makedirs(lang_dir, exist_ok=True)
            with open(lang_file, "w", encoding="utf-8") as f:
                f.write(full_content)
            print(f"✓ ({len(translations)} translated)")
        else:
            print("✗ (API error)")

        time.sleep(0.5)

    print("\n=== Done! ===")


if __name__ == "__main__":
    main()
