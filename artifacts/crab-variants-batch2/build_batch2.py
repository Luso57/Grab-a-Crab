"""Second collection: preserve the base meshes, add small details, embed PNG atlases."""
import bpy
import importlib.util
import json
import math
import hashlib
import numpy as np
from pathlib import Path
from mathutils import Vector

ROOT=Path(r"C:\Grab a Crab")
WORK=ROOT/"artifacts"/"crab-variants-batch2"
OUT=ROOT/"Crabmodels"
spec=importlib.util.spec_from_file_location("crab_batch2_core",str(ROOT/"artifacts"/"crab-variants"/"build_crabs.py"))
core=importlib.util.module_from_spec(spec)
spec.loader.exec_module(core)
Geo,Painter,rgb=core.Geo,core.Painter,core.rgb
original_face_uv=core.face_uv
NAMES=["Sushi","Pizza","Pineapple","Strawberry","Popcorn","Coffee","Ramen","Origami","Patchwork","Porcelain","Sunflower","CoralReef","RaceCar","Firefighter","Detective","Pharaoh","Viking","Music"]
PALETTES={
 "Sushi":["ee8772","f1e8cc","fff8e8","f6ceb1","375748","89b775","ffefdc","263a33"],
 "Pizza":["efc25f","c99244","ffe69b","bb4f41","d49a4e","719e62","fff0b9","8c4239"],
 "Pineapple":["dfb646","c39639","f7dfa0","b58c38","6fa36b","48794d","ffebae","8c692c"],
 "Strawberry":["d85e66","c65561","f7b8b5","ffe6ac","7ca968","537e4f","fff0cb","9f3a4c"],
 "Popcorn":["d9635e","cd5655","fff0c4","f9e8b5","fff1c9","e5c17a","fff9e9","974542"],
 "Coffee":["725044","8c6753","ecd6b5","edcfa4","9b684c","543a30","fff0d3","3f2d2a"],
 "Ramen":["edc878","bd6853","ffe8b0","f8e6be","f5d88a","6ba06b","fff6db","a85b42"],
 "Origami":["ebdfce","98bccb","edf7f4","b2ccd5","80b3cb","de968b","fff5e6","768a9c"],
 "Patchwork":["8eaebc","91a4bb","edc6c8","ddc19a","cd959e","a2ba9c","fff0d9","667c91"],
 "Porcelain":["e8edf1","b5cbdc","f6fbff","4c73a5","366194","7ba3c7","ffffff","274775"],
 "Sunflower":["8e6345","75905b","f5d676","e1b65c","efc355","f5db8c","fff0ba","614933"],
 "CoralReef":["a3d2c7","7cb8b4","f1ebdc","b3e1e0","ef9b8d","b5a0d4","fff4df","4f8f93"],
 "RaceCar":["cf5a5a","bc4a52","404554","b95352","edf0ed","414857","fff7e5","702c3b"],
 "Firefighter":["cb5251","b94b4d","f5d376","e9be61","d4544e","f5d474","fff0bf","713a3f"],
 "Detective":["c6ae8e","a58a6d","e9d9b9","d4c09e","a48664","664f40","f7e7c7","54463c"],
 "Pharaoh":["456897","477e99","e9cf80","ebcb70","e4c36c","48aeb3","fff0b2","294263"],
 "Viking":["81939d","99795e","e5d2aa","d4c39c","adb9c0","b69970","fff0cf","526172"],
 "Music":["78639d","607f9c","e3a0c3","eaa8c9","70c8cd","353c53","f6efff","424160"],
}
EXTRA=["101725","ffffff","ef9cb8","83d4dc","f8df87","9cc594","b8a4da","ea9274"]
DESCRIPTIONS={
 "Sushi":"Salmon stripes, seaweed wrap, rice white limbs, and a little wasabi garnish.",
 "Pizza":"Golden cheese, pepperoni spots, olive rings, and a raised crust trim.",
 "Pineapple":"Golden diamond rind and a small green leafy crown.",
 "Strawberry":"Red skin, cream seeds, and fresh green leaves.",
 "Popcorn":"Cinema stripes and small buttery popcorn puffs.",
 "Coffee":"Espresso brown with latte art and coffee bean details.",
 "Ramen":"Golden noodles, an egg garnish, scallions, and chopsticks.",
 "Origami":"Paper panels, printed fold lines, and a small folded paper bird.",
 "Patchwork":"Pastel fabric panels, stitched borders, and sewn buttons.",
 "Porcelain":"White porcelain with blue flowers and decorative borders.",
 "Sunflower":"Brown seed pattern, golden petal trim, and green limbs.",
 "CoralReef":"Seafoam shell with small colorful branching corals.",
 "RaceCar":"Red racing paint, white stripes, number 07, and a small spoiler.",
 "Firefighter":"Red helmet, yellow safety markings, and a shield badge.",
 "Detective":"Tan tweed, a brown hat, and a magnifying glass on one claw.",
 "Pharaoh":"Lapis and turquoise with a striped gold headdress.",
 "Viking":"Steel helmet, ivory horns, and small fur trim details.",
 "Music":"Purple musical staff patterns and colorful headphones.",
}

