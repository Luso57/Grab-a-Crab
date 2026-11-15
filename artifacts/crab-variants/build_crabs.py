"""Build textured variants from the live base crab. Run inside Blender.

The original objects are read only. Each export uses one image atlas and one
material per mesh, with both embedded FBX media and a separate PNG.
"""
import bpy
import bmesh
import numpy as np
import math
import json
import zlib
import struct
import hashlib
from pathlib import Path
from mathutils import Vector

ROOT = Path(r"C:\Grab a Crab")
OUT = ROOT / "Crabmodels"
WORK = ROOT / "artifacts" / "crab-variants"
NAMES = ["Lava", "Crystal", "Galaxy", "Treasure", "Thunder", "Clockwork",
         "Bubble", "Prism", "Mushroom", "Honeycomb", "Disco", "Knight",
         "Robot", "Cloud", "Cactus", "Cupcake", "Arcade", "Storm"]

# body, limbs, pincer interior, spots, detail A/B, highlight, shade
PALETTES = {
 "Lava": ["302833","43303c","ff9b27","ffbc42","ff6125","f3c55c","ffe5a3","201d2a"],
 "Crystal": ["9162c7","7652ad","dbb4ff","d9c1ff","a87fe8","6959b6","edddff","50357f"],
 "Galaxy": ["20244f","393065","a38bf2","b6d6ff","87d8f7","df96ed","e7f5ff","14172f"],
 "Treasure": ["bf8a37","d7a748","f7db82","65d6be","ffd77d","9b5a2e","fff0b0","68402f"],
 "Thunder": ["2852a1","356dc7","9ef3ff","b9f8ff","ffe574","60def3","edfaff","17336d"],
 "Clockwork": ["765044","9f7150","d6af6c","d7b67a","dfbd78","a76a43","f8e1af","493a37"],
 "Bubble": ["69c9d8","62b8d3","c2f4f4","d5fcff","b0edf4","77bbdf","efffff","37849f"],
 "Prism": ["c0b4ed","a294dc","dff7ff","f6d4ee","ffb7d8","9be5e2","fff0fc","7d75ae"],
 "Mushroom": ["d9564b","ca604f","f6d9a8","fff0cf","e86759","e8d1a1","fff5dc","8e3e3d"],
 "Honeycomb": ["e9aa40","ca872d","ffdf80","ffe7a0","ffd364","bc7725","fff0bb","9b591f"],
 "Disco": ["5c4a8e","7562a6","e1bcff","c9e6ff","89d7f2","de9edc","f0f7ff","302841"],
 "Knight": ["718398","8296aa","d2dfeb","d5b774","bccbda","e5c782","eff5fa","414e69"],
 "Robot": ["778c98","647c8b","afe9e8","7ee8d6","b3c9d1","66dfce","e7f8f8","35495b"],
 "Cloud": ["92c8ec","a6d7f1","eefaff","ffffff","f6fcff","d5e9f5","ffffff","668dbb"],
 "Cactus": ["68a365","588a58","bbce88","d8dfab","e7d7a3","e78ab4","edf0c4","376345"],
 "Cupcake": ["ee9fc1","d98bb6","ffe3e3","fff0ce","ffe5e6","cba0e3","fff7ec","b86c9b"],
 "Arcade": ["303655","434365","ef9cca","7ee9e3","72e5df","f79fc8","eefaff","1c2338"],
 "Storm": ["4d627f","5a7595","a3d9f4","b9def6","ffe49a","8399b0","e2eff9","2c3c59"],
}
EXTRA = ["101725","ffffff","ff8fba","68e1ee","ffe777","9be4a2","bc9bf5","ff9670"]
DESCRIPTIONS = {
 "Lava":"Charcoal shell, molten fissures, and small obsidian spires.",
 "Crystal":"Lavender facets with a cluster of amethyst crystals.",
 "Galaxy":"Indigo nebula, star field, and a small orbital star ornament.",
 "Treasure":"Engraved gold, inset jewels, and a little stack of coins.",
 "Thunder":"Cobalt shell, electric cyan markings, and a golden lightning crest.",
 "Clockwork":"Warm brass and copper with three meshing shell gears.",
 "Bubble":"Aqua rings and glossy illustrated bubble ornaments.",
 "Prism":"Pastel rainbow facets with small multicolored prisms.",
 "Mushroom":"Toadstool red and cream with miniature mushroom sprouts.",
 "Honeycomb":"Amber hexagons, wax cells, and rounded honey droplets.",
 "Disco":"Colored mirror tiles and a faceted disco ball.",
 "Knight":"Blue steel armor accents, rivets, and a gold trimmed shield.",
 "Robot":"Steel panels, teal circuits, and two small antennae.",
 "Cloud":"Sky blue shell and soft white cloud puffs.",
 "Cactus":"Green ribs, tiny cream spines, and a pink cactus blossom.",
 "Cupcake":"Pink frosting, cream dollops, colorful sprinkles, and a cherry.",
 "Arcade":"Neon pixel maze, game controls, and a little joystick.",
 "Storm":"Rain streaks, dark cloud puffs, and a small lightning accent.",
}

