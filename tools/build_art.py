"""Original Blender models and synthesized audio for Rainfall.
Run with Blender --background --python tools/build_art.py.
Coordinates here use Blender Z up; GLB maps this to Godot Y up.
"""
import bpy
import math
import random
import wave
from pathlib import Path
from mathutils import Vector
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
MODELS = ROOT / "assets/models"
SOURCE = ROOT / "art/source"
TEX = ROOT / "assets/textures"
AUDIO = ROOT / "assets/audio"
rng = random.Random(8146)
for p in (MODELS, SOURCE, TEX, AUDIO):
    p.mkdir(parents=True, exist_ok=True)
bpy.ops.object.select_all(action="SELECT")
bpy.ops.object.delete(use_global=False)

def material(name, color, rough=.6, metallic=0):
    m = bpy.data.materials.new(name)
    m.diffuse_color = (*color, 1)
    m.use_nodes = True
    m.node_tree.nodes.clear()
    bs = m.node_tree.nodes.new("ShaderNodeBsdfPrincipled")
    output = m.node_tree.nodes.new("ShaderNodeOutputMaterial")
    m.node_tree.links.new(bs.outputs[0], output.inputs[0])
    bs.inputs["Base Color"].default_value = (*color, 1)
    bs.inputs["Roughness"].default_value = rough
    bs.inputs["Metallic"].default_value = metallic
    return m

wood = material("Wet_Honey_Wood", (.45, .265, .105), .27)
walnut = material("Walnut_Frame", (.072, .043, .022), .24)
gold = material("Aged_Brass", (.48, .32, .12), .29, .7)
ink = material("Grid_Ink", (.045, .027, .018), .57)
black = material("Obsidian_Stone", (.009, .020, .020), .17, .15)
white = material("Moon_Jade_Stone", (.78, .86, .77), .2, .06)
slate = material("Rain_Slate", (.085, .13, .115), .36)
rock = material("River_Rock", (.15, .19, .16), .52)
moss = material("Velvet_Moss", (.11, .20, .085), .89)
bark = material("Pine_Bark", (.08, .105, .077), .85)
bamboo_mat = material("Bamboo_Jade", (.07, .17, .075), .4)
leaf_mats = [material("Leaf_%d" % i, c, .82) for i, c in enumerate([
    (.035, .09, .051), (.06, .16, .072), (.105, .23, .102),
    (.15, .28, .11), (.07, .19, .14)])]
ground = material("Forest_Floor", (.055, .09, .065), .76)
lamp = material("Lantern_Amber", (.9, .4, .095), .5)
bs = next(n for n in lamp.node_tree.nodes if n.type == "BSDF_PRINCIPLED")
bs.inputs["Emission Color"].default_value = (1, .45, .12, 1)
bs.inputs["Emission Strength"].default_value = 2

# Continuous maple grain, baked into a portable image used by both Blender and Godot.
n = 1024
yy, xx = np.mgrid[0:n, 0:n].astype(np.float32) / n
grain = np.sin(xx * 490 + 8*np.sin(yy*9) + 4*np.sin(xx*28 + yy*3))
fine = np.sin(xx*1900 + np.sin(yy*47)*3)
cloud = np.sin(xx*7 + np.sin(yy*5))*np.sin(yy*13+xx*4)
g = .045*grain + .018*fine + .038*cloud
rgb = np.stack([.61+g, .40+g*.8, .21+g*.5, np.ones_like(g)], axis=-1)
im = bpy.data.images.new("Maple_Grain", n, n)
im.pixels.foreach_set(np.clip(rgb,0,1).ravel())
im.filepath_raw = str(TEX / "maple.png")
im.file_format = "PNG"
im.save()
nt = wood.node_tree
tex = nt.nodes.new("ShaderNodeTexImage")
tex.image = im
nt.links.new(tex.outputs["Color"], next(n for n in nt.nodes if n.type == "BSDF_PRINCIPLED").inputs["Base Color"])

def box(name, loc, dims, mat, bevel=0):
    bpy.ops.mesh.primitive_cube_add(size=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.dimensions = dims
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    if bevel:
        b = o.modifiers.new("Crafted rounded edges", "BEVEL")
        b.width = bevel
        b.segments = 3
        o.modifiers.new("Weighted normals", "WEIGHTED_NORMAL")
    return o

def sphere(name, loc, scale, mat, segments=32, rings=16):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=segments, ring_count=rings, radius=1, location=loc)
    o = bpy.context.object
    o.name = name
    o.scale = scale
    bpy.ops.object.transform_apply(location=False, rotation=False, scale=True)
    o.data.materials.append(mat)
    for f in o.data.polygons: f.use_smooth=True
    return o

