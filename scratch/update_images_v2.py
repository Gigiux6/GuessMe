import json
import urllib.request
import urllib.parse
import time

def fetch_images_from_wiki(names, lang='en'):
    """Fetch thumbnail URLs for a list of names from a specific Wikipedia API."""
    if not names:
        return {}
    
    titles = "|".join([urllib.parse.quote(name) for name in names])
    url = f"https://{lang}.wikipedia.org/w/api.php?action=query&titles={titles}&prop=pageimages&format=json&pithumbsize=500&pilimit=50&redirects=1"
    
    req = urllib.request.Request(url, headers={'User-Agent': 'GuessMeAppBot/1.0 (lespo.dev@gmail.com)'})
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            
            # Handle redirects
            redirect_map = {}
            if 'redirects' in data.get('query', {}):
                for r in data['query']['redirects']:
                    redirect_map[r['to']] = r['from']

            pages = data.get('query', {}).get('pages', {})
            results = {}
            for page_id, page_info in pages.items():
                title = page_info.get('title')
                thumbnail = page_info.get('thumbnail', {}).get('source')
                if thumbnail:
                    # Map back to original name if it was a redirect
                    original_name = redirect_map.get(title, title)
                    results[original_name] = thumbnail
            return results
    except Exception as e:
        print(f"Error fetching images from {lang} wiki: {e}")
        return {}

def main():
    json_path = 'assets/data/characters.json'
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    identities_to_update = []
    for pack in data['packs']:
        for identity in pack['identities']:
            if 'ui-avatars.com' in identity['imageUrl']:
                identities_to_update.append(identity)

    print(f"Remaining identities needing images: {len(identities_to_update)}")

    batch_size = 50
    total_updated = 0
    
    for i in range(0, len(identities_to_update), batch_size):
        batch = identities_to_update[i:i+batch_size]
        batch_names = [id['name'] for id in batch]
        
        print(f"Processing batch {i//batch_size + 1}... ({len(batch_names)} names)")
        
        # Try English Wikipedia first
        image_map = fetch_images_from_wiki(batch_names, 'en')
        
        # Identify names still missing images
        missing_after_en = [name for name in batch_names if name not in image_map]
        
        # Try Italian Wikipedia for missing ones
        if missing_after_en:
            it_image_map = fetch_images_from_wiki(missing_after_en, 'it')
            image_map.update(it_image_map)
        
        # Apply updates
        for identity in batch:
            name = identity['name']
            if name in image_map:
                identity['imageUrl'] = image_map[name]
                total_updated += 1
        
        time.sleep(0.5)

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated {total_updated} additional identities.")

if __name__ == "__main__":
    main()
