from pathlib import Path
import json, sys, shutil
from PIL import Image
root=Path(__file__).resolve().parents[1]
source=Path(sys.argv[1]); im=Image.open(source).convert('RGBA')
shutil.copyfile(source,root/'Artwork/Studio6_stickers_original.png')
labels=['Закладка лесная','Пионы акварельные','Бант с кружевом','Ботанический скотч','Горный пейзаж','Сказочная лестница','Волшебная книга и ключ','Спящий котёнок','Старинный фонарь','Чай с печеньем','Осенние украшения','Цветочный полароид','Старинная бумага','Книжная композиция','Зимняя веточка','Луна и звёзды']
categories=['Винтажные закладки','Акварельные растения','Банты и кружево','Декоративный скотч','Пейзажные бордюры','Сказочные объекты','Книги, письма и ключи','Животные','Часы, фонари и свечи','Чай и десерты','Сезонные украшения','Рамки и полароиды','Текстурная бумага','Готовые композиции','Сезонные украшения','Сказочные объекты']
entries=[]
manifest=json.loads((root/'Resources/StudioAssets/manifest.json').read_text())
manifest=[x for x in manifest if not x['id'].startswith('Studio6_')]
for i in range(16):
    x,y=i%4,i//4
    tile=im.crop((round(x*im.width/4),round(y*im.height/4),round((x+1)*im.width/4),round((y+1)*im.height/4)))
    bbox=tile.getchannel('A').getbbox()
    assert bbox
    # Keep actual alpha, trim empty gutters without painting or reconstructing artwork.
    tile=tile.crop(bbox)
    key=f'Studio6_{i+1:02d}'
    folder=root/f'Resources/Assets.xcassets/Sticker_{key}.imageset';folder.mkdir(exist_ok=True)
    tile.save(folder/'art.png')
    (folder/'Contents.json').write_text(json.dumps({'images':[{'idiom':'universal','filename':'art.png'}],'info':{'author':'xcode','version':1}}))
    tile.save(root/f'Resources/StudioAssets/stickers/{key}.png')
    thumb=tile.copy();thumb.thumbnail((192,192),Image.Resampling.LANCZOS)
    thumb.save(root/f'Resources/StudioAssets/thumbnails/{key}.png')
    manifest.append({'id':key,'width':tile.width,'height':tile.height,'thumbnailWidth':thumb.width,'thumbnailHeight':thumb.height,'alpha':True})
    entries.append(f'        StickerEntry(id: "{key}", title: "{labels[i]}", category: "{categories[i]}")')
(root/'Resources/StudioAssets/manifest.json').write_text(json.dumps(manifest,ensure_ascii=False,indent=2))
p=root/'Sources/NotebookUI.swift';s=p.read_text()
s=s.replace('static let categories = ["Все", "Рамки"','static let categories = Studio6StickerCatalog.categories + ["Все", "Рамки"',1)
s=s.replace('static let all: [StickerEntry] = [','static let all: [StickerEntry] = Studio6StickerCatalog.all + [',1)
s+='\n\nenum Studio6StickerCatalog {\n    static let categories = '+json.dumps(list(dict.fromkeys(categories)),ensure_ascii=False)+'\n    static let all: [StickerEntry] = [\n'+',\n'.join(entries)+'\n    ]\n}\n'
p.write_text(s)
print('Imported 16 individually cropped alpha stickers')
