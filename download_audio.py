import urllib.request
import os

os.makedirs('assets/audio', exist_ok=True)

# Success sound (Ding)
urllib.request.urlretrieve('https://assets.mixkit.co/active_storage/sfx/2000/2000-preview.mp3', 'assets/audio/success.mp3')

# Whoosh sound (Pass)
urllib.request.urlretrieve('https://assets.mixkit.co/active_storage/sfx/2945/2945-preview.mp3', 'assets/audio/whoosh.mp3')

print("Downloaded audio assets successfully.")