def rgb(hexcode):
    return np.array([int(hexcode[i:i+2], 16)/255 for i in (0,2,4)], dtype=np.float32)

def png_write(path, arr):
    # Arrays use bottom-left origin, matching Blender's UV space.
    a = np.uint8(np.clip(arr[::-1],0,1)*255+.5)
    raw = b"".join(b"\0" + row.tobytes() for row in a)
    def chunk(kind, payload):
        return struct.pack(">I",len(payload))+kind+payload+struct.pack(">I",zlib.crc32(kind+payload)&0xffffffff)
    path.write_bytes(b"\x89PNG\r\n\x1a\n"+chunk(b"IHDR",struct.pack(">IIBBBBB",a.shape[1],a.shape[0],8,2,0,0,0))+chunk(b"IDAT",zlib.compress(raw,8))+chunk(b"IEND",b""))

class Painter:
    def __init__(self, color):
        self.x,self.y=np.meshgrid(np.linspace(0,1,1024,dtype=np.float32),np.linspace(0,1,768,dtype=np.float32))
        self.a=np.empty((768,1024,3),np.float32)
        self.a[:]=color
    def paint(self,mask,col,alpha=1):
        m=np.clip(mask*alpha,0,1)[...,None]
        self.a=self.a*(1-m)+np.asarray(col)*m
    def disc(self,x,y,r,col,alpha=1):
        d=np.sqrt((self.x-x)**2+(self.y-y)**2)
        self.paint(np.clip((r-d)*900,0,1),col,alpha)
    def ring(self,x,y,r,w,col):
        d=np.abs(np.sqrt((self.x-x)**2+(self.y-y)**2)-r)
        self.paint(np.clip((w-d)*900,0,1),col)
    def line(self,a,b,w,col,alpha=1):
        dx,dy=b[0]-a[0],b[1]-a[1]
        t=np.clip(((self.x-a[0])*dx+(self.y-a[1])*dy)/(dx*dx+dy*dy+1e-9),0,1)
        d=np.sqrt((self.x-a[0]-t*dx)**2+(self.y-a[1]-t*dy)**2)
        self.paint(np.clip((w-d)*900,0,1),col,alpha)
    def poly(self,points,col):
        inside=np.zeros(self.x.shape,bool)
        for a,b in zip(points,points[1:]+points[:1]):
            crossing=((a[1]>self.y)!=(b[1]>self.y)) & (self.x < (b[0]-a[0])*(self.y-a[1])/(b[1]-a[1]+1e-12)+a[0])
            inside ^= crossing
        self.paint(inside,col)
    def cloud(self,x,y,r,col):
        for dx,dy,s in [(-.6,0,.65),(0,.25,.9),(.65,0,.65),(0,-.22,.75)]:
            self.disc(x+dx*r,y+dy*r,r*s,col)

