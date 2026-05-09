import json

with open('assets/data/characters.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

for pack in data['packs']:
    print(f"Pack: {pack['name']} ({pack['id']}) - Identities: {len(pack['identities'])}")
