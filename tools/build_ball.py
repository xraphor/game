"""Original stitched 32-panel football. Blender 4.3+, no external assets."""
from pathlib import Path
import bpy, math
from mathutils import Vector
bpy.ops.object.select_all(action='SELECT'); bpy.ops.object.delete(use_global=False)
bpy.ops.mesh.primitive_ico_sphere_add(subdivisions=1,radius=1)
ico=bpy.context.object
verts=[v.co.copy() for v in ico.data.vertices]
faces=[list(p.vertices) for p in ico.data.polygons]
edges=set(tuple(sorted((f[i],f[(i+1)%3]))) for f in faces for i in range(3))
points={(a,b):(verts[a]*2+verts[b]).normalized() for a,b in edges for a,b in [(a,b),(b,a)]}
polygons=[]
for i,v in enumerate(verts):
    neighbors=[b for a,b in points if a==i]
    normal=v.normalized(); u=(verts[neighbors[0]]-v).normalized(); w=normal.cross(u)
    neighbors.sort(key=lambda j:math.atan2((points[i,j]-v).dot(w),(points[i,j]-v).dot(u)))
    polygons.append(([points[i,j] for j in neighbors],0))
for a,b,c in faces: polygons.append(([points[a,b],points[b,a],points[b,c],points[c,b],points[c,a],points[a,c]],1))
coords=[]; triangles=[]; slots=[]
for border,slot in polygons:
    center=sum(border,Vector()).normalized()
    base=len(coords); coords.append(center*.221)
    # Curved leather panels, separated by recessed dark seams.
    ring=[(p*.972+center*.028).normalized() for p in border]
    for j in range(len(ring)):
        for step in range(5):
            p=ring[j].lerp(ring[(j+1)%len(ring)],step/5).normalized()
            coords.append(p*.22)
    count=len(ring)*5
    for j in range(count): triangles.append((base,base+1+j,base+1+(j+1)%count)); slots.append(slot)
mesh=bpy.data.meshes.new('StitchedPanels');mesh.from_pydata(coords,[],triangles);mesh.update()
obj=bpy.data.objects.new('FootballPanels',mesh);bpy.context.collection.objects.link(obj)
for name,color in [('BlackLeather',(.016,.025,.03,1)),('WhiteLeather',(.86,.88,.82,1))]:
    m=bpy.data.materials.new(name);m.diffuse_color=color;m.use_nodes=True
    m.node_tree.nodes['Principled BSDF'].inputs['Base Color'].default_value=color
    m.node_tree.nodes['Principled BSDF'].inputs['Roughness'].default_value=.58
    mesh.materials.append(m)
for p,slot in zip(mesh.polygons,slots):p.material_index=slot;p.use_smooth=True
bpy.data.objects.remove(ico,do_unlink=True)
bpy.ops.mesh.primitive_uv_sphere_add(segments=48,ring_count=24,radius=.2188)
seams=bpy.context.object;seams.name='RecessedSeams';seams.data.materials.append(mesh.materials[0])
for p in seams.data.polygons:p.use_smooth=True
bpy.ops.export_scene.gltf(filepath=str(Path(__file__).resolve().parent.parent/'assets/models/football.glb'),export_format='GLB',export_animations=False)
print('FOOTBALL_CREATED',len(polygons),'panels')
