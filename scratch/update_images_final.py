import re
import sys
import time
from duckduckgo_search import DDGS

file_path = r'c:\Progetti\Google Antigravity\lib\data\game_packs.dart'

with open(file_path, 'r', encoding='utf-8') as f:
    content = f.read()

pattern = re.compile(r"GameIdentity\(name:\s*'([^']+)',\s*imageUrl:\s*'([^']+)'\)")
matches = pattern.findall(content)

new_content = content
total = len(matches)
print(f"Found {total} identities.")

with DDGS() as ddgs:
    for i, (name, url) in enumerate(matches):
        if 'ui-avatars.com' not in url:
            continue
            
        print(f"[{i+1}/{total}] Searching for {name}...")
        img_url = None
        for attempt in range(3):
            try:
                results = list(ddgs.images(name + " character", max_results=1))
                if results and len(results) > 0:
                    img_url = results[0]['image']
                    break
            except Exception as e:
                print(f"Error fetching {name}: {e}")
                time.sleep(1)
                
        if not img_url:
            # Try again without "character" suffix if it failed
            for attempt in range(2):
                try:
                    results = list(ddgs.images(name, max_results=1))
                    if results and len(results) > 0:
                        img_url = results[0]['image']
                        break
                except Exception:
                    time.sleep(1)
        
        if img_url:
            print(f"  Found: {img_url}")
            old_str = f"GameIdentity(name: '{name}', imageUrl: '{url}')"
            new_str = f"GameIdentity(name: '{name}', imageUrl: '{img_url}')"
            new_content = new_content.replace(old_str, new_str)
        else:
            print(f"  Failed to find image for {name}")

        time.sleep(1) # Be nice to the API

with open(file_path, 'w', encoding='utf-8') as f:
    f.write(new_content)

print("Done updating file.")
