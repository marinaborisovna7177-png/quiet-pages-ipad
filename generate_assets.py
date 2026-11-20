from PIL import Image, ImageDraw, ImageFilter
from pathlib import Path
import math, random, json
random.seed(811)
root=Path(__file__).parent/'Resources/Assets.xcassets'
S=512

def asset(name, image, family='Sticker'):
    p=root/(f'{family}_{name}.imageset');p.mkdir(parents=True,exist_ok=True)
    image.save(p/'art.png',optimize=True)
    (p/'Contents.json').write_text(json.dumps({'images':[{'filename':'art.png','idiom':'universal'}],'info':{'author':'xcode','version':1}},ensure_ascii=False))

def blend_fill(canvas, color, x, y, r):
    lay=Image.new('RGBA',canvas.size);d=ImageDraw.Draw(lay,'RGBA')
    for k in range(9,0,-1):
        rr=r*(0.45+k/12)
        d.ellipse((x-rr,y-rr,x+rr,y+rr),fill=(*color, max(1,int(5+(10-k)*1.8))))
    lay=lay.filter(ImageFilter.GaussianBlur(5))
    canvas.alpha_composite(lay)

def draw_sticker(name):
    im=Image.new('RGBA',(S,S));d=ImageDraw.Draw(im,'RGBA')
    def e(box,fill,outline=None,width=2):d.ellipse(box,fill=fill,outline=outline,width=width)
    def line(points,fill,width=5,joint='curve'):d.line(points,fill=fill,width=width,joint=joint)
    burg=(158,88,106,220);rose=(221,152,163,217);soft=(244,193,195,220);green=(111,139,112,225);gold=(190,151,89,225)
    # painted watercolor effect: irregular semi-transparent overlaid shapes and a few small stipples
    if name in ('Rosebud','Flower','Peony'):
        c=(260,252)
        stem=[(255,365),(258,340),(257,310),(252,284)]
        line(stem,(105,130,110,210),9)
        for side in [-1,1]:
            for yy in [327,355]:
                x=255+side*(28 if yy==327 else 40)
                e((x-34,yy-16,x+30,yy+10),(*green[:3],130));line([(255,yy+5),(x,yy)],green,4)
        if name=='Rosebud':
            for i in range(10):
                a=i*math.pi*2/10; rr=67 if i%2 else 44
                x=c[0]+math.cos(a)*rr;y=c[1]+math.sin(a)*rr*.8
                e((x-57,y-68,x+57,y+68),(*([rose,soft,burg][i%3][:3]),165))
            for i in range(4):
                a=i*math.pi/2
                x=c[0]+math.cos(a)*21; y=c[1]+math.sin(a)*18
                e((x-44,y-39,x+44,y+39),(*burg[:3],140))
            line([(244,251),(266,238),(284,254),(271,275),(251,281)],(*burg[:3],175),7)
        else:
            n=9 if name=='Flower' else 13
            for i in range(n):
                a=2*math.pi*i/n; r=62 if name=='Flower' else 71
                xx=c[0]+math.cos(a)*r;yy=c[1]+math.sin(a)*r
                e((xx-48,yy-56,xx+48,yy+56),(*([rose,soft,burg][i%3][:3]),145))
            e((219,207,291,279),(*gold[:3],215))
            for i in range(15):
                x=256+random.uniform(-30,30); y=244+random.uniform(-27,27)
                e((x-2,y-2,x+2,y+2),(113,77,53,115))
    elif name=='Butterfly':
        for side in [-1,1]:
            for iy,(ry,col) in enumerate([(185,(178,166,209,190)),(290,(212,162,187,195))]):
                pts=[(257,266),(257+side*65,ry-55),(257+side*151,ry-39),(257+side*177,ry+50),(257+side*70,ry+90)]
                d.polygon(pts,fill=col)
                d.line(pts+[pts[0]],fill=(126,102,131,155),width=4)
                e((257+side*70-20,ry+2,257+side*70+20,ry+42),(247,232,220,180))
        e((247,194,269,350),(80,69,76,240))
        line([(253,208),(221,160)],(80,69,76,220),4);line([(264,208),(292,159)],(80,69,76,220),4)
    elif name=='Bow':
        d.polygon([(250,260),(78,160),(76,309),(250,277)],fill=(221,166,171,220))
        d.polygon([(266,255),(434,163),(435,318),(260,281)],fill=(241,181,186,221))
        d.polygon([(250,287),(176,436),(251,414),(287,288)],fill=(205,139,152,190))
        d.polygon([(267,284),(354,430),(377,388),(282,275)],fill=(228,166,179,197))
        d.rounded_rectangle((222,224,299,310),radius=20,fill=(184,111,130,240))
        for x in [120,386]:line([(x,240),(242 if x==120 else 275,269)],(255,230,221,120),4)
    elif name=='Goldstar':
        for dx,dy,rr in [(-55,0,80),(101,-105,39),(-115,-111,26),(71,124,31)]:
            x,y=256+dx,256+dy
            pts=[]
            for i in range(10):
                a=i*math.pi/5 - math.pi/2;r=rr if i%2==0 else rr*0.27
                pts.append((x+r*math.cos(a),y+r*math.sin(a)))
            d.polygon(pts,fill=(203,163,102,225))
            d.line(pts+[pts[0]],fill=(153,115,79,120),width=3)
    elif name=='Waxseal':
        e((90,91,420,420),(129,64,80,215));e((103,99,405,405),(169,87,98,226))
        e((125,123,385,385),None,(229,169,161,130),10)
        line([(204,262),(247,299),(324,215)],(246,208,174,240),19)
    elif name=='Coffee':
        e((136,354,376,392),(124,101,99,70))
        d.rounded_rectangle((125,157,362,359),radius=35,fill=(240,221,205,237),outline=(163,127,118,140),width=6)
        e((327,196,437,322),None,(181,140,129,221),20)
        e((151,171,335,216),(130,94,80,224))
        e((180,177,305,203),(236,206,178,207))
        for x,y in [(195,119),(250,106),(300,127)]:
            line([(x,y),(x-13,y-18),(x+11,y-33)],(190,172,167,135),5)
    elif name=='Tea':
        e((132,348,381,383),(177,149,139,135))
        d.rounded_rectangle((136,189,356,343),radius=26,fill=(233,226,218,239),outline=(149,158,146,170),width=5)
        e((331,203,419,324),None,(144,166,156,210),16)
        e((160,195,331,222),(132,150,133,180))
        d.arc((180,128,302,214),190,325,fill=(177,172,158,130),width=6)
    elif name=='Book':
        d.polygon([(100,146),(245,170),(245,407),(96,385)],fill=(169,122,137,234))
        d.polygon([(245,170),(412,151),(405,378),(245,407)],fill=(226,193,192,239))
        d.polygon([(105,159),(240,183),(240,381),(103,361)],fill=(242,227,215,229))
        d.polygon([(251,184),(396,168),(394,358),(251,385)],fill=(248,240,225,228))
        line([(245,174),(245,397)],(118,90,99,159),5)
        for y in [218,242,266,290]:
            line([(124,y),(218,y+10)],(151,126,124,96),3)
            line([(276,y+8),(375,y-2)],(151,126,124,96),3)
    elif name=='Ticket':
        d.rounded_rectangle((77,164,436,347),radius=18,fill=(230,203,172,226),outline=(175,146,120,170),width=5)
        for y in range(165,360,20):e((289,y,299,y+7),(172,127,107,135))
        line([(122,211),(245,211)],(122,104,100,155),7)
        line([(122,241),(221,241)],(122,104,100,115),5)
        for y in [286,309]:line([(122,y),(247,y)],(122,104,100,90),4)
        e((329,208,387,266),(196,150,143,190))
    elif name=='Lace':
        for i in range(11):
            x=80+35*i
            e((x,240,x+75,330),None,(238,228,211,240),7)
            e((x+12,254,x+61,312),None,(204,188,177,145),3)
        d.rectangle((84,227,464,263),fill=(241,231,217,180))
    elif name=='Moon':
        e((157,130,396,382),(196,167,109,227))
        e((221,97,429,339),(0,0,0,0))
        # erase overlapping arc to leave crescent
        hole=Image.new('L',(S,S));hd=ImageDraw.Draw(hole);hd.ellipse((223,97,437,326),fill=255)
        alpha=im.getchannel('A'); import PIL.ImageChops
        alpha=PIL.ImageChops.subtract(alpha,hole);im.putalpha(alpha)
        d=ImageDraw.Draw(im,'RGBA')
        for x,y,r in [(178,110,19),(405,235,17),(355,102,12)]:
            pts=[]
            for i in range(8):
                a=math.pi*i/4;r2=r if i%2==0 else r*.23
                pts.append((x+r2*math.cos(a),y+r2*math.sin(a)))
            d.polygon(pts,fill=(191,153,102,233))
    elif name=='Heart':
        pts=[(258,407)]
        for a in range(0,361,5):
            t=a*math.pi/180
            x=256+9.5*(16*math.sin(t)**3)
            y=263-9.5*(13*math.cos(t)-5*math.cos(2*t)-2*math.cos(3*t)-math.cos(4*t))
            pts.append((x,y))
        d.polygon(pts,fill=(216,155,172,221))
        line([(208,212),(237,195)],(255,235,228,140),12)
    elif name=='Leaf':
        line([(195,430),(220,361),(253,292),(291,204),(316,115)],(106,130,107,214),8)
        for i in range(5):
            x=205+i*25;y=373-i*57
            e((x-84,y-47,x+5,y+13),(114,147,127,175))
            e((x+0,y-48,x+75,y+16),(137,164,141,169))
    elif name=='Envelope':
        d.rounded_rectangle((82,149,431,378),radius=17,fill=(245,225,203,236),outline=(167,142,132,145),width=4)
        d.polygon([(91,157),(260,298),(425,157)],fill=(223,189,177,175))
        line([(91,366),(222,264)],(179,146,138,160),4)
        line([(425,366),(296,264)],(179,146,138,160),4)
        e((224,249,289,314),(165,82,96,228))
    elif name=='Washi':
        d.polygon([(82,207),(435,152),(460,284),(106,343)],fill=(226,181,190,182))
        for i in range(0,350,25):
            line([(109+i,212-i*.15),(132+i,329-i*.15)],(255,244,236,100),4)
    elif name=='Polaroid':
        d.rounded_rectangle((98,77,411,432),radius=8,fill=(250,244,229,252),outline=(189,176,155,190),width=4)
        d.rectangle((123,105,386,342),fill=(179,192,181,235))
        d.polygon([(123,299),(213,207),(275,280),(332,190),(386,255),(386,342),(123,342)],fill=(99,142,121,218))
        e((274,143,319,188),(245,219,165,220))
        line([(199,397),(316,397)],(166,144,140,120),3)
    # Add subtle grain only on opaque portions to simulate paper/paint texture
    pix=im.load()
    for _ in range(9000):
        x=random.randrange(S);y=random.randrange(S)
        col=pix[x,y]
        if col[3]>35:
            n=random.randint(-16,15)
            pix[x,y]=(max(0,min(255,col[0]+n)),max(0,min(255,col[1]+n)),max(0,min(255,col[2]+n)),col[3])
    # Soft edge shading behind stickers
    shadow=Image.new('RGBA',im.size)
    shadow.putalpha(im.getchannel('A').filter(ImageFilter.GaussianBlur(9)).point(lambda a:int(a*.17)))
    comp=Image.alpha_composite(shadow,im)
    return comp.resize((256,256),Image.Resampling.LANCZOS)

