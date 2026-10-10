"""Build the clothed, skinned athlete from the MakeHuman CC0 base mesh.
Run: blender --background --python tools/build_athlete.py
No MakeHuman program code is used. Asset source and CC0 notice are included.
"""
from pathlib import Path
import bpy, gzip, math
from mathutils import Vector

ROOT = Path(__file__).resolve().parent.parent
vertices, faces, groups, texcoords, face_uv = [], [], {}, [], []
group = ''
for line in gzip.decompress((ROOT/'tools/source/human-base.obj.gz').read_bytes()).decode().splitlines():
    fields=line.split()
    if not fields: continue
    if fields[0]=='v': vertices.append(Vector(tuple(map(float, fields[1:4]))))
    elif fields[0]=='vt': texcoords.append(tuple(map(float, fields[1:3])))
    elif fields[0]=='g': group=fields[1]; groups.setdefault(group, [])
    elif fields[0]=='f':
        indices=[int(f.split('/')[0])-1 for f in fields[1:]]
        groups[group].extend(indices)
        if group=='body':
            faces.append(indices)
            face_uv.append([int(f.split('/')[1])-1 for f in fields[1:]])

body_indices=sorted(set(i for face in faces for i in face))
minimum=min(vertices[i].y for i in body_indices)
scale=1.79/(max(vertices[i].y for i in body_indices)-minimum)
def convert(p): return Vector((p.x*scale, p.z*scale, (p.y-minimum)*scale+0.035))
def joint(name):
    indices=set(groups['joint-'+name])
    return convert(sum((vertices[i] for i in indices), Vector())/len(indices))
points={i:convert(vertices[i]) for i in body_indices}
# Athletic proportions, a flatter chest and a relaxed, masculine garment silhouette.
for p in points.values():
    if 1.02<p.z<1.51:
        p.x*=1.07
        if 1.2<p.z<1.48 and p.y>0.08: p.y=min(p.y,0.122)

bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
arm_data=bpy.data.armatures.new('AthleteRig')
rig=bpy.data.objects.new('AthleteRig',arm_data)
bpy.context.collection.objects.link(rig); bpy.context.view_layer.objects.active=rig
rig.select_set(True); bpy.ops.object.mode_set(mode='EDIT')
bones={}
def bone(name, head, tail, parent=None):
    b=arm_data.edit_bones.new(name); b.head=head; b.tail=tail
    if parent: b.parent=arm_data.edit_bones[parent]
    bones[name]=(Vector(head),Vector(tail)); return b
bone('Root',(0,0,0),(0,0,.2))
pelvis=joint('pelvis'); neck=Vector((0,.013,1.505))
bone('Pelvis',pelvis,(0,.005,1.13),'Root')
bone('Spine',(0,.005,1.13),(0,.003,1.345),'Pelvis')
bone('Chest',(0,.003,1.345),neck,'Spine')
bone('Neck',neck,(0,.012,1.58),'Chest')
bone('Head',(0,.012,1.58),(0,.025,1.81),'Neck')
for side,letter in [('l','L'),('r','R')]:
    shoulder,elbow,hand=joint(side+'-shoulder'),joint(side+'-elbow'),joint(side+'-hand')
    hip,knee,ankle=joint(side+'-upper-leg'),joint(side+'-knee'),joint(side+'-ankle')
    bone('UpperArm.'+letter,shoulder,elbow,'Chest')
    bone('LowerArm.'+letter,elbow,hand,'UpperArm.'+letter)
    bone('Hand.'+letter,hand,hand+Vector((0,.11,-.02)),'LowerArm.'+letter)
    bone('Thigh.'+letter,hip,knee,'Pelvis')
    bone('Shin.'+letter,knee,ankle,'Thigh.'+letter)
    bone('Foot.'+letter,ankle,ankle+Vector((0,.17,-.035)),'Shin.'+letter)
bpy.ops.object.mode_set(mode='OBJECT'); rig.select_set(False)
materials={}
def material(name,color,roughness=.75):
    mat=bpy.data.materials.new(name); mat.diffuse_color=(*color,1); mat.use_nodes=True
    shader=mat.node_tree.nodes.get('Principled BSDF')
    shader.inputs['Base Color'].default_value=(*color,1); shader.inputs['Roughness'].default_value=roughness
    materials[name]=mat; return mat
material('Skin',(.49,.30,.20),.5); material('Hands',(.49,.30,.20),.55)
material('Jersey',(.04,.36,.45),.78); material('Shorts',(.015,.04,.06),.82)
material('Socks',(.04,.36,.45),.86); material('Boots',(.015,.025,.04),.35)
material('Hair',(.025,.013,.009),.9); material('Eyes',(.85,.83,.77),.38)
material('Iris',(.028,.045,.035),.35); material('Trim',(.85,.88,.86),.55)

def distance_to_segment(p, a, b):
    line=b-a; t=max(0,min(1,(p-a).dot(line)/line.length_squared))
    return (p-(a+line*t)).length

def weights(p):
    side='L' if p.x>0 else 'R'
    if p.z>1.57: candidates=['Head','Neck']
    elif abs(p.x)>.20 and p.z>1.01: candidates=['UpperArm.'+side,'LowerArm.'+side,'Hand.'+side,'Chest']
    elif p.z<.98: candidates=['Thigh.'+side,'Shin.'+side,'Foot.'+side,'Pelvis']
    else: candidates=['Pelvis','Spine','Chest','Neck']
    nearest=sorted((distance_to_segment(p,*bones[name]),name) for name in candidates)[:3]
    result=[(name,1/max(.015,d)**4) for d,name in nearest]
    total=sum(w for _,w in result)
    return [(name,w/total) for name,w in result]

