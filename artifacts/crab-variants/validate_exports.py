"""Validate and render the delivered FBX files in a clean Blender process."""
import bpy
import bmesh
import json
import hashlib
import math
import sys
from pathlib import Path
from mathutils import Vector
from io_scene_fbx import parse_fbx

ROOT=Path(r"C:\Grab a Crab")
OUT=ROOT/"Crabmodels"
PREVIEWS=OUT/"Previews"
PREVIEWS.mkdir(exist_ok=True)
manifest=json.loads((OUT/"manifest.json").read_text())
only=sys.argv[sys.argv.index("--")+1:] if "--" in sys.argv else []
report=json.loads((OUT/"validation.json").read_text()) if only else []
if only:manifest=[item for item in manifest if item["name"] in only]

def require(condition,message):
    if not condition:raise AssertionError(message)

def enum(obj,prop,value):
    choices=[i.identifier for i in obj.bl_rna.properties[prop].enum_items]
    require(value in choices,f"{prop}: {value} unavailable: {choices}")
    setattr(obj,prop,value)

def render_preview(name):
    scene=bpy.context.scene
    # The factory default uses EEVEE; select the installed EEVEE identifier if needed.
    if "EEVEE" not in scene.render.engine:
        try:scene.render.engine="BLENDER_EEVEE"
        except TypeError as ex:raise RuntimeError(f"EEVEE unavailable: {ex}")
    scene.render.resolution_x=640;scene.render.resolution_y=560;scene.render.resolution_percentage=100
    enum(scene.render.image_settings,"file_format","PNG")
    enum(scene.render.image_settings,"color_mode","RGB")
    scene.render.film_transparent=False
    world=bpy.data.worlds.new("Preview World");world.use_nodes=True
    bg=next(n for n in world.node_tree.nodes if n.type=="BACKGROUND")
    bg.inputs["Color"].default_value=(.18,.22,.3,1);bg.inputs["Strength"].default_value=.4;scene.world=world
    camera=bpy.data.cameras.new("Preview Camera");enum(camera,"type","ORTHO");camera.ortho_scale=4.9
    obj=bpy.data.objects.new("Preview Camera",camera);scene.collection.objects.link(obj)
    obj.location=(5,-7,5.5);obj.rotation_euler=(Vector((0,0,.75))-obj.location).to_track_quat('-Z','Y').to_euler();scene.camera=obj
    for nm,loc,power,size in [("Key",(-3,-4,7),650,5),("Fill",(4,-1,4),380,4),("Rim",(1,4,6),800,3)]:
        data=bpy.data.lights.new(nm,"AREA");data.energy=power;data.shape="DISK";data.size=size
        lamp=bpy.data.objects.new(nm,data);scene.collection.objects.link(lamp);lamp.location=loc
        lamp.rotation_euler=(Vector((0,0,.6))-lamp.location).to_track_quat('-Z','Y').to_euler()
    mesh=bpy.data.meshes.new("Ground");mesh.from_pydata([(-200,-200,-.015),(200,-200,-.015),(200,200,-.015),(-200,200,-.015)],[],[(0,1,2,3)])
    floor=bpy.data.objects.new("Ground",mesh);scene.collection.objects.link(floor)
    mat=bpy.data.materials.new("Ground");mat.use_nodes=True
    shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
    shader.inputs["Base Color"].default_value=(.045,.061,.09,1);shader.inputs["Roughness"].default_value=.8;mesh.materials.append(mat)
    scene.render.filepath=str(PREVIEWS/(name+".png"))
    bpy.ops.render.render(write_still=True)