names=['Rosebud','Flower','Peony','Butterfly','Bow','Goldstar','Waxseal','Coffee','Tea','Book','Ticket','Lace','Moon','Heart','Leaf','Envelope','Washi','Polaroid']
for name in names: asset(name,draw_sticker(name))

covers={
 'Rose': ((234,215,215),(184,126,147),'Flower'),
 'Sage': ((210,222,208),(96,133,119),'Leaf'),
 'Lavender': ((224,215,232),(148,129,175),'Butterfly'),
 'Night': ((55,61,80),(191,158,141),'Goldstar'),
 'Cream': ((244,227,206),(192,147,131),'Rosebud'),
 'Blue': ((210,220,232),(115,139,168),'Moon')
}
for name,(bg,accent,sticker) in covers.items():
    import numpy as np
    W,H=720,924
    yy,xx=np.mgrid[0:H,0:W]
    radial=np.sqrt(((xx-W*.45)/(W*.8))**2+((yy-H*.48)/(H*.9))**2)
    noise=np.random.default_rng(sum(map(ord,name))).normal(0,1.6,(H,W))
    arr=np.zeros((H,W,3),dtype='uint8')
    for c in range(3):
        v=bg[c]+(15 if name!='Night' else 6)*(1-radial)+noise
        arr[:,:,c]=np.uint8(np.clip(v,0,255))
    image=Image.fromarray(arr,'RGB').convert('RGBA')
    cloud=Image.new('RGBA',(W,H),(0,0,0,0))
    cd=ImageDraw.Draw(cloud,'RGBA')
    rng=random.Random(sum(map(ord,name)))
    for _ in range(16):
        x=rng.randint(0,W);y=rng.randint(0,H);r=rng.randint(70,180)
        cd.ellipse((x-r,y-r,x+r,y+r),fill=(*accent,rng.randint(6,16)))
    image.alpha_composite(cloud.filter(ImageFilter.GaussianBlur(45)))
    deco=Image.open(root/(f'Sticker_{sticker}.imageset')/'art.png').convert('RGBA')
    deco=deco.resize((250,250),Image.Resampling.LANCZOS)
    deco.putalpha(deco.getchannel('A').point(lambda a:int(a*.72)))
    image.alpha_composite(deco,(-26,-25))
    image.alpha_composite(deco,(W-210,H-217))
    ornamental=Image.new('RGBA',(W,H),(0,0,0,0));d=ImageDraw.Draw(ornamental,'RGBA')
    col=(242,223,210,105) if name=='Night' else (*accent,90)
    d.rounded_rectangle((31,31,W-31,H-31),radius=19,outline=col,width=3)
    d.rounded_rectangle((46,46,W-46,H-46),radius=14,outline=(*accent,40),width=1)
    for cy in [91,H-91]:
        d.line((W/2-52,cy,W/2+52,cy),fill=col,width=2)
        for delta in (-69,69): d.ellipse((W/2+delta-3,cy-3,W/2+delta+3,cy+3),fill=col)
    image.alpha_composite(ornamental)
    asset(name,image.convert('RGB'),'Cover')