def mesh(name, coords, polygons, slots, uv=None):
    data=bpy.data.meshes.new(name); data.from_pydata(coords,[],polygons); data.update()
    obj=bpy.data.objects.new(name,data); bpy.context.collection.objects.link(obj)
    for key in dict.fromkeys(slots): data.materials.append(materials[key])
    lookup={mat.name:i for i,mat in enumerate(data.materials)}
    for i,p in enumerate(data.polygons): p.material_index=lookup[slots[i]]; p.use_smooth=True
    if uv:
        layer=data.uv_layers.new(name='UVMap')
        for p,values in zip(data.polygons,uv):
            for loop_index, value in zip(p.loop_indices,values): layer.data[loop_index].uv=value
    modifier=obj.modifiers.new('Skeleton','ARMATURE'); modifier.object=rig; obj.parent=rig
    for name in bones: obj.vertex_groups.new(name=name)
    for i,p in enumerate(coords):
        for name,weight in weights(Vector(p)): obj.vertex_groups[name].add([i],weight,'REPLACE')
    return obj

index_map={old:new for new,old in enumerate(body_indices)}
polygons=[[index_map[i] for i in face] for face in faces]
coords=[points[i] for i in body_indices]
uv=[[texcoords[i] for i in face] for face in face_uv]
slots=[]
for face in faces:
    center=sum((points[i] for i in face),Vector())/len(face)
    slots.append('Hands' if abs(center.x)>.37 and 1.02<center.z<1.29 else 'Skin')
body=mesh('HumanSkin',coords,polygons,slots,uv)
# Sculpt the clothing as a separate shell with folds, keeping anatomy covered.
normals=[Vector() for _ in coords]
for face in polygons:
    n=(coords[face[1]]-coords[face[0]]).cross(coords[face[2]]-coords[face[0]])
    for i in face: normals[i]+=n
for n in normals: n.normalize()
cloth_coords=[]
for p,n in zip(coords,normals):
    q=p.copy(); offset=.018+math.sin(p.z*78+p.x*17)*math.sin(p.x*31)*.0028
    if 1.01<q.z<1.5 and abs(q.x)<.22:
        q.y=max(-.135,min(.135,q.y)); q.x*=1.045
    if .77<q.z<1.07 and abs(q.x)<.25: q.y=max(-.13,min(.14,q.y))
    cloth_coords.append(q+n*offset)
cloth_faces=[];cloth_slots=[];cloth_uv=[]
for f,u in zip(polygons,uv):
    p=sum((coords[i] for i in f),Vector())/len(f)
    slot=None
    if 1.04<p.z<1.515 and abs(p.x)<.265: slot='Jersey'
    if .77<p.z<1.075 and abs(p.x)<.30: slot='Shorts'
    if .135<p.z<.48 and abs(p.x)<.35: slot='Socks'
    if 1.23<p.z<1.49 and .23<abs(p.x)<.32: slot='Jersey'
    if slot: cloth_faces.append(f);cloth_slots.append(slot);cloth_uv.append(u)
mesh('AthleteKit',cloth_coords,cloth_faces,cloth_slots,cloth_uv)
# Hair follows the anatomical scalp, preserving the forehead and face.
hair_faces=[]
for f in polygons:
    p=sum((coords[i] for i in f),Vector())/len(f)
    if p.z>1.73 or (p.z>1.62 and p.y<.033): hair_faces.append(f)
hair_coords=[p+n*.007 for p,n in zip(coords,normals)]
mesh('Scalp',hair_coords,hair_faces,['Hair']*len(hair_faces))

def sphere(name,point,dimensions,slot,bone_name):
    bpy.ops.mesh.primitive_uv_sphere_add(segments=24,ring_count=12,location=point)
    obj=bpy.context.object; obj.name=name; obj.scale=dimensions
    bpy.ops.object.transform_apply(location=False,rotation=False,scale=True)
    # Bake world coordinates before binding so the skinning rest space is exact.
    for v in obj.data.vertices: v.co+=obj.location
    obj.location=(0,0,0); obj.data.materials.append(materials[slot])
    for p in obj.data.polygons:p.use_smooth=True
    obj.vertex_groups.new(name=bone_name).add(list(range(len(obj.data.vertices))),1,'REPLACE')
    mod=obj.modifiers.new('Skeleton','ARMATURE');mod.object=rig;obj.parent=rig
    return obj
for side,letter in [('l','L'),('r','R')]:
    eye=joint(side+'-eye'); sphere('Eye.'+letter,eye,(.014,.014,.0115),'Eyes','Head')
    sphere('Iris.'+letter,eye+Vector((0,.012,-.001)),(.0058,.003,.0058),'Iris','Head')
    ankle=joint(side+'-ankle'); boot_center=ankle+Vector((0,.057,-.040))
    sphere('Boot.'+letter,boot_center,(.065,.145,.060),'Boots','Foot.'+letter)
    # Laces and six molded studs, all skinned to the foot.
    for i in range(4): sphere('Lace.'+letter+str(i),boot_center+Vector((0,-.008+i*.015,.050)),(.029,.0035,.003),'Trim','Foot.'+letter)
    for x in [-.038,.038]:
        for y in [-.045,.025,.10]: sphere('Stud',boot_center+Vector((x,y,-.049)),(.009,.009,.01),'Boots','Foot.'+letter)

bpy.ops.object.select_all(action='SELECT')
bpy.ops.export_scene.gltf(filepath=str(ROOT/'assets/models/athlete.glb'),export_format='GLB',export_animations=False,export_yup=True,export_apply=False)
print('ATHLETE_GLB_CREATED',len(body_indices),'base vertices',len(faces),'base polygons')
