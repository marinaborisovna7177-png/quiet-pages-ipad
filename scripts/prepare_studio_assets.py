#!/usr/bin/env python3
"""Build offline files and bounded thumbnails, preserving every legacy asset ID."""
from pathlib import Path
import zipfile, json
from PIL import Image
ROOT = Path(__file__).resolve().parents[1]
assets = ROOT / 'Resources/Assets.xcassets'
out = ROOT / 'Resources/StudioAssets'
for part in sorted((ROOT/'StickerPacks').glob('MegaStickers_*.zip')):
    with zipfile.ZipFile(part) as archive:
        for info in archive.infolist():
            target = (assets / info.filename).resolve()
            if not target.is_relative_to(assets.resolve()):
                raise ValueError('Unsafe archive member')
        archive.extractall(assets)
for name in ('stickers','thumbnails'):
    (out/name).mkdir(parents=True, exist_ok=True)
manifest=[]
for folder in sorted(assets.glob('Sticker_*.imageset')):
    spec=json.loads((folder/'Contents.json').read_text())
    source=next((folder/i['filename'] for i in spec['images'] if i.get('filename')),None)
    if not source: continue
    key=folder.stem.removeprefix('Sticker_')
    with Image.open(source) as image:
        image.load()
        rgba=image.convert('RGBA')
        # Canvas files bounded to 1024; original sources remain in asset catalog.
        rgba.thumbnail((1024,1024),Image.Resampling.LANCZOS)
        rgba.save(out/'stickers'/f'{key}.png',optimize=True)
        rgba.thumbnail((192,192),Image.Resampling.LANCZOS)
        rgba.save(out/'thumbnails'/f'{key}.png',optimize=True)
        manifest.append({'id':key,'width':image.width,'height':image.height,'thumbnailWidth':rgba.width,'thumbnailHeight':rgba.height,'alpha':rgba.getchannel('A').getextrema()[0]<255})
(out/'manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
print(f'{len(manifest)} sticker images validated; 192px previews ready')