def mesh(name, verts, faces, mat, smooth=False):
    m=bpy.data.meshes.new(name)
    m.from_pydata(verts, [], faces)
    m.update()
    o=bpy.data.objects.new(name,m)
    bpy.context.collection.objects.link(o)
    m.materials.append(mat)
    if smooth:
        for f in m.polygons: f.use_smooth=True
    return o

def lathe(name, profile, loc, mat, count=64):
    vs=[]; fs=[]
    for r,z in profile:
        vs.extend([(loc[0]+r*math.cos(a*math.tau/count),
                    loc[1]+r*math.sin(a*math.tau/count),loc[2]+z) for a in range(count)])
    for j in range(len(profile)-1):
        for i in range(count):
            a=j*count+i;b=j*count+(i+1)%count
            fs.append((a,b,b+count,a+count))
    return mesh(name,vs,fs,mat,True)

def export_selected(path, objects):
    bpy.ops.object.select_all(action="DESELECT")
    for o in objects: o.select_set(True)
    bpy.context.view_layer.objects.active=objects[0]
    bpy.ops.export_scene.gltf(filepath=str(path), export_format="GLB",
        use_selection=True, export_apply=True, export_cameras=False, export_lights=False)

heroes=[]
for name,mat in (("black_stone",black),("white_stone",white)):
    o=sphere(name, (0,0,.088), (.211,.211,.097), mat,48,24)
    export_selected(MODELS/(name+".glb"),[o])
    heroes.append(o)
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"stones.blend"))
for o in heroes: bpy.data.objects.remove(o,do_unlink=True)

# A crafted kaya-wood board, separate top for the live wet-surface shader.
box("Walnut_Underbody",(0,0,.245),(8.08,8.08,.51),walnut,.12)
box("Board_Surface",(0,0,.575),(7.91,7.91,.15),wood,.06)
for x,y in [(-3.1,-3.1),(3.1,-3.1),(3.1,3.1),(-3.1,3.1)]:
    box("Carved_Foot",(x,y,-.16),(.48,.48,.4),walnut,.085)
for i in range(15):
    v=(i-7)*.46
    box("Grid_%02d_X"%i,(0,v,.654),(6.47,.012,.008),ink)
    box("Grid_%02d_Y"%i,(v,0,.654),(.012,6.47,.008),ink)
for x,y in [(3,3),(3,11),(7,7),(11,3),(11,11)]:
    lathe("Star_Point",[(0,.002),(.046,.002),(.046,.006),(0,.006)],
        ((x-7)*.46,(y-7)*.46,.658),ink,24)
for s in (-1,1):
    box("Brass_Edge",(0,s*3.85,.659),(7.71,.014,.009),gold)
    box("Brass_Edge",(s*3.85,0,.659),(.014,7.71,.009),gold)
    box("Frame_Inlay",(0,s*4.041,.25),(7.66,.01,.013),gold)
    box("Frame_Inlay",(s*4.041,0,.25),(.01,7.66,.013),gold)
for x in (-3.66,3.66):
    for y in (-3.66,3.66):
        for angle in (0,math.pi/2):
            o=box("Corner_Filigree",(x,y,.66),(.22,.013,.012),gold,.005)
            o.rotation_euler.z=angle
        lathe("Corner_Rivet",[(0,0),(.026,0),(.026,.008),(0,.014)],(x,y,.66),gold,20)

# Stone terrace: broad circular slab with radial joints, inset wood seating.
lathe("Terrace",[(0,-.65),(6.85,-.65),(6.55,-.54),(6.55,-.42),(0,-.42)],
    (0,0,0),slate,96)
for i in range(18):
    a=i*math.tau/18
    o=box("Terrace_Joint",(5.9*math.cos(a),5.9*math.sin(a),-.41),(1.22,.018,.012),ink)
    o.rotation_euler.z=a
for x in [-4.98,4.98]:
    profile=[(0,0),(.42,0),(.59,.1),(.70,.35),(.72,.48),(.69,.54),
             (.63,.53),(.59,.35),(.43,.14),(0,.12)]
    lathe("Stone_Bowl",profile,(x,-1.8,-.40),walnut)
    lathe("Bowl_Golden_Lip",[(.685,.492),(.716,.5),(.701,.515)],(x,-1.8,-.40),gold)
    mat=black if x<0 else white
    for i in range(21):
        a=rng.random()*math.tau;r=.50*math.sqrt(rng.random())
        o=sphere("Bowl_Stones",(x+r*math.cos(a),-1.8+r*math.sin(a),.0+rng.random()*.15),
                 (.16,.16,.075),mat,16,8)
        o.rotation_euler=(rng.uniform(-.3,.3),rng.uniform(-.3,.3),rng.random()*6)

