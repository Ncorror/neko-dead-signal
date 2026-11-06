#!/usr/bin/env python3
"""Author the Frontier v1 mesh kit as deterministic, self-contained glTF 2 GLBs.

No downloaded models, textures, fonts or authoring packages are required. Each
asset has one opaque vertex-colour material and a bottom-centre Y-up origin.
Run --check in CI; --preview additionally renders a geometry contact sheet.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import math
from pathlib import Path
import random
import struct

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / 'client/assets/environment/frontier_v1'
ART = ROOT / 'assets/art/environment-frontier-v1'

STEEL = '#56717e'
LIGHT = '#a5b6b8'
DARK = '#253b46'
WHITE = '#ced5cd'
OCHRE = '#b8a06b'
CYAN = '#67b1af'
STONE = '#697b83'


def add(a, b): return tuple(x+y for x, y in zip(a, b))
def sub(a, b): return tuple(x-y for x, y in zip(a, b))
def mul(a, k): return tuple(x*k for x in a)
def dot(a, b): return sum(x*y for x, y in zip(a, b))
def cross(a, b): return (a[1]*b[2]-a[2]*b[1], a[2]*b[0]-a[0]*b[2], a[0]*b[1]-a[1]*b[0])
def unit(a): return mul(a, 1/math.sqrt(dot(a, a)))


def color(hex_value, shade=1):
    srgb = [int(hex_value.lstrip('#')[i:i+2], 16)/255 for i in (0, 2, 4)]
    # COLOR_0 in glTF is linear; keep export independent of renderer colour flags.
    return tuple(max(0, min(1, (v/12.92 if v <= .04045 else ((v+.055)/1.055)**2.4)*shade)) for v in srgb)+(1,)


class Mesh:
    def __init__(self):
        self.positions = []
        self.normals = []
        self.colors = []

    def face(self, points, paint, outward=None, shade=1):
        points = list(points)
        n = cross(sub(points[1], points[0]), sub(points[2], points[0]))
        if dot(n, n) < 1e-14:
            raise ValueError('degenerate authoring face')
        if outward is not None and dot(n, outward) < 0:
            points.reverse()
        for i in range(1, len(points)-1):
            tri = (points[0], points[i], points[i+1])
            normal = unit(cross(sub(tri[1], tri[0]), sub(tri[2], tri[0])))
            self.positions.extend(tri)
            self.normals.extend([normal]*3)
            self.colors.extend([color(paint, shade)]*3)

    def loft(self, rings, paint, caps=True, shades=None):
        n = len(rings[0])
        centre = tuple(sum(p[k] for r in rings for p in r)/(len(rings)*n) for k in range(3))
        for level in range(len(rings)-1):
            for i in range(n):
                face = [rings[level][i], rings[level][(i+1) % n], rings[level+1][(i+1) % n], rings[level+1][i]]
                middle = tuple(sum(p[k] for p in face)/4 for k in range(3))
                self.face(face, paint, sub(middle, centre), (shades or [1]*n)[i])
        if caps:
            self.face(rings[0], paint, sub(rings[0][0], rings[-1][0]), .75)
            self.face(rings[-1], paint, sub(rings[-1][0], rings[0][0]), 1.08)

    @staticmethod
    def ring(width, depth, y, bevel=.08, x=0, z=0):
        a, b = width/2, depth/2
        c = min(bevel, a*.45, b*.45)
        return [(x+px, y, z+pz) for px, pz in [(-a+c,-b),(a-c,-b),(a,-b+c),(a,b-c),(a-c,b),(-a+c,b),(-a,b-c),(-a,-b+c)]]

    def box(self, centre, size, paint, bevel=.04):
        x,y,z = centre
        w,h,d = size
        self.loft([self.ring(w,d,y-h/2,bevel,x,z),self.ring(w,d,y+h/2,bevel,x,z)], paint,
                  shades=[.9,.95,1,.94,.86,.82,.9,.93])

    def tube(self, start, end, radius, paint, segments=8, end_radius=None, caps=True):
        axis = unit(sub(end, start))
        u = unit(cross(axis, (0,1,0) if abs(axis[1]) < .9 else (1,0,0)))
        v = cross(axis, u)
        rings=[]
        for origin, r in [(start, radius), (end, radius if end_radius is None else end_radius)]:
            rings.append([add(origin, add(mul(u,math.cos(i*math.tau/segments)*r),mul(v,math.sin(i*math.tau/segments)*r))) for i in range(segments)])
        self.loft(rings, paint, caps)

    def bounds(self):
        return [[round(min(p[k] for p in self.positions), 6) for k in range(3)],
                [round(max(p[k] for p in self.positions), 6) for k in range(3)]]

    def glb(self, name):
        binary = bytearray()
        views=[]
        accessors=[]
        for values, width, kind in [(self.positions,3,'VEC3'),(self.normals,3,'VEC3'),(self.colors,4,'VEC4')]:
            flat = [value for row in values for value in row]
            raw = struct.pack('<'+'f'*len(flat), *flat)
            views.append({'buffer':0,'byteOffset':len(binary),'byteLength':len(raw),'target':34962})
            binary.extend(raw)
            entry={'bufferView':len(views)-1,'componentType':5126,'count':len(values),'type':kind}
            if values is self.positions:
                packed=struct.unpack('<'+'f'*len(flat),raw)
                entry['min']=[min(packed[k::3]) for k in range(3)]
                entry['max']=[max(packed[k::3]) for k in range(3)]
            accessors.append(entry)
        document={'asset':{'version':'2.0','generator':'REINA Frontier v1 authoring script'},'scene':0,
                  'scenes':[{'nodes':[0]}],'nodes':[{'name':name,'mesh':0}],
                  'meshes':[{'name':name,'primitives':[{'attributes':{'POSITION':0,'NORMAL':1,'COLOR_0':2},'material':0,'mode':4}]}],
                  'materials':[{'name':'FrontierPaint','pbrMetallicRoughness':{'baseColorFactor':[1,1,1,1],'metallicFactor':0,'roughnessFactor':.9},'doubleSided':False}],
                  'buffers':[{'byteLength':len(binary)}],'bufferViews':views,'accessors':accessors}
        encoded=json.dumps(document,separators=(',',':'),sort_keys=True).encode()
        encoded+=b' '*(-len(encoded)%4)
        binary+=b'\0'*(-len(binary)%4)
        total=12+8+len(encoded)+8+len(binary)
        return struct.pack('<III',0x46546c67,2,total)+struct.pack('<II',len(encoded),0x4e4f534a)+encoded+struct.pack('<II',len(binary),0x004e4942)+binary


def habitat():
    m=Mesh()
    m.box((0,.16,0),(6,.32,6),DARK,.26)
    m.box((0,1.52,0),(5.7,2.4,5.7),STEEL,.32)
    m.loft([m.ring(5.95,5.95,2.7,.4),m.ring(5.2,5.4,3.2,.4)],LIGHT)
    m.box((0,.42,-2.89),(5.4,.18,.08),LIGHT)
    m.box((0,1.34,-2.9),(1.72,2.0,.08),DARK)
    m.box((0,1.29,-2.95),(1.43,1.8,.05),LIGHT)
    m.box((0,1.29,-2.981),(.045,1.72,.025),DARK,.005)
    for x in [-1.95,1.95]:
        m.box((x,1.83,-2.9),(1.1,.54,.08),DARK)
        m.box((x,1.85,-2.95),(.94,.3,.025),CYAN)
    for x in [-2.89,2.89]:
        for z in [-1.7,0,1.7]:
            m.box((x,1.7,z),(.09,.6,1.18),DARK)
            m.box((x,1.73,z),(.12,.3,.96),'#80a6ac')
        m.box((x,.62,0),(.1,.12,4.8),WHITE)
    for x in [-1.4,1.4]:
        m.box((x,3.23,0),(1.9,.08,3.1),DARK)
        for z in [-1.0,-.5,0,.5,1.0]:
            m.box((x,3.275,z),(1.7,.015,.035),'#6f8d9c',.005)
    for x in [-2.6,2.6]:
        m.box((x,2.45,0),(.15,.2,4.4),OCHRE)
    return m


def generator():
    m=Mesh()
    m.box((0,.15,0),(3,.3,2.5),DARK,.22)
    m.box((0,.8,0),(2.7,1.25,2.1),STEEL,.22)
    for x in [-.78,.78]:
        m.tube((x,.85,0),(x,2.25,0),.48,LIGHT,10,.35)
        for y in [1.15,1.55,1.95]:
            m.tube((x,y-.055,0),(x,y+.055,0),.5,DARK,10)
    m.box((0,2.35,0),(2.45,.3,1.35),LIGHT,.2)
    m.box((0,.95,1.07),(.8,.54,.08),DARK)
    m.box((0,1.02,1.12),(.55,.22,.04),CYAN)
    return m


def gate_post():
    m=Mesh()
    m.box((0,.18,0),(.7,.36,.7),DARK,.12)
    m.box((0,1.65,0),(.5,2.7,.5),LIGHT,.1)
    m.box((0,1.9,.26),(.3,.9,.05),STEEL)
    m.box((0,3.0,0),(.68,.4,.68),DARK,.1)
    for z in [-.345,.345]:m.box((0,3.05,z),(.48,.14,.02),CYAN,.005)
    return m


def wall():
    m=Mesh()
    m.loft([m.ring(3.3,.7,0,.12),m.ring(3.1,.45,1.4,.12)],STEEL)
    for x in [-1.15,-.4,.4,1.15]:
        for z in [-.28,.28]:m.box((x,.9,z),(.35,.22,.045),OCHRE)
    m.box((0,1.33,0),(2.9,.1,.38),LIGHT)
    return m


def landing_pad():
    m=Mesh()
    m.box((0,.015,0),(12,.03,12),DARK,1.3)
    for x in [-4.6,4.6]:m.box((x,.037,0),(.12,.01,8.9),WHITE,.005)
    for z in [-4.6,4.6]:m.box((0,.037,z),(9.2,.01,.12),WHITE,.005)
    for x in [-1,1]:m.box((x,.042,0),(.32,.01,3.4),OCHRE,.005)
    m.box((0,.042,0),(2.2,.01,.32),OCHRE,.005)
    for x in [-5.3,5.3]:
        for z in [-4,0,4]:m.box((x,.04,z),(.25,.02,.6),CYAN,.025)
    return m


def cargo():
    m=Mesh()
    m.box((0,1.2,0),(4.2,2.2,2.6),STEEL,.12)
    for y in [.12,2.28]:m.box((0,y,0),(4.4,.24,2.8),LIGHT,.14)
    for x in [-2.08,2.08]:
        for z in [-1.28,1.28]:m.box((x,1.2,z),(.24,2.2,.24),DARK)
    for x in [-1.65,-1.1,-.55,0,.55,1.1,1.65]:
        for z in [-1.32,1.32]:m.box((x,1.2,z),(.08,1.9,.06),'#83a1aa',.01)
    for x in [-2.12,2.12]:
        m.box((x,1.2,0),(.08,1.85,2.05),DARK)
        m.box((x,1.2,0),(.1,.045,2.08),LIGHT,.005)
        for z in [-.55,.55]:m.tube((x, .5,z),(x,1.9,z),.035,LIGHT,4)
    return m


def wreck_hull():
    m=Mesh()
    rings=[]
    for x,ry,rz in [(-5.5,.95,1.35),(-4.7,1.16,1.7),(3.5,1.16,1.7),(5.5,.6,1.1)]:
        rings.append([(x,1.3+math.sin(i*math.tau/10)*ry,math.cos(i*math.tau/10)*rz) for i in range(10)])
    m.loft(rings,STEEL,False,shades=[.8,.9,1.1,1.1,1,.9,.8,.8,.85,.9])
    m.face(rings[-1],DARK,(1,0,0))
    inner=[(-5.45,1.3+math.sin(i*math.tau/10)*.7,math.cos(i*math.tau/10)*1.0) for i in range(10)]
    m.face(inner,DARK,(-1,0,0))
    for x in [-4.7,-2,1,3.5]:
        for i in range(10):
            a=i*math.tau/10;b=(i+1)*math.tau/10
            m.tube((x,1.3+math.sin(a)*1.18,math.cos(a)*1.7),(x,1.3+math.sin(b)*1.18,math.cos(b)*1.7),.045,LIGHT,4)
    for x in [-3,0,2.5]:
        for z in [-1.68,1.68]:m.box((x,1.5,z),(1.6,.18,.03),OCHRE,.005)
    # Flatten the root below the buried keel without exceeding the old collider.
    m.box((0,.06,0),(7,.12,1.2),DARK)
    return m


def engine():
    m=Mesh()
    m.tube((0,1.4,-1.4),(0,1.4,1.15),1.22,DARK,12,1.38)
    m.tube((0,1.4,1.08),(0,1.4,1.4),1.38,LIGHT,12,1.1,False)
    for i in range(8):
        a=i*math.tau/8
        m.tube((math.cos(a)*.45,1.4+math.sin(a)*.45,1.25),(math.cos(a)*1.08,1.4+math.sin(a)*1.08,1.25),.05,STEEL,4)
    return m


def wing():
    m=Mesh()
    ring=[(-2.25,0,-2),(-.4,0,-2),(2.25,0,1.5),(1.8,0,2),(-2.25,0,1)]
    m.loft([ring,[(x,.4,z) for x,_,z in ring]],LIGHT)
    m.box((-1.8,.42,0),(.22,.05,2.8),OCHRE,.01)
    return m


def gantry_column():
    m=Mesh()
    m.box((0,.14,0),(.8,.28,.8),DARK,.1)
    for x in [-.24,.24]:
        for z in [-.24,.24]:m.tube((x,.2,z),(x,6.9,z),.08,LIGHT,4)
    for i in range(7):
        y=.35+i*.9
        for z in [-.24,.24]:m.tube((-.24,y,z),(.24,y+.8,z),.045,STEEL,4)
    m.box((0,6.9,0),(.8,.2,.8),OCHRE)
    return m


def gantry_beam():
    m=Mesh()
    for x in [-.3,.3]:
        for y in [.08,.42]:m.tube((x,y,-6.5),(x,y,6.5),.06,LIGHT,4)
        for i in range(13):m.tube((x,.08,-6.5+i),(x,.42,-5.5+i),.035,STEEL,4)
    m.box((0,.24,0),(.8,.4,1.1),OCHRE)
    return m


def obelisk():
    m=Mesh()
    m.box((0,.16,0),(1.7,.32,1.7),DARK,.24)
    m.loft([m.ring(1.55,1.5,.3,.3),m.ring(1.35,1.15,3.45,.3),m.ring(.95,.8,4,.2,x=-.1,z=.05)],STONE)
    for y,w in [(1.2,.48),(1.65,.16),(2.15,.38),(2.65,.14)]:
        m.box((0,y,.7),(w,.14,.035),CYAN,.01)
    return m


def terminal():
    m=Mesh()
    m.box((0,.12,0),(1.4,.24,1.4),DARK,.15)
    m.loft([m.ring(1.2,1.15,.24,.12),m.ring(1.05,.9,1.7,.12)],STEEL)
    m.box((0,1.735,0),(.8,.06,.62),CYAN)
    m.box((0,.8,.57),(.56,.25,.04),DARK)
    return m


def rock(seed=0):
    m=Mesh();r=random.Random(seed)
    rings=[]
    for y,radius in [(0,.32),(.17,.47),(.56,.44),(.84,.28),(1,.07)]:
        ring=[]
        for i in range(8):
            a=i*math.tau/8+.08*(seed % 3)
            length=radius*r.uniform(.8,1.05)
            ring.append((math.cos(a)*length,y if y in [0,1] else y+r.uniform(-.04,.04),math.sin(a)*length))
        rings.append(ring)
    m.loft(rings,STONE,shades=[.91,1.04,.86,.98,1.06,.92,.85,.97])
    return m


def arch():
    m=Mesh()
    for x in [-3.9,-1.3,1.3,3.9]:
        m.loft([m.ring(2.7,3.9,0,.32,x=x),m.ring(2.5,3.4,1.3,.45,x=x)],STONE)
    return m


def cave_back():
    m=Mesh()
    m.box((0,2.35,0),(6.5,4.7,.15),'#15242c',.2)
    return m


def flora():
    m=Mesh()
    m.tube((0,0,0),(0,1.25,0),.045,'#426b65',5,.025)
    for i in range(6):
        angle=i*math.tau/6
        radial=(math.cos(angle),0,math.sin(angle))
        side=(-math.sin(angle),0,math.cos(angle))
        centres=[mul(radial,.035),add(mul(radial,.16),(0,.58,0)),add(mul(radial,.38),(0,1.12+(i%2)*.14,0))]
        widths=[.03,.105,.012]
        front=[];back=[]
        for c,w in zip(centres,widths):
            front.append([add(add(c,mul(side,-w)),mul(radial,.012)),add(add(c,mul(side,w)),mul(radial,.012))])
            back.append([add(add(c,mul(side,-w)),mul(radial,-.012)),add(add(c,mul(side,w)),mul(radial,-.012))])
        for j in range(2):
            m.face([front[j][0],front[j][1],front[j+1][1],front[j+1][0]],'#5b978b',radial)
            m.face([back[j][0],back[j+1][0],back[j+1][1],back[j][1]],'#376e67',mul(radial,-1))
            for side_index in [0,1]:
                m.face([front[j][side_index],front[j+1][side_index],back[j+1][side_index],back[j][side_index]],'#467d73',mul(side,1 if side_index else -1))
        m.face([front[-1][0],front[-1][1],back[-1][1],back[-1][0]],CYAN,(0,1,0))
    m.tube((0,1.22,0),(0,1.4,0),.09,OCHRE,6,.035)
    return m


def build_models():
    pillar=rock(41)
    pillar.positions=[(x*3.5,y*6,z*4) for x,y,z in pillar.positions]
    # Transform normals correctly under a nonuniform model-space scale.
    pillar.normals=[unit((x/3.5,y/6,z/4)) for x,y,z in pillar.normals]
    models={'habitat':habitat(),'generator':generator(),'gate_post':gate_post(),'wall':wall(),
            'landing_pad':landing_pad(),'cargo':cargo(),'wreck_hull':wreck_hull(),'wreck_engine':engine(),
            'wreck_wing':wing(),'gantry_column':gantry_column(),'gantry_beam':gantry_beam(),
            'obelisk':obelisk(),'terminal':terminal(),'cave_pillar':pillar,'cave_arch':arch(),'cave_back':cave_back(),
            'rock_a':rock(7),'rock_b':rock(19),'rock_c':rock(31),'flora_rosette':flora()}
    sizes={'habitat':(6,3.2,6),'generator':(3,2.5,2.5),'gate_post':(.7,3.2,.7),'wall':(3.3,1.4,.7),
           'landing_pad':(12,.05,12),'cargo':(4.4,2.4,2.8),'wreck_hull':(11,2.5,3.4),'wreck_engine':(2.8,2.8,2.8),
           'wreck_wing':(4.5,.45,4),'gantry_column':(.8,7,.8),'gantry_beam':(.8,.5,13),'obelisk':(1.7,4,1.7),
           'terminal':(1.4,1.7,1.4),'cave_pillar':(3.5,6,4),'cave_arch':(10.5,1.3,4),'cave_back':(6.5,4.7,.15),
           'rock_a':(1,1,1),'rock_b':(1,1,1),'rock_c':(1,1,1),'flora_rosette':(.8,1.4,.8)}
    for name,mesh in models.items():
        lo,hi=mesh.bounds();w,h,d=sizes[name]
        scale=(min(1,w/(2*max(abs(lo[0]),abs(hi[0])))),min(1,h/(hi[1]-lo[1])),min(1,d/(2*max(abs(lo[2]),abs(hi[2])))))
        mesh.positions=[(x*scale[0],(y-lo[1])*scale[1],z*scale[2]) for x,y,z in mesh.positions]
        mesh.normals=[unit((x/scale[0],y/scale[1],z/scale[2])) for x,y,z in mesh.normals]
    return models


def main():
    parser=argparse.ArgumentParser()
    parser.add_argument('--check',action='store_true')
    parser.add_argument('--preview',action='store_true')
    args=parser.parse_args()
    models=build_models()
    manifest={'version':1,'coordinates':'Y-up, metres, bottom-centre origin','source':'Authored in this repository; no external assets or textures','assets':{}}
    for name,mesh in models.items():
        raw=mesh.glb(name)
        file=DEST/(name+'.glb')
        if args.check:
            if not file.exists() or file.read_bytes()!=raw:raise SystemExit('ASSET_REGEN_MISMATCH: '+str(file))
        else:
            DEST.mkdir(parents=True,exist_ok=True)
            file.write_bytes(raw)
        manifest['assets'][name]={'file':name+'.glb','triangles':len(mesh.positions)//3,'bounds':mesh.bounds(),'bytes':len(raw),'sha256':hashlib.sha256(raw).hexdigest()}
    encoded=json.dumps(manifest,indent=2,sort_keys=True)+'\n'
    target=DEST/'manifest.json'
    if args.check:
        if target.read_text()!=encoded:raise SystemExit('ASSET_MANIFEST_MISMATCH')
    else:target.write_text(encoded)
    if args.preview:
        from render_environment_kit import render
        render(models,ART/'contact_sheet.png')
    print('ENVIRONMENT_KIT_CHECK_PASS' if args.check else 'ENVIRONMENT_KIT_BUILT', 'assets='+str(len(models)), 'triangles='+str(sum(len(m.positions)//3 for m in models.values())))


if __name__=='__main__':main()
