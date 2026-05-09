import urllib.request
import urllib.parse
import re
import time

def get_image(query):
    try:
        url = 'https://html.duckduckgo.com/html/?q=' + urllib.parse.quote(query + ' image')
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        html = urllib.request.urlopen(req).read().decode('utf-8')
        
        # Look for vqd
        vqd_match = re.search(r'vqd=([\d-]+)', html)
        if not vqd_match:
            return None
        vqd = vqd_match.group(1)
        
        # Now search images
        url = 'https://duckduckgo.com/i.js?l=us-en&o=json&q=' + urllib.parse.quote(query) + '&vqd=' + vqd
        req = urllib.request.Request(url, headers={'User-Agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64)'})
        res = urllib.request.urlopen(req).read().decode('utf-8')
        
        import json
        data = json.loads(res)
        if 'results' in data and len(data['results']) > 0:
            return data['results'][0]['image']
    except Exception as e:
        print(f"Error fetching {query}: {e}")
        return None

file_path = r'c:\Progetti\Google Antigravity\lib\data\game_packs.dart'
with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r"GameIdentity\(name:\s*'([^']+)',\s*imageUrl:\s*'([^']+)'\)")
matches = pattern.findall(content)
new_content = content

print(f"Found {len(matches)} identities.")
for i, (name, url) in enumerate(matches):
    if 'ui-avatars.com' not in url:
        continue
    print(f"[{i+1}/{len(matches)}] Searching for {name}...")
    img_url = get_image(name)
    if img_url:
        print(f"  Found: {img_url}")
        old_str = f"GameIdentity(name: '{name}', imageUrl: '{url}')"
        new_str = f"GameIdentity(name: '{name}', imageUrl: '{img_url}')"
        new_content = new_content.replace(old_str, new_str)
    else:
        print(f"  No image found for {name}")
    time.sleep(1) # delay to avoid rate limit

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done.")