def lantern(x,y):
    box("Lantern_Plinth",(x,y,-.15),(.76,.76,.48),slate,.07)
    box("Lantern_Stem",(x,y,.31),(.28,.28,.48),slate,.035)
    box("Lantern_Tray",(x,y,.57),(.73,.73,.14),slate,.04)
    box("Lantern_Light",(x,y,.86),(.42,.42,.45),lamp,.025)
    for dx in [-.28,.28]:
        for dy in [-.28,.28]: box("Lantern_Post",(x+dx,y+dy,.88),(.055,.055,.5),walnut,.008)
    # Two-tier traditional overhanging roof.
    for z,w in [(1.2,.92),(1.31,.68)]:
        vs=[(x-w/2,y-w/2,z),(x+w/2,y-w/2,z),(x+w/2,y+w/2,z),(x-w/2,y+w/2,z),
            (x,y,z+.22)]
        mesh("Lantern_Roof",vs,[(0,1,4),(1,2,4),(2,3,4),(3,0,4),(3,2,1,0)],slate)
    sphere("Lantern_Finial",(x,y,1.57),(.065,.065,.08),gold,16,8)
lantern(-5.28,3.6);lantern(5.28,3.6)

parts={}
def group(mat):
    if mat.name not in parts: parts[mat.name]=[[],[],mat]
    return parts[mat.name]
def tube(a,b,r1,r2,mat,sides=8):
    verts,faces,_=group(mat);off=len(verts)
    a=Vector(a);b=Vector(b);up=(b-a).normalized()
    side=up.cross(Vector((0,1,0)))
    if side.length<.01: side=up.cross(Vector((1,0,0)))
    side.normalize();other=up.cross(side)
    for pos,r in [(a,r1),(b,r2)]:
        for i in range(sides):
            p=pos+r*(side*math.cos(math.tau*i/sides)+other*math.sin(math.tau*i/sides))
            verts.append(tuple(p))
    for i in range(sides): faces.append((off+i,off+(i+1)%sides,off+(i+1)%sides+sides,off+i+sides))
    faces.append(tuple(off+sides+i for i in range(sides)))

def leaf(p,d,length,width,mat):
    vs,fs,_=group(mat);off=len(vs)
    p=Vector(p);d=Vector(d).normalized()
    side=d.cross(Vector((0,0,1)))
    if side.length<.05: side=Vector((1,0,0))
    side.normalize()
    tip=p+d*length+Vector((0,0,-length*.12))
    mid=p+d*length*.47
    vs.extend([tuple(p),tuple(mid-side*width),tuple(mid+Vector((0,0,width*.4))),
               tuple(mid+side*width),tuple(tip)])
    fs.extend([(off,off+1,off+2),(off,off+2,off+3),
               (off+1,off+4,off+2),(off+2,off+4,off+3)])

def tree(x,y,height,seed):
    rr=random.Random(seed)
    bend=Vector((rr.uniform(-.7,.7),rr.uniform(-.7,.7),0))
    points=[Vector((x,y,-.6))+Vector((0,0,height*t))+bend*t*t for t in [0,.28,.52,.72,.9,1]]
    for i in range(5): tube(points[i],points[i+1],.33*(1-i*.17),.33*(1-(i+1)*.17),bark,10)
    # Root flares.
    for i in range(6):
        a=i*math.tau/6+rr.random()
        tube((x,y,-.05),(x+math.cos(a)*.85,y+math.sin(a)*.85,-.58),.12,.026,bark,7)
    for j in range(11):
        t=.38+j*.048
        origin=Vector((x,y,height*t-.6))+bend*t*t
        a=j*2.4+rr.random()
        spread=(1.0-t)*3.8+rr.random()*.35
        end=origin+Vector((math.cos(a)*spread,math.sin(a)*spread,.4+rr.random()*.8))
        tube(origin,end,.10*(1-t),.018,bark,7)
        for k in range(100):
            phi=rr.random()*math.tau; radius=math.sqrt(rr.random())*spread*.7
            p=end+Vector((math.cos(phi)*radius,math.sin(phi)*radius,rr.uniform(-.18,.65)))
            leaf(p,(math.cos(phi),math.sin(phi),rr.uniform(-.25,.4)),
                 rr.uniform(.22,.58),rr.uniform(.06,.14),leaf_mats[rr.randrange(5)])
            if k%5==0:
                tube(end,p,.012,.003,bark,5)

