import os
import re
import urllib.request
import urllib.parse
import json
import time

def translate_text(text, target_lang):
    if not text.strip(): return text
    
    # Do not translate brand names and format strings
    protect = ['Top Notch', 'YouTube', 'Spotify', 'Podcasts', 'Touch ID', 'HUD', 'Safari', 'Mac', 'Claude', 'Pomodoro', '%@', '%d', '⌘⇧Y', 'H:', 'L:']
    
    mapping = {}
    protected_text = text
    for i, p in enumerate(protect):
        placeholder = f' __P{i}__ '
        if p in protected_text:
            mapping[placeholder.strip()] = p
            protected_text = protected_text.replace(p, placeholder)
            
    url = f'https://translate.googleapis.com/translate_a/single?client=gtx&sl=en&tl={target_lang}&dt=t&q={urllib.parse.quote(protected_text.strip())}'
    
    req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
    try:
        resp = urllib.request.urlopen(req)
        res_json = json.loads(resp.read().decode())
        translated = ''.join(part[0] for part in res_json[0] if part[0])
    except Exception as e:
        print(f'Error translating {text}: {e}')
        return text

    # Restore protected words
    for placeholder, original in mapping.items():
        translated = translated.replace(placeholder.strip(), original)
        translated = translated.replace(placeholder.strip().lower(), original)
        
    translated = translated.replace(' % @', ' %@').replace('% @', '%@')
    translated = translated.replace(' % d', ' %d').replace('% d', '%d')
    translated = translated.replace(' ⌘⇧Y', ' ⌘⇧Y')
    
    return translated.strip()

en_file = '/Users/iamabillionaire/Downloads/topnotch/MyDynamicIsland/en.lproj/Localizable.strings'
with open(en_file, 'r', encoding='utf-8') as f:
    en_lines = f.readlines()
    
langs = ['ru', 'tr', 'ar', 'th', 'sv', 'da', 'vi', 'nb', 'pl', 'fi', 'id', 'ms', 'el', 'cs', 'hu', 'ro', 'uk']

base_dir = '/Users/iamabillionaire/Downloads/topnotch/MyDynamicIsland'

total_langs = len(langs)
for index, lang in enumerate(langs):
    lproj_dir = os.path.join(base_dir, f'{lang}.lproj')
    os.makedirs(lproj_dir, exist_ok=True)
    dest_file = os.path.join(lproj_dir, 'Localizable.strings')
    
    print(f'Translating for {lang} ({index+1}/{total_langs})...')
    translated_lines = []
    for line in en_lines:
        match = re.match(r'^\"([^\"]+)\"\s*=\s*\"([^\"]+)\";', line)
        if match:
            key, value = match.groups()
            if value in ['Top Notch', 'YouTube', 'Spotify', 'Podcasts', 'Cyan', 'Orange']:
                trans_val = value
            else:
                trans_val = translate_text(value, lang)
                time.sleep(0.05)
            translated_lines.append(f'\"{key}\" = \"{trans_val}\";\n')
        else:
            translated_lines.append(line)
    
    with open(dest_file, 'w', encoding='utf-8') as f:
        f.writelines(translated_lines)
        
print('All 17 additional languages successfully translated!')