def texture(name):
    pal=[rgb(h) for h in PALETTES[name]+EXTRA]
    if name=="Cupcake":pal[15]=rgb("da3f62")
    p=Painter(pal[0]); x,y=p.x,p.y
    p.a*= (.95+.08*y)[...,None]
    rng=np.random.default_rng(NAMES.index(name)+712)
    if name=="Lava":
        paths=[[(.08,0),(.22,.2),(.16,.38),(.35,.5),(.28,.72),(.4,1)],[(.35,.5),(.65,.56),(.76,.38),(1,.31)],[(.28,.72),(.08,.83),(0,.79)],[(.65,.56),(.58,.81),(.76,1)],[(.22,.2),(.48,.13),(.61,0)],[(.58,.81),(.9,.77),(1,.89)]]
        for path in paths:
            for a,b in zip(path,path[1:]):
                p.line(a,b,.026,pal[4],.35);p.line(a,b,.012,pal[4]);p.line(a,b,.0045,pal[2])
        for _ in range(35):
            p.disc(*rng.random(2),rng.uniform(.001,.004),pal[3],.7)
    elif name in ("Crystal","Prism"):
        cols=[pal[0],pal[1],pal[2],pal[3],pal[4],pal[5],pal[6]] if name=="Crystal" else [pal[i] for i in [2,3,4,5,10,11,12,13,14]]
        grid=5
        for j in range(grid):
            for i in range(grid):
                a=(i/grid,j/grid);b=((i+1)/grid,j/grid);c=((i+1)/grid,(j+1)/grid);d=(i/grid,(j+1)/grid)
                p.poly([a,b,c],cols[(i+2*j)%len(cols)])
                p.poly([a,c,d],cols[(i+2*j+2)%len(cols)])
                p.line(a,c,.0015,pal[6],.45)
    elif name=="Galaxy":
        haze=np.exp(-((y-(.3+.32*np.sin(x*3.6)))**2)/.025)
        p.paint(haze,pal[14],.4)
        p.paint(np.exp(-((y-(.2+.3*x))**2)/.008),pal[11],.18)
        for i in range(95):
            u,v=rng.random(2);r=rng.uniform(.001,.0035)
            p.disc(u,v,r,pal[6])
            if i%12==0:
                p.line((u-.009,v),(u+.009,v),.0015,pal[6]);p.line((u,v-.012),(u,v+.012),.0015,pal[6])
    elif name=="Treasure":
        for inset in [.04,.065]:
            for a,b in [((inset,inset),(1-inset,inset)),((1-inset,inset),(1-inset,1-inset)),((1-inset,1-inset),(inset,1-inset)),((inset,1-inset),(inset,inset))]:p.line(a,b,.005,pal[6])
        for u in np.arange(.15,1,.23):
            for v in np.arange(.12,1,.23):p.poly([(u,v-.025),(u+.025,v),(u,v+.025),(u-.025,v)],pal[5])
    elif name=="Thunder":
        for shift in [-.23,.12,.43]:
            pts=[(.2+shift,0),(.43+shift,.35),(.28+shift,.35),(.57+shift,.73),(.43+shift,.73),(.7+shift,1)]
            for a,b in zip(pts,pts[1:]):p.line(a,b,.025,pal[5],.25);p.line(a,b,.009,pal[2])
    elif name=="Clockwork":
        for u,v,r in [(.28,.52,.23),(.68,.69,.18),(.64,.24,.13)]:
            p.ring(u,v,r,.009,pal[4]);p.ring(u,v,r*.72,.003,pal[3])
            for t in np.linspace(0,math.tau,16,endpoint=False):
                p.line((u+math.cos(t)*r*.8,v+math.sin(t)*r*.8),(u+math.cos(t)*r*.95,v+math.sin(t)*r*.95),.004,pal[5])
        for u,v in [(.07,.09),(.93,.09),(.07,.92),(.93,.92)]:p.disc(u,v,.018,pal[6]);p.line((u-.01,v),(u+.01,v),.003,pal[7])
    elif name=="Bubble":
        for _ in range(21):
            u,v=rng.uniform(.03,.97,2);r=rng.uniform(.025,.09)
            p.ring(u,v,r,.004,pal[6]);p.disc(u-r*.35,v+r*.45,r*.15,pal[9])
    elif name=="Mushroom":
        for u,v,r in [(.1,.2,.04),(.35,.15,.055),(.78,.21,.06),(.15,.63,.06),(.5,.6,.07),(.88,.75,.05),(.55,.93,.04)]:p.disc(u,v,r,pal[3])
    elif name=="Honeycomb":
        r=.087
        for j in range(-1,9):
            for i in range(-1,9):
                u=i*r*1.73+(j%2)*r*.865;v=j*r*1.5
                pts=[(u+math.cos(math.pi/6+k*math.tau/6)*r*.93,v+math.sin(math.pi/6+k*math.tau/6)*r*.93) for k in range(6)]
                p.poly(pts,pal[5] if (i+j)%3==0 else pal[1])
                for a,b in zip(pts,pts[1:]+pts[:1]):p.line(a,b,.004,pal[4])
    elif name=="Disco":
        for j in range(10):
            for i in range(12):
                col=pal[[4,5,6,11,14,10][(i+3*j)%6]]
                u,v=i/12,j/10
                p.poly([(u+.006,v+.007),(u+1/12-.006,v+.007),(u+1/12-.006,v+.1-.007),(u+.006,v+.1-.007)],col*(.72+.25*rng.random()))
                p.line((u+.01,v+.085),(u+.065,v+.085),.002,pal[6],.7)
    elif name=="Knight":
        p.poly([(.18,0),(.82,0),(.74,1),(.26,1)],pal[7])
        for u in [.18,.82]:p.line((u,0),(.5+(u-.5)*.75,1),.008,pal[5])
        for v in [.16,.84]:p.line((0,v),(1,v),.008,pal[4])
    elif name=="Robot":
        for u in [.1,.9]:p.line((u,0),(u,1),.006,pal[7])
        for u,v in [(0.2,.1),(.8,.15),(.3,.8),(.72,.75)]:
            path=[(u,v),(u,v+.12),(u+.1,v+.12),(u+.1,v+.25)]
            for a,b in zip(path,path[1:]):p.line(a,b,.006,pal[5])
            p.ring(u,v,.012,.004,pal[6])
        for u in [.43,.48,.53,.58]:p.line((u,.35),(u,.6),.008,pal[7])
    elif name=="Cloud":
        for u,v,r in [(.12,.25,.09),(.6,.23,.12),(.3,.65,.1),(.84,.65,.09),(.6,.92,.06)]:p.cloud(u,v,r,pal[6])
    elif name=="Cactus":
        for u in np.arange(.05,1,.13):
            p.line((u,0),(u,1),.015,pal[7],.5);p.line((u+.025,0),(u+.025,1),.007,pal[2],.55)
            for v in np.arange(.13,1,.23):
                p.line((u-.015,v+.018),(u,v),.002,pal[4]);p.line((u+.015,v+.018),(u,v),.002,pal[4])
    elif name=="Cupcake":
        for u in np.arange(-.05,1.1,.15):p.disc(u,.03,.115,pal[4])
        for i in range(65):
            u,v=rng.uniform(.05,.95,2);a=rng.random()*math.tau
            p.line((u,v),(u+math.cos(a)*.018,v+math.sin(a)*.018),.004,pal[10+i%6])
    elif name=="Arcade":
        step=.055
        for j in range(3,16,3):
            for i in range(2,17,4):
                u,v=i*step,j*step
                p.line((u,v),(u+step*2,v),.006,pal[4]);p.line((u+step*2,v),(u+step*2,v+step),.006,pal[4])
        for j in range(1,18,2):
            for i in range(1,18,2):p.poly([(i*step-.006,j*step-.006),(i*step+.006,j*step-.006),(i*step+.006,j*step+.006),(i*step-.006,j*step+.006)],pal[12])
    elif name=="Storm":
        for i in range(55):
            u,v=rng.random(2);p.line((u,v),(u-.015,v-.04),.002,pal[2],.7)
        for u,v,r in [(.18,.78,.12),(.52,.9,.14),(.85,.75,.11)]:p.cloud(u,v,r,pal[7])
        for a,b in zip([(.7,.65),(.6,.45),(.72,.45)],[ (.6,.45),(.72,.45),(.58,.22)]):p.line(a,b,.008,pal[4])
    atlas=np.zeros((1024,1024,3),np.float32)
    atlas[256:]=p.a
    for i,col in enumerate(pal):
        colx=i%8;coly=i//8
        atlas[coly*64:(coly+1)*64,colx*128:(colx+1)*128]=col
    sx=np.linspace(0,1,1024)[None,:,None];sy=np.linspace(0,1,128)[:,None,None]
    atlas[128:256]=np.array(pal[0])[None,None,:]*(.9+.1*sy)
    if name in ("Cupcake","Cactus"):
        stripe=(np.floor(sx*20)%2)*.25
        atlas[128:256]=pal[0]*(1-stripe)+pal[2]*stripe
    elif name in ("Knight","Robot","Clockwork","Treasure"):
        atlas[144:151]=pal[5];atlas[233:240]=pal[5]
    elif name in ("Thunder","Arcade"):
        atlas[155:162]=pal[4];atlas[220:227]=pal[4]
    path=OUT/(name+"Crab_Color.png")
    png_write(path,atlas)
    return pal,path

