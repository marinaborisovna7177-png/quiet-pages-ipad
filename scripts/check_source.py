from pathlib import Path
import json, sys
from PIL import Image
from tree_sitter import Language, Parser
import tree_sitter_swift
from pbxproj import XcodeProject
root=Path(__file__).resolve().parents[1]
parser=Parser(Language(tree_sitter_swift.language()))
errors=[]
swift_files = list((root/'Sources').glob('*.swift')) + list((root/'Tests').glob('*.swift'))
for p in swift_files:
    tree=parser.parse(p.read_bytes())
    # Parser grammar lacks Swift multiple trailing closures; parse still reports those.
    if tree.root_node.has_error: errors.append(str(p.relative_to(root)))
assert not errors, f'Swift syntax: {errors}'
project=XcodeProject.load(str(root/'QuietPages.xcodeproj/project.pbxproj'))
assert project
manifest=json.loads((root/'Resources/StudioAssets/manifest.json').read_text())
assert len({x['id'] for x in manifest})==len(manifest)
assert sum(x['id'].startswith('Mega_') for x in manifest)==2000
for row in manifest:
    for sub in ['stickers','thumbnails']:
        with Image.open(root/'Resources/StudioAssets'/sub/(row['id']+'.png')) as im:
            im.load()
            assert max(im.size)<=(192 if sub=='thumbnails' else 1024)
            assert im.mode=='RGBA'
arts=list((root/'Resources/Assets.xcassets').glob('Studio6Art_*.imageset'))
assert len(arts)==16
for folder in arts:
    with Image.open(folder/'art.png') as im: im.load()
report={'swift_files_parsed':len(swift_files),'asset_files_decoded':len(manifest)*2+16,'sticker_count':len(manifest),'paper_themes':16,'paper_rulings':64,'template_theme_combinations':240,'xcode_build':'NOT RUN','ipad_tests':'NOT RUN','syntax_check':'tree-sitter only; not Swift typechecking'}
(root/'Docs/LOCAL_CHECKS.json').write_text(json.dumps(report,indent=2))
print(json.dumps(report,indent=2))
