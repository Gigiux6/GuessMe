import json
import urllib.request
import urllib.parse
import time

def get_wikimedia_images(names):
    """Fetch thumbnail URLs for a list of names from Wikimedia API."""
    if not names:
        return {}
    
    # We can query up to 50 titles at a time
    titles = "|".join([urllib.parse.quote(name) for name in names])
    url = f"https://en.wikipedia.org/w/api.php?action=query&titles={titles}&prop=pageimages&format=json&pithumbsize=500&pilimit=50"
    
    # Wikipedia requires a User-Agent header
    req = urllib.request.Request(url, headers={'User-Agent': 'GuessMeAppBot/1.0 (lespo.dev@gmail.com)'})
    
    try:
        with urllib.request.urlopen(req) as response:
            data = json.loads(response.read().decode())
            pages = data.get('query', {}).get('pages', {})
            
            results = {}
            for page_id, page_info in pages.items():
                title = page_info.get('title')
                thumbnail = page_info.get('thumbnail', {}).get('source')
                if thumbnail:
                    results[title] = thumbnail
            return results
    except Exception as e:
        print(f"Error fetching images for {names[:3]}...: {e}")
        return {}

def main():
    json_path = 'assets/data/characters.json'
    with open(json_path, 'r', encoding='utf-8') as f:
        data = json.load(f)

    all_names_needing_images = []
    identities_to_update = []

    for pack in data['packs']:
        for identity in pack['identities']:
            if 'ui-avatars.com' in identity['imageUrl']:
                all_names_needing_images.append(identity['name'])
                identities_to_update.append(identity)

    print(f"Total identities needing images: {len(all_names_needing_images)}")

    # Process in batches of 50
    batch_size = 50
    updated_count = 0
    
    for i in range(0, len(all_names_needing_images), batch_size):
        batch_names = all_names_needing_images[i:i+batch_size]
        print(f"Processing batch {i//batch_size + 1}... ({len(batch_names)} names)")
        
        image_map = get_wikimedia_images(batch_names)
        
        # Match images back to identities
        # Note: Wikipedia might return titles slightly differently (e.g. "Rihanna" vs "Rihanna (singer)")
        # So we do a case-insensitive match or similar if needed.
        for name in batch_names:
            if name in image_map:
                # Find the identity in our to-update list
                for identity in identities_to_update:
                    if identity['name'] == name:
                        identity['imageUrl'] = image_map[name]
                        updated_count += 1
                        break
        
        time.sleep(0.5) # Be nice to the API

    with open(json_path, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)

    print(f"Successfully updated {updated_count} identities.")

if __name__ == "__main__":
    main()