treepos=[]
for i in range(47):
    x=rng.uniform(-20,20);y=rng.uniform(7,29)
    treepos.append((x,y,rng.uniform(6.5,15),100+i))
for s in (-1,1):
    for i in range(9):
        treepos.append((s*rng.uniform(7.4,17),rng.uniform(-11,7),rng.uniform(8,14),400+i+int(s*20)))
for args in treepos: tree(*args)

# Bamboo groves frame the clearing.
for side in (-1,1):
    for i in range(19):
        x=side*rng.uniform(6.8,12);y=rng.uniform(-3,14)
        h=rng.uniform(4,9);tilt=Vector((rng.uniform(-.7,.7),rng.uniform(-.5,.5),0))
        for j in range(int(h/.65)):
            a=Vector((x,y,-.6+j*.65))+tilt*j*.65/h
            b=Vector((x,y,-.6+(j+1)*.65))+tilt*(j+1)*.65/h
            tube(a,b,.075,.065,bamboo_mat,8)
            tube(b-Vector((0,0,.025)),b+Vector((0,0,.025)),.084,.084,moss,8)
            if j>3 and j%2==0:
                direction=Vector((side*rng.uniform(-1,1),rng.uniform(-1,1),.25))
                tip=b+direction*1.1
                tube(b,tip,.015,.004,bamboo_mat,6)
                for k in range(12):
                    p=b+(tip-b)*k/12
                    a2=rng.random()*math.tau
                    leaf(p,(math.cos(a2),math.sin(a2),-.3),rng.uniform(.35,.6),.045,leaf_mats[2])

# Ferns and rain-polished rocks around the terrace.
for i in range(87):
    a=rng.random()*math.tau;r=rng.uniform(7.1,16)
    x=r*math.cos(a);y=r*math.sin(a)
    if i<20:
        x=rng.choice([-1,1])*rng.uniform(5.8,8);y=rng.uniform(-7,-3)
    size=rng.uniform(.24,.88)
    if i%2==0:
        bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=2,radius=1,location=(x,y,-.4))
        o=bpy.context.object;o.name="Mossy_River_Stone"
        o.scale=(size,size*.74,size*.6);o.rotation_euler.z=rng.random()*6
        o.data.materials.append(rock)
        for v in o.data.vertices: v.co*=rng.uniform(.90,1.10)
        for f in o.data.polygons: f.use_smooth=True
        sphere("Moss_Cap",(x-.08,y,-.4+size*.48),(size*.80,size*.55,.055),moss,12,6)
    for j in range(6):
        angle=j*math.tau/6+rng.random()*.5
        length=rng.uniform(.45,1.1)
        start=Vector((x,y,-.53))
        for k in range(9):
            t=k/9
            p=start+Vector((math.cos(angle)*t*length,math.sin(angle)*t*length,math.sin(t*2.2)*length*.55))
            for sign in (-1,1):
                d=(math.cos(angle+sign*.8),math.sin(angle+sign*.8),-.13)
                leaf(p,d,(1-t)*length*.35,.045*(1-t)+.008,leaf_mats[2+(j%2)])


N=54;vs=[];fs=[]
for y in range(N):
    for x in range(N):
        px=(x/(N-1)-.5)*85;py=(y/(N-1)-.5)*85
        z=-.69+(.06*math.sin(px*.7)*math.cos(py*.8) if px*px+py*py<50 else .21*math.sin(px*.24)*math.cos(py*.32))
        vs.append((px,py,z))
for y in range(N-1):
    for x in range(N-1):
        a=y*N+x;fs.append((a,a+1,a+1+N,a+N))
mesh("Forest_Ground",vs,fs,ground,True)

# Fallen brass-green leaves on the outer terrace, outside the playable board.
for i in range(85):
    x=rng.uniform(-6,6);y=rng.uniform(-6,6)
    if abs(x)<4.2 and abs(y)<4.2: continue
    a=rng.random()*math.tau
    leaf((x,y,-.39),(math.cos(a),math.sin(a),.02),rng.uniform(.13,.30),.055,leaf_mats[3])
# Group each material into an editable foliage mesh, including the fallen leaves.

for name,(vs,fs,mat) in parts.items():
    mesh(name+"_Grove",vs,fs,mat,smooth="Bark" in name or "Bamboo" in name)