class Geo:
    def __init__(self):self.v=[];self.f=[];self.c=[];self.s=[]
    def add(self,verts,faces,col,smooth=False):
        k=len(self.v);self.v.extend([tuple(v) for v in verts]);self.f.extend([tuple(k+i for i in f) for f in faces])
        self.c.extend(col if isinstance(col,list) else [col]*len(faces));self.s.extend([smooth]*len(faces))
    def box(self,c,size,col):
        x,y,z=c;a,b,d=[s*.5 for s in size]
        v=[(x+i*a,y+j*b,z+k*d) for k in [-1,1] for j in [-1,1] for i in [-1,1]]
        self.add(v,[(0,2,3,1),(4,5,7,6),(0,1,5,4),(2,6,7,3),(0,4,6,2),(1,3,7,5)],col)
    def cylinder(self,a,b,r1,r2,col,n=16):
        a,b=Vector(a),Vector(b);axis=(b-a).normalized();u=axis.cross(Vector((0,1,0)))
        if u.length<.01:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u).normalized()
        verts=[a+r1*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v) for i in range(n)]
        faces=[tuple(reversed(range(n)))]
        if r2==0:
            verts.append(b)
            faces.extend([(i,(i+1)%n,n) for i in range(n)])
        else:
            verts.extend([b+r2*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v) for i in range(n)])
            faces.append(tuple(range(n,2*n)))
            faces.extend([(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)])
        self.add(verts,faces,col)
    def sphere(self,c,scale,col,n=16,rings=8,smooth=True,facets=False):
        c=Vector(c);sc=Vector(scale)
        vs=[c+Vector((0,0,sc.z))]
        for j in range(1,rings):
            t=math.pi*j/rings
            for i in range(n):
                a=i*math.tau/n;vs.append(c+Vector((sc.x*math.sin(t)*math.cos(a),sc.y*math.sin(t)*math.sin(a),sc.z*math.cos(t))))
        vs.append(c-Vector((0,0,sc.z)));bot=len(vs)-1
        fs=[(0,1+i,1+(i+1)%n) for i in range(n)]
        for j in range(rings-2):
            for i in range(n):
                k=1+j*n+i;kn=1+j*n+(i+1)%n;fs.append((k,k+n,kn+n,kn))
        fs.extend([(bot,1+(rings-2)*n+(i+1)%n,1+(rings-2)*n+i) for i in range(n)])
        cols=([4,5,6,10,11,14]*((len(fs)+5)//6))[:len(fs)] if facets else col
        self.add(vs,fs,cols,smooth)
    def poly(self,pts,c,depth,col,axis="z"):
        def point(u,v,w):return (u+c[0],v+c[1],w+c[2]) if axis=="z" else (u+c[0],w+c[1],v+c[2])
        n=len(pts);vs=[point(u,v,w) for w in [-depth/2,depth/2] for u,v in pts]
        fs=[tuple(reversed(range(n))),tuple(range(n,2*n))]+[(i,(i+1)%n,(i+1)%n+n,i+n) for i in range(n)]
        self.add(vs,fs,col)
    def torus(self,c,major,minor,col,n=32,m=6,scale=(1,1,1)):
        vs=[];fs=[]
        for i in range(n):
            a=i*math.tau/n
            for j in range(m):
                b=j*math.tau/m
                vs.append((c[0]+scale[0]*(major+minor*math.cos(b))*math.cos(a),c[1]+scale[1]*(major+minor*math.cos(b))*math.sin(a),c[2]+scale[2]*minor*math.sin(b)))
        for i in range(n):
            for j in range(m):fs.append((i*m+j,((i+1)%n)*m+j,((i+1)%n)*m+(j+1)%m,i*m+(j+1)%m))
        self.add(vs,fs,col,True)
    def gear(self,c,r,teeth,col):
        n=teeth*4;vs=[]
        for z in [-.025,.025]:
            for inner in [False,True]:
                for i in range(n):
                    rad=r*.33 if inner else r*(1 if i%4 in (1,2) else .82)
                    vs.append((c[0]+rad*math.cos(i*math.tau/n),c[1]+rad*math.sin(i*math.tau/n),c[2]+z))
        fs=[]
        for i in range(n):
            j=(i+1)%n
            fs.extend([(i,j,n+j,n+i),(2*n+i,3*n+i,3*n+j,2*n+j),(i,2*n+i,2*n+j,j),(n+i,n+j,3*n+j,3*n+i)])
        self.add(vs,fs,col)
        self.cylinder((c[0],c[1],c[2]-.03),(c[0],c[1],c[2]+.055),r*.18,r*.18,7,n=16)

def star(r):return [(math.sin(i*math.pi/5)*(r if i%2==0 else r*.45),math.cos(i*math.pi/5)*(r if i%2==0 else r*.45)) for i in range(10)]
def bolt(s=1):return [(x*s,y*s) for x,y in [(-.05,.62),(.15,.62),(.02,.36),(.17,.36),(-.16,0),(-.05,.27),(-.19,.27)]]

def details(name):
    g={role:Geo() for role in ["Body","Claw_L","Claw_R"]};b=g["Body"]
    if name=="Lava":
        for x,y,h in [(-.8,1.1,.25),(-.4,1.3,.32),(0,1.3,.42),(.4,1.3,.32),(.8,1.1,.25)]:
            b.cylinder((x,y,1.25),(x,y,1.28),.115,.105,4,n=7);b.cylinder((x,y,1.28),(x,y,1.28+h),.09,0,7,n=5)
    elif name=="Crystal":
        for x,y,h,r in [(-.26,.95,.52,.13),(.07,1.03,.7,.14),(.35,.93,.4,.11)]:
            b.cylinder((x,y,1.24),(x,y,1.24+h*.7),r,r,4,n=6);b.cylinder((x,y,1.24+h*.7),(x,y,1.24+h),r,0,6,n=6)
        for side in [-1,1]:g["Claw_L" if side<0 else "Claw_R"].cylinder((side*1.35,-.69,1.0),(side*1.38,-.69,1.2),.09,0,4,n=6)
    elif name=="Galaxy":
        b.torus((0,.87,1.29),.37,.018,4,scale=(1.2,.7,1))
        b.poly(star(.18),(0,.87,1.38),.07,6)
        for x,y in [(-.45,.7),(.4,1.1)]:b.sphere((x,y,1.3),(.045,.045,.045),5,n=10,rings=6)
    elif name=="Treasure":
        for x,y,col in [(-.48,.42,13),(.4,.77,10),(-.1,1.1,11)]:
            b.cylinder((x,y,1.25),(x,y,1.3),.18,.18,4,n=8);b.sphere((x,y,1.33),(.14,.14,.12),col,n=8,rings=4,smooth=False)
        for j in range(3):b.cylinder((.65,1.16,1.25+j*.04),(.65,1.16,1.28+j*.04),.14,.14,4,n=20)
    elif name=="Thunder":
        b.poly(bolt(),(0,1.0,1.25),.075,4,axis="y")
    elif name=="Clockwork":
        for x,y,r,t,c in [(-.45,.72,.31,12,4),(.16,.9,.25,10,5),(.48,.47,.19,9,4)]:b.gear((x,y,1.3),r,t,c)
        for x,y in [(-.92,-.12),(.92,-.12),(-.92,1.2),(.92,1.2)]:b.sphere((x,y,1.26),(.045,.045,.025),6,n=10,rings=6)
    elif name=="Bubble":
        for x,y,r in [(-.35,.9,.21),(.15,1.04,.28),(.55,.76,.14)]:
            b.sphere((x,y,1.25+r*.8),(r,r,r),4,n=20,rings=12)
            b.sphere((x-r*.3,y-r*.7,1.25+r*1.4),(r*.18,r*.05,r*.2),9,n=12,rings=8)
            b.torus((x,y,1.25+r*.15),r*.55,.014,6,n=24)
    elif name=="Prism":
        for x,y,r,h,c in [(-.7,.9,.18,.32,10),(-.25,1.18,.16,.38,11),(.25,1.18,.16,.38,12),(.7,.9,.18,.32,14)]:
            b.cylinder((x,y,1.24),(x,y,1.24+h),r,0,c,n=4)
    elif name=="Mushroom":
        for x,y,r,h in [(-.44,.98,.25,.2),(.13,1.02,.32,.3),(.54,.81,.18,.13)]:
            b.cylinder((x,y,1.24),(x,y,1.25+h),r*.28,r*.25,3,n=12)
            b.sphere((x,y,1.25+h),(r,r,r*.48),4,n=20,rings=10)
            for a in [0,2.1,4.2]:b.sphere((x+math.cos(a)*r*.44,y+math.sin(a)*r*.44,1.25+h+r*.43),(r*.16,r*.16,.015),3,n=10,rings=6)
    elif name=="Honeycomb":
        for x,y in [(-.43,.82),(0,.82),(.43,.82),(-.22,1.18),(.22,1.18)]:
            b.cylinder((x,y,1.25),(x,y,1.32),.22,.22,4,n=6);b.cylinder((x,y,1.32),(x,y,1.335),.17,.17,5,n=6)
        for x,y in [(-.9,.15),(.88,.36)]:b.sphere((x,y,1.24),(.08,.09,.12),4,n=12,rings=8)
    elif name=="Disco":
        b.cylinder((0,.95,1.24),(0,.95,1.39),.055,.055,5,n=12)
        b.sphere((0,.95,1.58),(.26,.26,.26),4,n=16,rings=10,smooth=False,facets=True)
        for x,y in [(-.63,.85),(.63,.85)]:b.poly(star(.1),(x,y,1.28),.025,6)
    elif name=="Knight":
        shield=[(-.32,.3),(.32,.3),(.3,-.08),(0,-.36),(-.3,-.08)]
        b.poly(shield,(0,.77,1.29),.065,5)
        b.poly([(x*.83,y*.83) for x,y in shield],(0,.77,1.33),.03,7)
        b.box((0,.77,1.355),(.055,.37,.024),5);b.box((0,.83,1.355),(.3,.055,.024),5)
        for x,y in [(-.86,.0),(.86,.0),(-.86,1.2),(.86,1.2)]:b.sphere((x,y,1.27),(.04,.04,.025),4,n=10,rings=6)
        for side in [-1,1]:
            cg=g["Claw_L" if side<0 else "Claw_R"]
            cg.box((side*1.34,-.82,1.018),(.36,.4,.025),4)
    elif name=="Robot":
        for x in [-.7,.7]:
            b.cylinder((x,1.1,1.24),(x,1.1,1.56),.028,.022,7,n=12);b.sphere((x,1.1,1.61),(.075,.075,.075),5,n=12,rings=8)
        b.box((0,.8,1.275),(.6,.42,.045),7)
        b.box((0,.8,1.302),(.5,.32,.02),4)
        for x in [-.16,0,.16]:b.box((x,.8,1.317),(.05,.2,.012),5)
    elif name=="Cloud":
        for x,y,z,r in [(-.55,1.0,1.3,.23),(-.2,1.05,1.38,.29),(.17,1.05,1.4,.3),(.53,1.0,1.3,.23)]:b.sphere((x,y,z),(r,r*.8,r*.7),4,n=16,rings=10)
    elif name=="Cactus":
        for x in [-.92,.92]:
            for y in [.12,.48,.84,1.18]:b.cylinder((x,y,1.19),(x+(.08 if x>0 else -.08),y,1.38),.022,0,4,n=6)
        for a in np.linspace(0,math.tau,7,endpoint=False):b.sphere((.43+.14*math.cos(a),1.0+.14*math.sin(a),1.34),(.12,.1,.07),5,n=12,rings=8)
        b.sphere((.43,1.0,1.4),(.075,.075,.05),12,n=12,rings=8)
    elif name=="Cupcake":
        for x in [-.7,-.35,0,.35,.7]:
            b.sphere((x,1.1,1.29),(.19,.18,.12),4,n=16,rings=8)
            b.cylinder((x,1.1,1.3),(x+.025,1.1,1.52),.13,0,4,n=12)
        rng=np.random.default_rng(21)
        for i in range(20):
            x,y=rng.uniform(-.85,.85),rng.uniform(-.1,.8);a=rng.random()*math.tau
            b.cylinder((x,y,1.27),(x+.07*math.cos(a),y+.07*math.sin(a),1.27),.015,.015,10+i%6,n=8)
        b.sphere((-.22,.88,1.54),(.15,.15,.15),15,n=20,rings=12)
        b.cylinder((-.22,.88,1.67),(-.16,.9,1.82),.014,.01,13,n=8)
    elif name=="Arcade":
        b.cylinder((-.47,.94,1.25),(-.47,.94,1.29),.18,.18,7,n=20)
        b.cylinder((-.47,.94,1.29),(-.47,.94,1.51),.035,.035,4,n=12)
        b.sphere((-.47,.94,1.56),(.11,.11,.11),10,n=16,rings=10)
        for x,y,c in [(.25,.84,10),(.52,1.01,11),(.55,.68,12)]:b.cylinder((x,y,1.25),(x,y,1.31),.08,.08,c,n=16)
        b.box((-.35,.25,1.28),(.32,.1,.04),7);b.box((-.35,.25,1.28),(.1,.32,.04),7)
    elif name=="Storm":
        for x,y,z,r in [(-.6,1.02,1.3,.2),(-.3,1.07,1.36,.26),(.02,1.04,1.32,.23)]:b.sphere((x,y,z),(r,r*.8,r*.7),5,n=16,rings=10)
        b.poly(bolt(.65),(.49,1.0,1.26),.06,4,axis="y")
    return g

def initialize():
    global BASE, ORIGINAL_SCENE, SCENE, MANIFEST
    OUT.mkdir(parents=True,exist_ok=True);WORK.mkdir(parents=True,exist_ok=True)
    ORIGINAL_SCENE=bpy.context.scene
    BASE={o.name:o for o in ORIGINAL_SCENE.objects if o.type=="MESH"}
    assert "Body" in BASE and len(BASE)==28,"Expected the original 28-part crab scene."
    assert not bpy.data.scenes.get("Crab Variants"),"Variant scene already exists; load the existing module instead."
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/"BaseCrab_Original.blend"),copy=True)
    SCENE=bpy.data.scenes.new("Crab Variants")
    bpy.context.window.scene=SCENE
    SCENE.world=ORIGINAL_SCENE.world
    SCENE.unit_settings.system=ORIGINAL_SCENE.unit_settings.system
    SCENE.unit_settings.scale_length=ORIGINAL_SCENE.unit_settings.scale_length
    MANIFEST=[]
    print("Original crab backed up; variant workspace ready.")