# App icon, no embedded text
icon=Image.new('RGB',(1024,1024),(230,201,205));d=ImageDraw.Draw(icon)
for k in range(20):
    c=(232-min(k*2,35),198-min(k,15),207-min(k,20))
    d.rounded_rectangle((95+k*2,100+k*2,929-k*2,925-k*2),radius=110,outline=c,width=3)
d.rounded_rectangle((214,194,810,834),radius=52,fill=(250,240,226),outline=(166,119,136),width=10)
d.rounded_rectangle((240,217,780,808),radius=40,outline=(213,177,176),width=6)
for k in range(5):d.ellipse((193,292+k*90,236,330+k*90),fill=(173,133,151))
# hand painted pen nib
p=[(504,382),(532,451),(494,515),(469,454)]
d.polygon(p,fill=(171,122,146));d.line((482,455,512,475),fill=(250,237,215),width=8)
d.arc((388,320,620,560),start=20,end=170,fill=(179,130,149),width=17)
icon.save(root/'AppIconLarge.png')

# classic multi-size icon images for iPad compatibility
appicon=root/'AppIcon.appiconset';appicon.mkdir(exist_ok=True)
sizes=[('ipad','20x20','1x',20),('ipad','20x20','2x',40),('ipad','29x29','1x',29),('ipad','29x29','2x',58),('ipad','40x40','1x',40),('ipad','40x40','2x',80),('ipad','76x76','1x',76),('ipad','76x76','2x',152),('ipad','83.5x83.5','2x',167),('iphone','20x20','2x',40),('iphone','20x20','3x',60),('iphone','29x29','2x',58),('iphone','29x29','3x',87),('iphone','40x40','2x',80),('iphone','40x40','3x',120),('iphone','60x60','2x',120),('iphone','60x60','3x',180),('ios-marketing','1024x1024','1x',1024)]
imgs=[]
for idx,(idiom,size,scale,px) in enumerate(sizes):
    fn=f'Icon-{idiom}-{size.replace(".","-")}-{scale}.png'
    icon.resize((px,px),Image.Resampling.LANCZOS).save(appicon/fn)
    imgs.append({'filename':fn,'idiom':idiom,'size':size,'scale':scale})
(appicon/'Contents.json').write_text(json.dumps({'images':imgs,'info':{'version':1,'author':'xcode'}},ensure_ascii=False))
print('assets generated',len(list(root.rglob('art.png'))))
