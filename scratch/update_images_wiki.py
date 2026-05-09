import urllib.request
import urllib.parse
import json
import re
import concurrent.futures

file_path = r'c:\Progetti\Google Antigravity\lib\data\game_packs.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r"GameIdentity\(name:\s*'([^']+)',\s*imageUrl:\s*'([^']+)'\)")
matches = pattern.findall(content)

def get_wiki_image(name):
    # Try italian first
    try:
        url = 'https://it.wikipedia.org/api/rest_v1/page/summary/' + urllib.parse.quote(name.replace(' ', '_'))
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        res = urllib.request.urlopen(req, timeout=5).read()
        data = json.loads(res)
        if 'thumbnail' in data:
            return data['thumbnail']['source']
    except Exception:
        pass
        
    # Try english
    try:
        url = 'https://en.wikipedia.org/api/rest_v1/page/summary/' + urllib.parse.quote(name.replace(' ', '_'))
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0'})
        res = urllib.request.urlopen(req, timeout=5).read()
        data = json.loads(res)
        if 'thumbnail' in data:
            return data['thumbnail']['source']
    except Exception:
        pass
        
    # fallback to a generic image placeholder using unsplash with keyword
    # But since the user wants specific, let's use unsplash source
    return f"https://images.unsplash.com/photo-1533738363-b7f9aef128ce?w=256&q=80" # A nice placeholder if missing

new_content = content
for i, (name, url) in enumerate(matches):
    if 'ui-avatars.com' not in url:
        continue
        
    img = get_wiki_image(name)
    if not img or "unsplash.com" in img:
        # unsplash source fallback based on name
        img = f"https://source.unsplash.com/256x256/?{urllib.parse.quote(name)}"

    old_str = f"GameIdentity(name: '{name}', imageUrl: '{url}')"
    new_str = f"GameIdentity(name: '{name}', imageUrl: '{img}')"
    new_content = new_content.replace(old_str, new_str)
    print(f"Replaced {name} -> {img}")

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done updating file.")
