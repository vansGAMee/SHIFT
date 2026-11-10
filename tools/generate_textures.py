from PIL import Image, ImageDraw
import numpy as np
from pathlib import Path
p=Path(__file__).resolve().parents[1]/'assets'/'textures'; p.mkdir(parents=True,exist_ok=True)
rng=np.random.default_rng(409)
def field(base,n=128,strength=8):
 a=np.zeros((n,n,3))+np.array(base)
 a+=rng.normal(0,strength,(n,n,1))
 coarse=rng.normal(0,strength,(n//8,n//8,1)).repeat(8,0).repeat(8,1)
 a+=coarse
 return np.uint8(np.clip(a,0,255))
def save(a,name): Image.fromarray(a,'RGB').save(p/(name+'.png'))
a=field((101,101,91),128,7)
for x in range(0,128,32): a[:,x:x+1]=a[:,x:x+1]*.64
for y in range(0,128,32): a[y:y+1]=a[y:y+1]*.63
for i in range(80):
 x,y=rng.integers(0,127,2); a[y:y+1,x:x+2]=np.maximum(a[y:y+1,x:x+2]-22,0)
save(a,'floor')
a=field((121,116,100),128,10)
for x in [0,63,127]: a[:,x:x+1]=a[:,x:x+1]*.55
for i in range(20):
 x=int(rng.integers(0,128)); y=int(rng.integers(0,95)); l=int(rng.integers(5,30)); a[y:y+l,x:x+1]=np.array([88,64,45])
save(a,'concrete')
a=field((60,72,58),128,5); a[:,0:2]=a[:,0:2]*.58; a[0:2]=a[0:2]*.8; save(a,'green')
a=field((73,74,68),128,6)
for y in range(0,128,32): a[y:y+2]=a[y:y+2]*.42
for x in range(0,128,32): a[:,x:x+2]=a[:,x:x+2]*.42
for x in [4,28,36,60,68,92,100,124]:
 for y in [4,28,36,60,68,92,100,124]: a[y:y+2,x:x+2]=(130,126,106)
save(a,'metal')
a=field((91,66,40),128,7)
for x in range(128):
 s=10*np.sin(x*.55)+8*np.sin(x*2.2); a[:,x]=np.uint8(np.clip(a[:,x].astype(float)+s,0,255))
for i in range(40):
 x,y=rng.integers(0,120,2); a[y:y+8,x:x+2]=a[y:y+8,x:x+2]*.55
save(a,'bark')
a=field((69,78,41),128,9)
for i in range(900):
 x,y=rng.integers(0,128,2); a[y,x]=[int(rng.integers(60,100)),int(rng.integers(70,102)),int(rng.integers(30,58))]
save(a,'grass_ground')
a=field((111,108,100),128,12)
for i in range(40):
 x,y=rng.integers(0,128,2); a[y:y+2,x:x+5]=a[y:y+2,x:x+5]*.65
save(a,'rock')
a=field((43,43,37),64,3)
for y in range(64):
 for x in range(64):
  if ((x+y)//12)%2==0: a[y,x]=[173+int(rng.integers(-12,13)),135+int(rng.integers(-8,9)),51+int(rng.integers(-6,7))]
save(a,'hazard')
im=Image.new('RGBA',(32,48)); d=ImageDraw.Draw(im)
for i in range(15):
 x=int(rng.integers(4,28)); tip=int(rng.integers(1,28)); col=(int(rng.integers(39,65)),int(rng.integers(67,99)),int(rng.integers(38,59)),255)
 d.polygon([(x-1,47),(x+1,47),(x+int(rng.integers(-7,8)),tip)],fill=col)
im.save(p/'grass_blades.png')
print('Generated pixel textures:', ', '.join(x.name for x in p.glob('*.png')))
# Chunky, dense silhouettes survive the game's 640px internal resolution.
im=Image.new('RGBA',(64,32)); d=ImageDraw.Draw(im)
for x in range(2,61,3):
 span=int((1-x/70)*12)+1
 for side in [-1,1]:
  col=(int(rng.integers(30,45)),int(rng.integers(49,72)),int(rng.integers(29,43)),255)
  d.polygon([(x-2,16),(x+3,16),(min(63,x+10),16+side*span),(x+4,16+side*(span-1))],fill=col)
d.line([(1,16),(61,16)],fill=(51,57,31,255),width=1)
im.save(p/'spruce_bough.png')