def ellipse(p,x,y,rx,ry,color,angle=0):
    dx=p.x-x;dy=p.y-y;c=math.cos(angle);s=math.sin(angle)
    d=np.sqrt(((dx*c+dy*s)/rx)**2+((-dx*s+dy*c)/ry)**2)
    p.paint(np.clip((1-d)*min(rx,ry)*950,0,1),color)

def path(p,points,width,color,alpha=1):
    for a,b in zip(points,points[1:]):p.line(a,b,width,color,alpha)

def flower(p,u,v,r,colors):
    for a in np.linspace(0,math.tau,6,endpoint=False):
        ellipse(p,u+math.cos(a)*r*.58,v+math.sin(a)*r*.58,r*.5,r*.23,colors[0],a)
    p.disc(u,v,r*.23,colors[1])

def texture(name):
    pal=[rgb(h) for h in PALETTES[name]+EXTRA]
    p=Painter(pal[0]);x,y=p.x,p.y
    p.a*=(.96+.06*y)[...,None]
    rng=np.random.default_rng(482+NAMES.index(name))
    if name=="Sushi":
        for v in np.arange(-.4,1.5,.15):
            path(p,[(-.05,v),(.5,v+.26),(1.05,v)],.014,pal[6])
        p.paint((x>.415)&(x<.585),pal[4])
        for u in [.43,.46,.49,.52,.55,.575]:p.line((u,0),(u,1),.002,pal[5],.5)
    elif name=="Pizza":
        for u,v in [(0.1,.1),(.32,.28),(.75,.14),(.16,.6),(.55,.73),(.89,.88)]:
            p.disc(u,v,.047,pal[3]);p.disc(u-.012,v+.012,.007,pal[7])
        for u,v in [(.26,.82),(.68,.45),(.82,.6),(.45,.1)]:p.ring(u,v,.026,.008,pal[7])
        for i in range(16):
            u,v=rng.uniform(.05,.95,2);p.line((u,v),(u+.025,v+.035),.007,pal[5])
        for a,b in [((.015,0),(.015,1)),((.985,0),(.985,1)),((0,.98),(1,.98))]:p.line(a,b,.026,pal[4])
    elif name=="Pineapple":
        for shift in np.arange(-1.1,1.1,.2):
            p.line((shift,0),(shift+1,1),.009,pal[7]);p.line((shift+1,0),(shift,1),.009,pal[7])
            p.line((shift+.016,0),(shift+1.016,1),.003,pal[6])
        for u in np.arange(.1,1,.2):
            for v in np.arange(.1,1,.2):p.poly([(u,v+.018),(u+.012,v),(u,v-.018),(u-.012,v)],pal[3])
    elif name=="Strawberry":
        for j,v in enumerate(np.arange(.07,1,.16)):
            for u in np.arange(.06,1,.14):ellipse(p,u+(j%2)*.06,v,.009,.018,pal[3],-.2)
    elif name=="Popcorn":
        p.paint((np.floor(x*12)%2)==0,pal[6])
        p.poly([(.29,.22),(.71,.22),(.71,.68),(.29,.68)],pal[7])
        p.poly([(.31,.24),(.69,.24),(.69,.66),(.31,.66)],pal[0])
        p.poly([(u*.25+.5,v*.25+.45) for u,v in core.star(.65)],pal[2])
    elif name=="Coffee":
        ellipse(p,.5,.49,.35,.35,pal[4])
        # Layered latte leaves with a cream stem.
        for j in range(7):
            v=.3+j*.052;r=.13*(1-j*.09)
            ellipse(p,.5-r*.44,v,r,.027,pal[6],-.22)
            ellipse(p,.5+r*.44,v,r,.027,pal[6],.22)
        p.line((.5,.22),(.5,.69),.008,pal[6])
        p.ring(.5,.49,.355,.006,pal[3])
    elif name=="Ramen":
        for j in range(10):
            points=[(u,.06+j*.09+.025*math.sin(u*math.tau*2+j)) for u in np.linspace(0,1,32)]
            path(p,points,.012,pal[4]);path(p,[(u,v+.012) for u,v in points],.003,pal[6])
        for u,v in [(.18,.22),(.66,.38),(.83,.67),(.24,.84)]:p.ring(u,v,.028,.01,pal[5])
    elif name=="Origami":
        p.poly([(0,0),(.5,.5),(0,1)],pal[4]);p.poly([(1,0),(.5,.5),(1,1)],pal[3]);p.poly([(0,1),(.5,.5),(1,1)],pal[6])
        for a,b in [((0,0),(1,1)),((1,0),(0,1)),((.5,0),(.5,1)),((0,.5),(1,.5))]:
            for t in np.arange(0,1,.04):
                q=(a[0]+(b[0]-a[0])*t,a[1]+(b[1]-a[1])*t);t2=min(t+.022,1)
                p.line(q,(a[0]+(b[0]-a[0])*t2,a[1]+(b[1]-a[1])*t2),.0016,pal[7])
    elif name=="Patchwork":
        for j in range(4):
            for i in range(4):
                u,v=i/4,j/4;c=pal[[0,4,5,3,14,11][(i+2*j)%6]]
                p.poly([(u,v),(u+.25,v),(u+.25,v+.25),(u,v+.25)],c)
                for t in np.arange(.015,.25,.035):
                    p.line((u+t,v+.012),(u+t+.018,v+.012),.002,pal[6]);p.line((u+.012,v+t),(u+.012,v+t+.018),.002,pal[6])
    elif name=="Porcelain":
        for u,v,r in [(.22,.28,.095),(.69,.25,.08),(.48,.6,.12),(.18,.85,.075),(.81,.8,.09)]:
            flower(p,u,v,r,[pal[4],pal[5]])
            for sign in [-1,1]:
                pts=[(u+sign*t*.16,v+.03+math.sin(t*math.pi)*.08) for t in np.linspace(0,1,14)]
                path(p,pts,.0025,pal[4]);ellipse(p,u+sign*.12,v+.12,.045,.014,pal[5],sign*.5)
        for u in [.025,.975]:p.line((u,0),(u,1),.005,pal[4])
        for v in [.025,.975]:p.line((0,v),(1,v),.005,pal[4])
    elif name=="Sunflower":
        for j,v in enumerate(np.arange(.06,1,.09)):
            for u in np.arange(.04,1,.09):ellipse(p,u+(j%2)*.045,v,.012,.022,pal[7],.45)
    elif name=="CoralReef":
        for i in range(45):
            u,v=rng.random(2);p.disc(u,v,rng.uniform(.006,.025),pal[[3,4,5,6][i%4]],.7)
        for u in [.1,.38,.8]:
            path(p,[(u,.2),(u+.02,.45),(u-.02,.7),(u+.04,.95)],.005,pal[7],.5)
            for v in [.4,.65,.8]:p.line((u,v),(u-.06,v+.09),.004,pal[7],.5)
    elif name=="RaceCar":
        for u in [.17,.78]:p.paint((x>u)&(x<u+.055),pal[4])
        p.poly([(.34,.16),(.66,.16),(.66,.43),(.34,.43)],pal[4])
        path(p,[(.39,.22),(.46,.22),(.46,.37),(.39,.37),(.39,.22)],.012,pal[5])
        path(p,[(.52,.37),(.61,.37),(.54,.22)],.012,pal[5])
        for j in range(2):
            for i in range(10):
                if (i+j)%2==0:p.poly([(i*.1,.85+j*.05),(i*.1+.1,.85+j*.05),(i*.1+.1,.9+j*.05),(i*.1,.9+j*.05)],pal[5])
    elif name=="Firefighter":
        for u in [.1,.85]:p.paint((x>u)&(x<u+.05),pal[5])
        for a,b in [((.25,.12),(.5,.3)),((.5,.3),(.75,.12))]:p.line(a,b,.018,pal[5])
    elif name=="Detective":
        for j in range(14):
            for i in range(14):
                u,v=i/14,j/14;sign=1 if i%2==0 else -1
                p.line((u,v),(u+.025,v+sign*.025),.0018,pal[7],.28)
        for u in [.05,.95]:p.line((u,0),(u,1),.005,pal[5])
    elif name=="Pharaoh":
        for j in range(13):
            v=j/13;p.paint((y>v)&(y<v+.026),pal[4])
        p.poly([(.43,.12),(.57,.12),(.57,.56),(.43,.56)],pal[5])
        for v in [.19,.3,.41]:p.poly([(.5,v+.035),(.54,v),(.5,v-.035),(.46,v)],pal[4])
    elif name=="Viking":
        for u in [.06,.94]:
            p.line((u,0),(u,1),.02,pal[5])
            for v in np.arange(.08,1,.13):p.disc(u,v,.008,pal[6])
        for a,b in [((.35,.1),(.65,.45)),((.65,.1),(.35,.45))]:p.line(a,b,.012,pal[7])
    elif name=="Music":
        for v in [.2,.26,.32,.38,.44,.68,.74,.8,.86,.92]:p.line((.02,v),(.98,v),.002,pal[6],.65)
        for u,v in [(.14,.26),(.34,.38),(.62,.26),(.85,.38),(.25,.8),(.58,.74),(.82,.86)]:
            ellipse(p,u,v,.026,.018,pal[3],.35);p.line((u+.02,v),(u+.02,v+.13),.004,pal[3]);p.line((u+.02,v+.13),(u+.06,v+.1),.006,pal[3])
    atlas=np.zeros((1024,1024,3),np.float32);atlas[256:]=p.a
    for i,col in enumerate(pal):atlas[(i//8)*64:(i//8+1)*64,(i%8)*128:(i%8+1)*128]=col
    sx=np.linspace(0,1,1024)[None,:,None];sy=np.linspace(0,1,128)[:,None,None]
    atlas[128:256]=pal[0]*(.93+.07*sy)
    if name=="Sushi":
        atlas[128:256]=pal[2];atlas[128:256,425:599]=pal[4]
    elif name=="Popcorn":atlas[128:256]=np.where((np.floor(sx*12)%2)==0,pal[6],pal[0])
    elif name=="Patchwork":atlas[128:256]=np.take(np.array([pal[0],pal[4],pal[5],pal[3]]),(np.floor(sx[0,:,0]*8)%4).astype(int),axis=0)[None,:,:]
    elif name in ("Porcelain","Ramen","Firefighter","Pharaoh","Viking","Music"):
        c=4 if name in ("Porcelain","Pharaoh") else 5
        atlas[141:150]=pal[c];atlas[230:239]=pal[c]
    elif name=="RaceCar":atlas[128:256,175:231]=pal[4];atlas[128:256,799:855]=pal[4]
    pathout=OUT/(name+"Crab_Color.png");core.png_write(pathout,atlas)
    return pal,pathout

def tube(g,points,radii,color,n=10):
    pts=[Vector(p) for p in points];verts=[];faces=[]
    for j,p in enumerate(pts):
        axis=(pts[min(j+1,len(pts)-1)]-pts[max(0,j-1)]).normalized()
        u=axis.cross(Vector((0,1,0)))
        if u.length<.001:u=axis.cross(Vector((1,0,0)))
        u.normalize();v=axis.cross(u).normalized()
        for i in range(n):verts.append(p+radii[j]*(math.cos(i*math.tau/n)*u+math.sin(i*math.tau/n)*v))
    faces.append(tuple(reversed(range(n))))
    for j in range(len(pts)-1):
        for i in range(n):faces.append((j*n+i,j*n+(i+1)%n,(j+1)*n+(i+1)%n,(j+1)*n+i))
    faces.append(tuple(range((len(pts)-1)*n,len(pts)*n)))
    g.add(verts,faces,color,True)

def turn(g,start,angle,center):
    c,s=math.cos(angle),math.sin(angle)
    for i in range(start,len(g.v)):
        x,y,z=g.v[i];x-=center[0];y-=center[1]
        g.v[i]=(center[0]+x*c-y*s,center[1]+x*s+y*c,z)

def leaf(g,c,width,height,color,angle=0):
    start=len(g.v)
    g.poly([(0,0),(-width*.5,height*.35),(-width*.25,height*.75),(0,height),(width*.25,height*.75),(width*.5,height*.35)],c,.025,color,axis="y")
    turn(g,start,angle,c)

def details(name):
    g={role:Geo() for role in ["Body","Claw_L","Claw_R"]}
    b=g["Body"]
    if name=="Sushi":
        for x,y in [(-.75,.85),(-.65,1.03),(-.82,1.18)]:b.sphere((x,y,1.29),(.08,.035,.035),2,n=12,rings=6)
        for x,y,z,r in [(.62,.98,1.31,.14),(.78,1.02,1.31,.13),(.7,1.06,1.43,.1)]:b.sphere((x,y,z),(r,r,r*.75),5,n=12,rings=6)
    elif name=="Pizza":
        tube(b,[(-1.02,.0,1.23),(-1.02,.65,1.26),(-.97,1.3,1.24),(-.5,1.38,1.23),(0,1.38,1.23),(.5,1.38,1.23),(.97,1.3,1.24),(1.02,.65,1.26),(1.02,.0,1.23)],[.065]*9,4,n=10)
        for x,y in [(-.42,.73),(.45,.2),(.56,1.06)]:b.torus((x,y,1.27),.065,.018,7,n=16,m=6)
        for x,y in [(-.7,.1),(.8,.6)]:b.sphere((x,y,1.23),(.06,.09,.1),2,n=12,rings=6)
    elif name=="Pineapple":
        for angle,h,w in [(0,.66,.24),(.8,.54,.26),(1.65,.61,.22),(2.55,.5,.26),(3.4,.63,.22),(4.4,.53,.25),(5.4,.56,.24)]:
            x=.12*math.cos(angle);y=1.02+.12*math.sin(angle)
            leaf(b,(x,y,1.25),w,h,4 if h>.55 else 5,angle)
    elif name=="Strawberry":
        for a in np.linspace(0,math.tau,5,endpoint=False):
            x=.35*math.cos(a);y=.88+.3*math.sin(a);k=len(b.v)
            b.poly([(-.22,0),(-.08,-.095),(.24,0),(-.08,.095)],(x,y,1.29),.035,4)
            turn(b,k,a,(x,y,1.29))
        b.cylinder((0,.88,1.27),(.04,.9,1.48),.055,.035,5,n=10)
    elif name=="Popcorn":
        for x,y in [(-.7,1.04),(-.22,1.12),(.27,1.1),(.72,1.01)]:
            for dx,dy,z,r in [(-.07,0,1.37,.12),(.06,.035,1.39,.13),(0,-.045,1.48,.11)]:
                b.sphere((x+dx,y+dy,z),(r,r*.85,r*.8),4,n=12,rings=6)
            b.sphere((x,y-.09,1.38),(.035,.025,.035),5,n=10,rings=6)
    elif name=="Coffee":
        for x,y,a in [(-.57,1.0,-.35),(.56,1.04,.3)]:
            k=len(b.v);b.sphere((x,y,1.32),(.2,.125,.09),4,n=16,rings=8);turn(b,k,a,(x,y,1.32))
            points=[(x+t*math.cos(a),y+t*math.sin(a)+.015*math.sin(t*20),1.409-.025*(t/.15)**2) for t in np.linspace(-.15,.15,9)]
            tube(b,points,[.012]*len(points),7,n=6)
    elif name=="Ramen":
        for off in [0,.16]:b.cylinder((-.72,.93+off,1.4),(.75,1.14+off,1.4),.024,.018,7,n=8)
        b.sphere((-.52,.42,1.285),(.19,.23,.045),6,n=16,rings=6)
        b.sphere((-.52,.44,1.325),(.095,.115,.02),12,n=14,rings=6)
        for x,y in [(.55,.28),(.67,.7),(-.8,.75)]:b.torus((x,y,1.28),.065,.018,5,n=16,m=6)
        for offset in [0,.14]:
            points=[(-.25+.5*t,.28+offset+.05*math.sin(t*math.tau*2),1.27) for t in np.linspace(0,1,18)]
            tube(b,points,[.018]*len(points),4,n=6)
    elif name=="Origami":
        # Closed paper-like triangular wedges form a compact folded bird.
        b.add([(-.03,.85,1.4),(-.53,.95,1.66),(-.22,.54,1.38),(-.2,.81,1.36)],[(0,1,2),(0,3,1),(1,3,2),(2,3,0)],4)
        b.add([(.03,.85,1.4),(.53,.95,1.66),(.22,.54,1.38),(.2,.81,1.36)],[(0,2,1),(0,1,3),(1,2,3),(2,0,3)],6)
        b.add([(-.1,.86,1.28),(.1,.86,1.28),(0,.57,1.44),(0,1.19,1.39)],[(0,2,1),(0,1,3),(0,3,2),(1,2,3)],3)
        b.poly([(-.035,0),(.035,0),(.11,.27),(.045,.36),(.005,.26)],(0,.62,1.39),.055,4,axis="y")
        b.add([(.03,.59,1.73),(.1,.59,1.68),(.05,.42,1.7),(.06,.61,1.65)],[(0,1,2),(0,3,1),(0,2,3),(1,3,2)],5)
    elif name=="Patchwork":
        for x,y,r,c in [(-.56,.91,.14,4),(.5,.95,.12,5),(0,.32,.11,14)]:
            b.cylinder((x,y,1.25),(x,y,1.3),r,r,c,n=20)
            for dx in [-.028,.028]:
                for dy in [-.028,.028]:b.cylinder((x+dx,y+dy,1.3),(x+dx,y+dy,1.306),.011,.011,7,n=8)
    elif name=="Porcelain":
        # The printed blue flowers are the main feature; keep the porcelain silhouette clean.
        pass
    elif name=="Sunflower":
        for a in np.linspace(0,math.tau,12,endpoint=False):
            x=.64*math.cos(a);y=.62+.49*math.sin(a);k=len(b.v)
            b.sphere((x,y,1.28),(.25,.095,.045),4 if math.cos(a)>0 else 5,n=12,rings=6)
            turn(b,k,a,(x,y,1.28))
        b.cylinder((0,.62,1.245),(0,.62,1.28),.35,.35,0,n=24)
        for a in np.linspace(0,math.tau,10,endpoint=False):b.sphere((.23*math.cos(a),.62+.23*math.sin(a),1.289),(.025,.035,.012),7,n=8,rings=4)
    elif name=="CoralReef":
        for x,y,c,h in [(-.67,1.05,4,.47),(0,1.17,5,.6),(.63,1.05,11,.43)]:
            tube(b,[(x,y,1.23),(x-.025,y,1.4),(x+.025,y,1.25+h)],[.055,.043,.024],c,n=10)
            for direction,z in [(-1,1.38),(1,1.48)]:
                tip=(x+direction*.17,y-.025,z+.2)
                tube(b,[(x,y,z),(x+direction*.13,y-.02,z+.08),tip],[.035,.025,.015],c,n=8)
                b.sphere(tip,(.024,.024,.026),c,n=8,rings=5)
        b.poly(core.star(.13),(-.52,.3,1.28),.025,15)
    elif name=="RaceCar":
        for x in [-.48,.48]:b.box((x,1.15,1.4),(.08,.13,.3),5)
        b.box((0,1.15,1.58),(1.4,.27,.07),5)
        b.box((0,1.135,1.622),(1.22,.07,.018),4)
        for side in [-1,1]:
            cg=g["Claw_L" if side<0 else "Claw_R"]
            cg.box((side*1.34,-.82,1.018),(.055,.38,.015),4)
    elif name=="Firefighter":
        b.sphere((0,.9,1.31),(.64,.48,.045),4,n=24,rings=6)
        b.sphere((0,.94,1.35),(.47,.36,.29),4,n=24,rings=10)
        tube(b,[(0,.65,1.48),(0,.8,1.62),(0,1.03,1.64),(0,1.23,1.49)],[.025]*4,5,n=8)
        badge=[(-.1,.12),(.1,.12),(.09,-.04),(0,-.12),(-.09,-.04)]
        b.poly(badge,(0,.58,1.48),.025,5,axis="y")
        b.box((-.025,.559,1.48),(.025,.015,.13),7);b.box((.01,.559,1.535),(.08,.015,.025),7);b.box((.002,.559,1.486),(.065,.015,.022),7)
    elif name=="Detective":
        b.sphere((0,.93,1.31),(.61,.43,.045),4,n=24,rings=6)
        start=len(b.v);b.cylinder((0,.93,1.32),(0,.93,1.62),.4,.34,4,n=16)
        for i in range(start,len(b.v)):
            x,y,z=b.v[i];b.v[i]=(x,.93+(y-.93)*.72,z)
        start=len(b.v);b.cylinder((0,.93,1.34),(0,.93,1.415),.404,.39,5,n=16)
        for i in range(start,len(b.v)):
            x,y,z=b.v[i];b.v[i]=(x,.93+(y-.93)*.72,z)
        cg=g["Claw_L"];cg.torus((-1.34,-.98,1.08),.16,.025,7,n=24,m=6)
        cg.cylinder((-1.34,-.82,1.08),(-1.34,-.52,1.08),.032,.028,5,n=12)
    elif name=="Pharaoh":
        b.sphere((0,.98,1.46),(.35,.28,.34),0,n=20,rings=10)
        for sign in [-1,1]:
            flap=[(sign*x,z) for x,z in [(.22,0),(.58,.02),(.47,.4),(.25,.5)]]
            b.poly(flap,(0,.98,1.25),.12,4,axis="y")
            for z in [1.32,1.42,1.52]:b.box((sign*(.4-(z-1.32)*.25),.906,z),(.22,.025,.044),0)
        tube(b,[(-.3,.79,1.6),(-.17,.72,1.66),(0,.7,1.68),(.17,.72,1.66),(.3,.79,1.6)],[.025]*5,4,n=8)
        tube(b,[(0,.7,1.65),(0,.67,1.78),(0,.6,1.82)],[.024,.03,.03],4,n=10)
        b.sphere((0,.58,1.83),(.045,.035,.04),4,n=12,rings=6)
    elif name=="Viking":
        b.sphere((0,.94,1.34),(.5,.37,.28),4,n=24,rings=10)
        b.torus((0,.94,1.33),.47,.035,7,n=24,m=6,scale=(1,.76,1))
        tube(b,[(0,.6,1.36),(0,.7,1.54),(0,.94,1.63),(0,1.18,1.54),(0,1.27,1.36)],[.02]*5,7,n=8)
        for sign in [-1,1]:
            tube(b,[(sign*.4,.95,1.49),(sign*.61,.95,1.61),(sign*.7,.95,1.8),(sign*.64,.95,1.97)],[.09,.075,.045,.006],2,n=12)
        for x in [-.82,-.56,.56,.82]:b.sphere((x,1.22,1.27),(.13,.1,.06),5,n=12,rings=6)
    elif name=="Music":
        points=[(1.19*math.cos(t),.82,.96+.94*math.sin(t)) for t in np.linspace(0,math.pi,21)]
        tube(b,points,[.055]*len(points),5,n=10)
        for side in [-1,1]:
            b.cylinder((side*1.08,.82,.98),(side*1.27,.82,.98),.225,.225,5,n=24)
            b.cylinder((side*1.27,.82,.98),(side*1.31,.82,.98),.19,.19,4,n=24)
            b.cylinder((side*1.31,.82,.98),(side*1.325,.82,.98),.1,.1,3,n=20)
    return g

def face_uv(mesh,poly,tag,uv):
    if mesh.name.startswith("SushiCrab_Body") and tag==-2 and abs(poly.normal.x)>abs(poly.normal.y):tag=2
    if mesh.name.startswith("SushiCrab_ShellSpot_06") and tag==3:tag=4
    original_face_uv(mesh,poly,tag,uv)

def signature(o):
    mats=[]
    for m in o.data.materials:
        n=next(n for n in m.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
        mats.append((tuple(m.diffuse_color),tuple(n.inputs["Base Color"].default_value),n.inputs["Roughness"].default_value,n.inputs["Metallic"].default_value))
    return (tuple(o.location),tuple(o.rotation_euler),tuple(o.scale),[tuple(v.co) for v in o.data.vertices],[(tuple(p.vertices),p.use_smooth,p.material_index) for p in o.data.polygons],[[tuple(v.uv) for v in l.data] for l in o.data.uv_layers],mats)

def verify_original():
    names=list(core.BASE)
    with bpy.data.libraries.load(str(ROOT/"artifacts"/"crab-variants"/"BaseCrab_Original.blend"),link=False) as (src,dst):dst.objects=names.copy()
    loaded=list(dst.objects)
    checks={name:signature(core.BASE[name])==signature(obj) for name,obj in zip(names,loaded)}
    meshes=[o.data for o in loaded];mats={m for o in loaded for m in o.data.materials}
    for o in loaded:bpy.data.objects.remove(o,do_unlink=True)
    for mesh in meshes:
        if mesh.users==0:bpy.data.meshes.remove(mesh)
    for m in mats:
        if m.users==0:bpy.data.materials.remove(m)
    assert len(checks)==28 and all(checks.values()),checks
    (WORK/"original_preservation.json").write_text(json.dumps(checks,indent=2))
    print("Original crab matches the saved backup: 28/28 parts.")

def initialize():
    WORK.mkdir(parents=True,exist_ok=True);OUT.mkdir(exist_ok=True)
    assert bpy.data.scenes.get("Crab Variants 2") is None,"Second batch scene already exists."
    original=bpy.data.scenes.get("Scene")
    assert original is not None
    core.BASE={o.name:o for o in original.objects if o.type=="MESH"}
    assert len(core.BASE)==28 and "Body" in core.BASE
    core.NAMES=NAMES;core.DESCRIPTIONS=DESCRIPTIONS;core.WORK=WORK;core.OUT=OUT
    core.texture=texture;core.details=details;core.face_uv=face_uv;core.MANIFEST=[]
    verify_original()
    core.SCENE=bpy.data.scenes.new("Crab Variants 2");core.SCENE.world=original.world
    core.SCENE.unit_settings.system=original.unit_settings.system;core.SCENE.unit_settings.scale_length=original.unit_settings.scale_length
    bpy.context.window.scene=core.SCENE
    print("Second batch workspace ready.")

def build(name):
    result=core.build(name)
    assert result["triangles"]<10000,result
    return result

def finish():
    verify_original()
    for name in NAMES:bpy.data.images[name+"Crab_Color"].pack()
    bpy.ops.object.select_all(action="DESELECT")
    for screen in bpy.data.screens:
        for area in screen.areas:
            if area.type=="VIEW_3D":
                s=area.spaces.active
                assert "MATERIAL" in [i.identifier for i in s.shading.bl_rna.properties["type"].enum_items]
                s.shading.type="MATERIAL";s.shading.use_scene_world=False;s.shading.use_scene_lights=False
                s.region_3d.view_location=Vector((13,4.9,.8));s.region_3d.view_rotation=Vector((0,-5,7)).to_track_quat("Z","Y");s.region_3d.view_distance=25
                assert "ORTHO" in [i.identifier for i in s.region_3d.bl_rna.properties["view_perspective"].enum_items]
                s.region_3d.view_perspective="ORTHO"
    bpy.ops.wm.save_as_mainfile(filepath=str(WORK/"CrabVariants2.blend"),copy=True)
    print("Saved second batch editable source and packed all texture images.")
