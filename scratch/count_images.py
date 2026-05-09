import json

with open('assets/data/characters.json', 'r', encoding='utf-8') as f:
    data = json.load(f)

total_identities = 0
needs_image = 0
names_needing_image = []

for pack in data['packs']:
    for identity in pack['identities']:
        total_identities += 1
        if 'ui-avatars.com' in identity['imageUrl']:
            needs_image += 1
            names_needing_image.append(identity['name'])

print(f"Total identities: {total_identities}")
print(f"Identities needing image: {needs_image}")
print(f"Sample names: {names_needing_image[:10]}")
