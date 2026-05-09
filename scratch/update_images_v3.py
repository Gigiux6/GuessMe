import json
import urllib.request
import urllib.parse
import time

def search_and_get_image(name, lang='it'):
    """Search for a name and get the image of the first result."""
    search_url = f"https://{lang}.wikipedia.org/w/api.php?action=query&list=search&srsearch={urllib.parse.quote(name)}&srlimit=1&format=json"
    req = urllib.request.Request(search_url, headers={'User-Agent': 'GuessMeAppBot/1.0 (lespo.dev@gmail.com)'})
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            search_results = data.get('query', {}).get('search', [])
            if not search_results:
                return None
            
            best_title = search_results[0]['title']
            
            # Now get the image for this title
            image_url = f"https://{lang}.wikipedia.org/w/api.php?action=query&titles={urllib.parse.quote(best_title)}&prop=pageimages&format=json&pithumbsize=500"
            req_img = urllib.request.Request(image_url, headers={'User-Agent': 'GuessMeAppBot/1.0 (lespo.dev@gmail.com)'})
            
            with urllib.request.urlopen(req_img) as img_response:
                img_data = json.loads(img_response.read().decode())
                pages = img_data.get('query', {}).get('pages', {})
                for p_id, p_info in pages.items():
                    thumb = p_info.get('thumbnail', {}).get('source')
                    if thumb:
                        return thumb
    except Exception:
        pass
    return None

def main():
    json_path = 'assets/data/characters.json'
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    identities_to_update = []
    for pack in data['packs']:
        for identity in pack['identities']:
            if 'ui-avatars.com' in identity['imageUrl']:
                identities_to_update.append(identity)

    print(f"Final pass: {len(identities_to_update)} identities left.")

    total_updated = 0
    for identity in identities_to_update:
        name = identity['name']
        print(f"Searching for {name}...")
        
        # Try search on Italian wiki first (many remaining are Italian)
        thumb = search_and_get_image(name, 'it')
        if not thumb:
            # Try search on English wiki
            thumb = search_and_get_image(name, 'en')
            
        if thumb:
            identity['imageUrl'] = thumb
            total_updated += 1
            print(f"  Found: {thumb}")
        else:
            print(f"  Not found.")
            
        time.sleep(0.3) # Wait a bit between searches (single titles now)

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated {total_updated} additional identities in final pass.")

if __name__ == "__main__":
    main()