for item in manifest:
    name=item["name"]
    bpy.ops.wm.read_factory_settings(use_empty=True)
    png=(OUT/item["texture"]).read_bytes();digest=hashlib.sha256(png).hexdigest()
    root,version=parse_fbx.parse(str(OUT/item["fbx"]))
    embedded=[]
    for container in root.elems:
        if container.id==b"Objects":
            for e in container.elems:
                if e.id==b"Video":
                    embedded.extend(c.props[0] for c in e.elems if c.id==b"Content" and c.props)
    require(len(embedded)==1,f"{name}: expected one embedded PNG")
    require(hashlib.sha256(embedded[0]).hexdigest()==digest,f"{name}: embedded image differs from delivered PNG")
    bpy.ops.import_scene.fbx(filepath=str(OUT/item["fbx"]),use_image_search=False,use_anim=False)
    meshes=[o for o in bpy.context.scene.objects if o.type=="MESH"]
    require(len(meshes)==28,f"{name}: incorrect mesh count")
    maxtris=0;total=0;bounds=[];uvzero=0;nonmanifold=0
    for obj in meshes:
        require(obj.name.startswith(name+"_"),f"{name}: unexpected mesh name {obj.name}")
        require(len(obj.data.materials)==1,f"{obj.name}: must use one material per mesh")
        require(len(obj.data.uv_layers)>0,f"{obj.name}: missing UVs")
        mat=obj.data.materials[0];require(mat.use_nodes,f"{obj.name}: no material graph")
        shader=next(n for n in mat.node_tree.nodes if n.type=="BSDF_PRINCIPLED")
        links=shader.inputs["Base Color"].links
        require(len(links)==1 and links[0].from_node.type=="TEX_IMAGE",f"{obj.name}: image not directly connected to color")
        image=links[0].from_node.image
        require(image and image.has_data and tuple(image.size)==(1024,1024),f"{obj.name}: missing texture pixels")
        require(image.packed_file is not None,f"{obj.name}: importer did not recover embedded texture")
        require(hashlib.sha256(image.packed_file.data).hexdigest()==digest,f"{obj.name}: imported image data mismatch")
        obj.data.calc_loop_triangles();triangles=obj.data.loop_triangles
        total+=len(triangles);maxtris=max(maxtris,len(triangles))
        require(len(triangles)<20000,f"{obj.name}: mesh exceeds triangle budget")
        uv=obj.data.uv_layers.active.data
        for tri in triangles:
            a,b,c=[uv[i].uv for i in tri.loops]
            area=abs((b.x-a.x)*(c.y-a.y)-(b.y-a.y)*(c.x-a.x))
            if area<1e-12:uvzero+=1
        bm=bmesh.new();bm.from_mesh(obj.data)
        nonmanifold+=sum(not e.is_manifold for e in bm.edges);bm.free()
        bounds.extend(obj.matrix_world@Vector(v) for v in obj.bound_box)
    require(uvzero==0,f"{name}: {uvzero} triangles have collapsed UVs")
    require(nonmanifold==0,f"{name}: {nonmanifold} non-manifold edges")
    lo=[min(v[i] for v in bounds) for i in range(3)];hi=[max(v[i] for v in bounds) for i in range(3)]
    require(abs((lo[0]+hi[0])/2)<.001 and abs((lo[1]+hi[1])/2)<.001,f"{name}: grid layout leaked into export")
    require(abs(lo[2])<.001,f"{name}: model is not grounded")
    require(total==item["triangles"],f"{name}: triangle count changed on export")
    result={"name":name,"status":"passed","mesh_count":len(meshes),"triangles":total,"largest_mesh_triangles":maxtris,
            "embedded_png_sha256":digest,"imported_packed_texture_matches":True,"zero_area_uv_triangles":uvzero,
            "nonmanifold_edges":nonmanifold,"dimensions":[round(hi[i]-lo[i],4) for i in range(3)]}
    report=[r for r in report if r["name"]!=name]+[result]
    (OUT/"validation.json").write_text(json.dumps(report,indent=2))
    print("VALIDATED "+json.dumps(result),flush=True)
    render_preview(name)

print(f"{len(manifest)} EXPORTED CRABS VALIDATED AND RENDERED",flush=True)