def make_material(name,image,eye=False):
    m=bpy.data.materials.new(name);m.use_nodes=True
    bsdf=next(n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    bsdf.inputs["Roughness"].default_value=.2 if eye else .42
    tex=m.node_tree.nodes.new("ShaderNodeTexImage");tex.image=image
    m.node_tree.links.new(tex.outputs["Color"],bsdf.inputs["Base Color"])
    return m

def face_uv(mesh,poly,tag,uv):
    coords=[mesh.vertices[mesh.loops[i].vertex_index].co for i in poly.loop_indices]
    if tag==-1:
        for li,co in zip(poly.loop_indices,coords):
            uv.data[li].uv=(.018+.964*(co.x+1.17)/2.34,.265+.72*(co.y+.427)/1.94)
    elif tag==-2:
        ax=0 if abs(poly.normal.y)>=abs(poly.normal.x) else 1
        lo,span=(-1.17,2.34) if ax==0 else (-.427,1.94)
        for li,co in zip(poly.loop_indices,coords):uv.data[li].uv=(.02+.96*(co[ax]-lo)/span,.135+.10*(co.z-.42)/.83)
    else:
        axis=max(range(3),key=lambda i:abs(poly.normal[i]));axes=[i for i in range(3) if i!=axis]
        mins=[min(v[a] for v in coords) for a in axes];spans=[max(v[a] for v in coords)-mins[k] for k,a in enumerate(axes)]
        for li,co in zip(poly.loop_indices,coords):
            u=(co[axes[0]]-mins[0])/max(spans[0],1e-8);v=(co[axes[1]]-mins[1])/max(spans[1],1e-8)
            uv.data[li].uv=((tag%8+.22+.56*u)/8,(tag//8+.22+.56*v)/16)

def build(name):
    assert name in NAMES
    model=name+"Crab"
    assert not bpy.data.objects.get(model),model+" already exists"
    pal,path=texture(name)
    image=bpy.data.images.load(str(path),check_existing=False);image.name=model+"_Color"
    shellmat=make_material(model+"_Textured",image)
    eyemat=make_material(model+"_Eyes",image,True)
    collection=bpy.data.collections.new(model);SCENE.collection.children.link(collection)
    root=bpy.data.objects.new(model,None);collection.objects.link(root)
    addons=details(name);objects=[]
    for role,src in BASE.items():
        geo=Geo()
        coords=[src.matrix_world@v.co for v in src.data.vertices]
        cols=[]
        for p in src.data.polygons:
            if role=="Body":col=-1 if p.normal.z>.5 else (-2 if p.normal.z>-.5 else 0)
            elif role.startswith("EyeHighlight"):col=9
            elif role.startswith("Eye_"):col=8
            elif role.startswith("ShellSpot"):
                col=3 if name not in ("Disco","Cupcake","Prism","Arcade") else 10+(int(role[-2:])%6)
            elif role.startswith("Claw_"):col=2 if p.material_index==1 else 1
            else:
                z=sum(coords[i].z for i in p.vertices)/len(p.vertices)
                col=2 if role.startswith("Leg_") and z<.19 else 1
            cols.append(col)
        geo.add(coords,[tuple(p.vertices) for p in src.data.polygons],cols)
        geo.s=[p.use_smooth for p in src.data.polygons]
        if role in addons and addons[role].f:
            a=addons[role];geo.add(a.v,a.f,a.c);geo.s[-len(a.s):]=a.s
        mesh=bpy.data.meshes.new(model+"_"+role+"_Mesh");mesh.from_pydata(geo.v,[],geo.f);mesh.update()
        obj=bpy.data.objects.new(model+"_"+role,mesh);collection.objects.link(obj);obj.parent=root
        mesh.materials.append(eyemat if role.startswith("Eye_") else shellmat)
        uv=mesh.uv_layers.new(name="UVMap")
        for p,tag,sm in zip(mesh.polygons,geo.c,geo.s):
            p.use_smooth=sm;face_uv(mesh,p,tag,uv)
        bm=bmesh.new();bm.from_mesh(mesh);bmesh.ops.recalc_face_normals(bm,faces=list(bm.faces))
        bmesh.ops.triangulate(bm,faces=[f for f in bm.faces if len(f.verts)>4]);bm.to_mesh(mesh);bm.free();mesh.update()
        objects.append(obj)
    bpy.ops.object.select_all(action="DESELECT")
    root.select_set(True)
    for o in objects:o.select_set(True)
    bpy.context.view_layer.objects.active=root
    # Enum identifiers have been checked against this installed exporter.
    bpy.ops.export_scene.fbx(filepath=str(OUT/(model+".fbx")),use_selection=True,object_types={"MESH","EMPTY"},
                             path_mode="COPY",embed_textures=True,axis_forward="-Z",axis_up="Y",global_scale=1.0,
                             apply_unit_scale=True,use_mesh_modifiers=True,bake_anim=False,add_leaf_bones=False)
    index=NAMES.index(name)
    root.location=((index%6)*5.2,(index//6)*4.9,0)
    tris=0
    for o in objects:o.data.calc_loop_triangles();tris+=len(o.data.loop_triangles)
    result={"name":model,"description":DESCRIPTIONS[name],"fbx":model+".fbx","texture":path.name,
            "mesh_count":len(objects),"triangles":tris,"texture_size":[1024,1024],"embedded_texture":True}
    MANIFEST.append(result)
    (OUT/"manifest.json").write_text(json.dumps(MANIFEST,indent=2),encoding="utf-8")
    print(json.dumps(result))
    return result

def save_source():
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/"CrabVariants.blend"),copy=True)
    print("Saved editable scene with original and variants.")