all_objects=[o for o in bpy.context.scene.objects if o.type=="MESH"]
bpy.context.scene.world.color=(.13,.19,.17)
bpy.ops.object.camera_add(location=(0,-12,12))
camera=bpy.context.object;camera.name="Art_Overview"
camera.rotation_euler=(Vector((0,0,0))-camera.location).to_track_quat("-Z","Y").to_euler()
bpy.context.scene.camera=camera
bpy.ops.object.light_add(type="AREA",location=(0,-2,10))
bpy.context.object.data.energy=1800;bpy.context.object.data.shape="DISK";bpy.context.object.data.size=9
bpy.context.scene.render.engine="CYCLES"
bpy.context.scene.cycles.samples=32
bpy.ops.wm.save_as_mainfile(filepath=str(SOURCE/"rainfall_sanctuary.blend"))
export_selected(MODELS/"sanctuary.glb",all_objects)
print("BLENDER_ART_OK",len(all_objects),"objects")

def wav(name,values,sr=22050):
    values=np.clip(values,-.95,.95)
    channels=1 if values.ndim==1 else values.shape[1]
    with wave.open(str(AUDIO/(name+".wav")),"wb") as f:
        f.setnchannels(channels);f.setsampwidth(2);f.setframerate(sr)
        f.writeframes((values*32767).astype("<i2").tobytes())

nr=np.random.default_rng(714)
sr=22050
duration=24
count=sr*duration
freq=np.fft.rfftfreq(count,1/sr)
def colored_noise():
    spectrum=np.fft.rfft(nr.standard_normal(count))
    filt=(np.maximum(freq,80)/180)**(-.4)
    filt*=np.minimum(freq/130,1)*np.exp(-freq/11000)
    a=np.fft.irfft(spectrum*filt,n=count)
    return a/np.std(a)*.13
rain=np.stack([colored_noise(),colored_noise()],axis=-1)
tt=np.arange(count)/sr
rain*= (1+.12*np.sin(tt*math.tau/duration)+.05*np.sin(tt*6*math.tau/duration))[:,None]
for i in range(350):
    at=nr.integers(0,count-2000);ln=nr.integers(100,900);t=np.arange(ln)/sr
    drop=np.sin(2*math.pi*(1300+nr.random()*3400)*t)*np.exp(-t*nr.uniform(100,230))*.035
    rain[at:at+ln,nr.integers(0,2)]+=drop
wav("rain",rain)

music=np.zeros((count,2))
for i,f in enumerate([110,164.8138,220,293.6648,329.6276]):
    envelope=(.7+.3*np.sin(tt*math.tau/duration+i))
    tone=(np.sin(math.tau*f*tt)+.19*np.sin(math.tau*f*2.002*tt))
    music+=np.stack([tone*envelope,tone*np.roll(envelope,2200)],axis=-1)*.012
for i in range(12):
    at=i*2*sr;f=[440,587.33,659.25,880,987.77][i%5]
    t=np.arange(min(sr*5,count-at))/sr
    note=(np.sin(math.tau*f*t)+.25*np.sin(math.tau*f*2.01*t)+.08*np.sin(math.tau*f*3.97*t))
    note*=np.exp(-t*1.3)*(1-np.exp(-t*70))*.05
    music[at:at+len(note),i%2]+=note
fade=np.minimum(np.minimum(tt,24-tt)*.4,1)
wav("forest_harmonics",music*fade[:,None])
# Placement sounds are real Yunzi recordings, rebuilt separately by build_audio.py.
t=np.arange(sr*1.4)/sr
wav("bow",np.sin(math.tau*(150*t+450*t*t))*.20*np.exp(-t*3)+nr.normal(size=len(t))*.12*np.exp(-t*5))
t=np.arange(sr*3)/sr
wav("moon",sum(np.sin(math.tau*f*t) for f in [440,660,880,1100])*.055*np.exp(-t*1.1)*(1-np.exp(-t*20)))
wav("cosmos",(np.sin(math.tau*(65*t-7*t*t))*.28+np.sin(math.tau*130*t)*.12+nr.normal(size=len(t))*.06)*np.exp(-t*.9)*(1-np.exp(-t*10)))
t=np.arange(sr*3.5)/sr
wav("victory",sum(np.sin(math.tau*f*t)*np.exp(-t*(.8+j*.15)) for j,f in enumerate([220,330,440,550,660]))*.055*(1-np.exp(-t*32)))
print("AUDIO_OK")
