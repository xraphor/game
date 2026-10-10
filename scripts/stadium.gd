extends Node3D
class_name FootballStadium

## Original procedural NUKE arena. Pitch coordinates: x +/-18, z +/-28.
## All static playing-surface, goal and boundary colliders are on layer 1.

var sun: DirectionalLight3D
var world_environment: WorldEnvironment
var floodlights: Array[SpotLight3D] = []
var crowd_nodes: Array[MultiMeshInstance3D] = []
var quality: int = 2
var _materials: Dictionary = {}
var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.seed = 481516
	_make_materials()
	_build_environment()
	_build_pitch()
	_build_goal(-1.0)
	_build_goal(1.0)
	_build_boundaries()
	_build_stands()
	_build_floodlights()
	_build_details()
	set_quality(quality)

func set_quality(index: int) -> void:
	quality = clampi(index, 0, 2)
	if not is_instance_valid(sun):
		return
	sun.shadow_enabled = quality > 0
	for light: SpotLight3D in floodlights:
		light.visible = quality > 0
	for audience: MultiMeshInstance3D in crowd_nodes:
		audience.visible = quality > 0
	var env: Environment = world_environment.environment
	var modern_renderer: bool = RenderingServer.get_current_rendering_method() != "gl_compatibility"
	if modern_renderer:
		env.ssao_enabled = quality == 2
		env.glow_enabled = quality == 2
		env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	else:
		env.tonemap_mode = Environment.TONE_MAPPER_LINEAR

func _mat(key: String) -> StandardMaterial3D:
	return _materials[key] as StandardMaterial3D

func _material(key: String, color: Color, roughness: float = 0.7, metallic: float = 0.0, emission: float = 0.0) -> void:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metallic
	if emission > 0.0:
		material.emission_enabled = true
		material.emission = color
		material.emission_energy_multiplier = emission
	_materials[key] = material

func _make_materials() -> void:
	_material("white", Color(0.89, 0.93, 0.89), 0.53)
	_material("line", Color(0.86, 0.90, 0.79), 0.94)
	_material("concrete", Color(0.18, 0.21, 0.22), 0.92)
	_material("concrete_dark", Color(0.10, 0.13, 0.14), 0.91)
	_material("roof", Color(0.08, 0.12, 0.15), 0.76, 0.35)
	_mat("roof").metallic_specular = 0.22
	_material("steel", Color(0.26, 0.31, 0.34), 0.32, 0.82)
	_material("black", Color(0.027, 0.047, 0.058), 0.49)
	_material("cyan", Color(0.18, 0.91, 0.82), 0.4, 0.20, 0.26)
	_material("orange", Color(0.96, 0.34, 0.10), 0.55)
	_material("lamp", Color(1.0, 0.91, 0.73), 0.35, 0.0, 3.0)
	_material("net", Color(0.72, 0.78, 0.74), 0.89)
	_material("seat", Color.WHITE, 0.68)
	_mat("seat").vertex_color_use_as_albedo = true
	_material("crowd", Color.WHITE, 0.96)
	_mat("crowd").vertex_color_use_as_albedo = true
	_material("tarmac", Color(0.087, 0.11, 0.115), 0.89)

func _build_environment() -> void:
	world_environment = WorldEnvironment.new()
	var env := Environment.new()
	var sky := Sky.new()
	var sky_mat := ProceduralSkyMaterial.new()
	sky_mat.sky_top_color = Color(0.045, 0.13, 0.27)
	sky_mat.sky_horizon_color = Color(0.89, 0.58, 0.37)
	sky_mat.ground_bottom_color = Color(0.06, 0.095, 0.11)
	sky_mat.ground_horizon_color = Color(0.57, 0.40, 0.27)
	sky_mat.sky_curve = 0.35
	sky_mat.ground_curve = 0.12
	sky_mat.sun_angle_max = 2.0
	sky.sky_material = sky_mat
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.63, 0.75, 0.85)
	env.ambient_light_energy = 0.68
	env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.fog_enabled = true
	env.fog_light_color = Color(0.48, 0.56, 0.59)
	env.fog_light_energy = 0.5
	env.fog_density = 0.0017
	env.fog_sky_affect = 0.02
	world_environment.environment = env
	add_child(world_environment)
	sun = DirectionalLight3D.new()
	sun.name = "WarmEveningSun"
	sun.rotation_degrees = Vector3(-28.0, -38.0, 0.0)
	sun.light_color = Color(1.0, 0.78, 0.55)
	sun.light_energy = 1.25
	sun.directional_shadow_max_distance = 115.0
	sun.shadow_bias = 0.035
	sun.shadow_normal_bias = 1.0
	add_child(sun)

func _box(position: Vector3, size: Vector3, material: Material, collider: bool = false) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = position
	add_child(node)
	if collider:
		_static_box(position, size)
	return node

func _static_box(position: Vector3, size: Vector3) -> void:
	var body := StaticBody3D.new()
	body.position = position
	body.collision_layer = 1
	body.collision_mask = 0
	var shape := BoxShape3D.new()
	shape.size = size
	var collision := CollisionShape3D.new()
	collision.shape = shape
	body.add_child(collision)
	add_child(body)

func _beam(start: Vector3, finish: Vector3, radius: float, material: Material, collider: bool = false) -> MeshInstance3D:
	var delta: Vector3 = finish - start
	var orientation := Quaternion(Vector3.UP, delta.normalized())
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = delta.length()
	mesh.radial_segments = 8 if radius < 0.05 else 12
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.position = (start + finish) * 0.5
	node.quaternion = orientation
	add_child(node)
	if collider:
		var body := StaticBody3D.new()
		body.position = node.position
		body.quaternion = orientation
		body.collision_layer = 1
		body.collision_mask = 0
		var shape := CylinderShape3D.new()
		shape.radius = radius
		shape.height = delta.length()
		var collision := CollisionShape3D.new()
		collision.shape = shape
		body.add_child(collision)
		add_child(body)
	return node

func _build_pitch() -> void:
	_box(Vector3(0.0, -0.22, 0.0), Vector3(100.0, 0.42, 112.0), _mat("tarmac"), true)
	var turf := MeshInstance3D.new()
	var mesh := PlaneMesh.new()
	mesh.size = Vector2(41.8, 65.8)
	turf.mesh = mesh
	turf.position.y = 0.001
	var material := ShaderMaterial.new()
	material.shader = load("res://shaders/grass.gdshader") as Shader
	turf.material_override = material
	add_child(turf)
	# The turf's physical surface is exactly y=0.
	_static_box(Vector3(0.0, -0.10, 0.0), Vector3(42.0, 0.2, 66.0))
	_rect_lines(Vector2.ZERO, Vector2(36.0, 56.0))
	_line(Vector2(-18.0, 0.0), Vector2(18.0, 0.0))
	_arc(Vector2.ZERO, 5.3, 0.0, TAU)
	_disc(Vector3(0.0, 0.011, 0.0), 0.11)
	for sign_value: float in [-1.0, 1.0]:
		_rect_lines(Vector2(0.0, sign_value * 23.5), Vector2(22.0, 9.0))
		_rect_lines(Vector2(0.0, sign_value * 26.15), Vector2(11.0, 3.7))
		_disc(Vector3(0.0, 0.011, sign_value * 20.5), 0.10)
		if sign_value < 0.0:
			_arc(Vector2(0.0, -20.5), 3.3, 0.47, PI - 0.47)
		else:
			_arc(Vector2(0.0, 20.5), 3.3, PI + 0.47, TAU - 0.47)
		for sx: float in [-1.0, 1.0]:
			var corner := Vector2(sx * 18.0, sign_value * 28.0)
			var angle: float = 0.0
			if sx > 0.0 and sign_value < 0.0:
				angle = PI * 0.5
			elif sx > 0.0 and sign_value > 0.0:
				angle = PI
			elif sx < 0.0 and sign_value > 0.0:
				angle = PI * 1.5
			_arc(corner, 0.8, angle, angle + PI * 0.5)
			_beam(Vector3(corner.x, 0.0, corner.y), Vector3(corner.x, 1.3, corner.y), 0.016, _mat("white"))
			_box(Vector3(corner.x + sx * 0.14, 1.15, corner.y), Vector3(0.28, 0.23, 0.014), _mat("cyan"))

func _line(a: Vector2, b: Vector2, width: float = 0.105) -> void:
	var delta: Vector2 = b - a
	var node: MeshInstance3D = _box(Vector3((a.x + b.x) * 0.5, 0.009, (a.y + b.y) * 0.5), Vector3(width, 0.012, delta.length()), _mat("line"))
	node.rotation.y = -atan2(delta.y, delta.x) + PI * 0.5
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _rect_lines(center: Vector2, size: Vector2) -> void:
	var half: Vector2 = size * 0.5
	_line(center + Vector2(-half.x, -half.y), center + Vector2(half.x, -half.y))
	_line(center + Vector2(-half.x, half.y), center + Vector2(half.x, half.y))
	_line(center + Vector2(-half.x, -half.y), center + Vector2(-half.x, half.y))
	_line(center + Vector2(half.x, -half.y), center + Vector2(half.x, half.y))

func _arc(center: Vector2, radius: float, start_angle: float, end_angle: float) -> void:
	var steps: int = maxi(12, int((end_angle - start_angle) * 12.0))
	var vertices := PackedVector3Array()
	var normals := PackedVector3Array()
	for i: int in range(steps):
		var a: float = lerpf(start_angle, end_angle, float(i) / float(steps))
		var b: float = lerpf(start_angle, end_angle, float(i + 1) / float(steps))
		var inner: float = radius - 0.0525
		var outer: float = radius + 0.0525
		var p0 := Vector3(center.x + cos(a) * inner, 0.015, center.y + sin(a) * inner)
		var p1 := Vector3(center.x + cos(a) * outer, 0.015, center.y + sin(a) * outer)
		var p2 := Vector3(center.x + cos(b) * outer, 0.015, center.y + sin(b) * outer)
		var p3 := Vector3(center.x + cos(b) * inner, 0.015, center.y + sin(b) * inner)
		for vertex: Vector3 in [p0, p1, p2, p0, p2, p3]:
			vertices.append(vertex)
			normals.append(Vector3.UP)
	var arrays: Array = []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = vertices
	arrays[Mesh.ARRAY_NORMAL] = normals
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	var node := MeshInstance3D.new()
	node.mesh = mesh
	var material: StandardMaterial3D = _mat("line").duplicate() as StandardMaterial3D
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	node.material_override = material
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _disc(position: Vector3, radius: float) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = 0.012
	mesh.radial_segments = 20
	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.position = position
	node.material_override = _mat("line")
	node.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(node)

func _build_goal(sign_value: float) -> void:
	var z: float = sign_value * 28.0
	var back: float = z + sign_value * 2.3
	# The opening (inside the 7 cm posts) is exactly 7.32 x 2.44 m.
	for x: float in [-3.73, 3.73]:
		_beam(Vector3(x, 0.07, z), Vector3(x, 2.51, z), 0.07, _mat("white"), true)
		_beam(Vector3(x, 0.06, z), Vector3(x, 0.06, back), 0.038, _mat("white"))
		_beam(Vector3(x, 2.51, z), Vector3(x, 2.51, back), 0.031, _mat("white"))
		_beam(Vector3(x, 0.06, back), Vector3(x, 2.51, back), 0.028, _mat("steel"))
	_beam(Vector3(-3.73, 2.51, z), Vector3(3.73, 2.51, z), 0.07, _mat("white"), true)
	_beam(Vector3(-3.73, 0.035, back), Vector3(3.73, 0.035, back), 0.028, _mat("steel"))
	_beam(Vector3(-3.73, 2.51, back), Vector3(3.73, 2.51, back), 0.028, _mat("steel"))
	# Solid collision sheets represent the flexible net's stop surface.
	_static_box(Vector3(0.0, 1.255, back), Vector3(7.60, 2.51, 0.06))
	_static_box(Vector3(-3.81, 1.255, (z + back) * 0.5), Vector3(0.055, 2.51, 2.3))
	_static_box(Vector3(3.81, 1.255, (z + back) * 0.5), Vector3(0.055, 2.51, 2.3))
	_static_box(Vector3(0.0, 2.58, (z + back) * 0.5), Vector3(7.60, 0.05, 2.3))
	var segments: Array[Transform3D] = []
	for i: int in range(41):
		var x: float = lerpf(-3.73, 3.73, float(i) / 40.0)
		segments.append(_cylinder_transform(Vector3(x, 0.03, back), Vector3(x, 2.51, back), 0.009))
		segments.append(_cylinder_transform(Vector3(x, 2.51, z), Vector3(x, 2.51, back), 0.009))
	for j: int in range(14):
		var y: float = lerpf(0.03, 2.51, float(j) / 13.0)
		segments.append(_cylinder_transform(Vector3(-3.73, y, back), Vector3(3.73, y, back), 0.009))
		for x: float in [-3.73, 3.73]:
			segments.append(_cylinder_transform(Vector3(x, y, z), Vector3(x, y, back), 0.009))
	for k: int in range(14):
		var zz: float = lerpf(z, back, float(k) / 13.0)
		segments.append(_cylinder_transform(Vector3(-3.73, 2.51, zz), Vector3(3.73, 2.51, zz), 0.009))
		for x: float in [-3.73, 3.73]:
			segments.append(_cylinder_transform(Vector3(x, 0.03, zz), Vector3(x, 2.51, zz), 0.009))
	var net_mesh := CylinderMesh.new()
	net_mesh.top_radius = 1.0
	net_mesh.bottom_radius = 1.0
	net_mesh.height = 1.0
	net_mesh.radial_segments = 4
	_multimesh(net_mesh, _mat("net"), segments)

func _cylinder_transform(a: Vector3, b: Vector3, radius: float) -> Transform3D:
	var delta: Vector3 = b - a
	var basis := Basis(Quaternion(Vector3.UP, delta.normalized()))
	basis = basis * Basis.from_scale(Vector3(radius, delta.length(), radius))
	return Transform3D(basis, (a + b) * 0.5)

func _multimesh(mesh: Mesh, material: Material, transforms: Array[Transform3D], colors: Array[Color] = []) -> MultiMeshInstance3D:
	var multi := MultiMesh.new()
	multi.transform_format = MultiMesh.TRANSFORM_3D
	multi.use_colors = not colors.is_empty()
	multi.mesh = mesh
	multi.instance_count = transforms.size()
	for i: int in range(transforms.size()):
		multi.set_instance_transform(i, transforms[i])
		if not colors.is_empty():
			multi.set_instance_color(i, colors[i])
	var node := MultiMeshInstance3D.new()
	node.multimesh = multi
	node.material_override = material
	add_child(node)
	return node

func _build_boundaries() -> void:
	# Tall invisible upper planes keep lofted shots in the practice arena.
	_static_box(Vector3(-21.4, 5.0, 0.0), Vector3(0.2, 10.0, 66.4))
	_static_box(Vector3(21.4, 5.0, 0.0), Vector3(0.2, 10.0, 66.4))
	_static_box(Vector3(0.0, 5.0, -33.4), Vector3(42.8, 10.0, 0.2))
	_static_box(Vector3(0.0, 5.0, 33.4), Vector3(42.8, 10.0, 0.2))
	for sx: float in [-1.0, 1.0]:
		_box(Vector3(sx * 21.1, 0.38, 0.0), Vector3(0.35, 0.76, 66.0), _mat("concrete"), true)
		for i: int in range(10):
			var z: float = -29.25 + float(i) * 6.5
			_box(Vector3(sx * 20.92, 0.59, z), Vector3(0.16, 0.92, 6.1), _mat("black"))
			_box(Vector3(sx * 20.82, 0.98, z), Vector3(0.025, 0.035, 6.1), _mat("cyan"))
			var text: String = "NUKE  /  FOOTBALL" if i % 2 == 0 else "PLAY THE BEAUTIFUL GAME"
			_label(text, Vector3(sx * 20.78, 0.60, z), 0.0037, -sx * PI * 0.5, Color(0.72, 0.95, 0.94), 50)
	for sz: float in [-1.0, 1.0]:
		_box(Vector3(0.0, 0.38, sz * 33.1), Vector3(42.0, 0.76, 0.35), _mat("concrete"), true)
		for i: int in range(6):
			var x: float = -17.5 + float(i) * 7.0
			_box(Vector3(x, 0.59, sz * 32.92), Vector3(6.5, 0.92, 0.16), _mat("black"))
			_box(Vector3(x, 0.99, sz * 32.82), Vector3(6.5, 0.035, 0.025), _mat("cyan"))
			_label("NUKE   ACADEMY", Vector3(x, 0.60, sz * 32.78), 0.0038, PI if sz > 0.0 else 0.0, Color(0.72, 0.95, 0.94), 50)

func _label(text: String, position: Vector3, pixel_size: float, angle: float, color: Color, font_size: int = 64) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.position = position
	label.rotation.y = angle
	label.pixel_size = pixel_size
	label.font_size = font_size
	label.outline_size = 0
	label.modulate = color
	label.shaded = false
	label.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(label)
	return label

func _build_stands() -> void:
	var seat_transforms: Array[Transform3D] = []
	var seat_colors: Array[Color] = []
	var back_transforms: Array[Transform3D] = []
	var crowd_transforms: Array[Transform3D] = []
	var crowd_colors: Array[Color] = []
	var head_transforms: Array[Transform3D] = []
	var head_colors: Array[Color] = []
	var palette: Array[Color] = [Color(0.07, 0.21, 0.25), Color(0.08, 0.43, 0.45), Color(0.24, 0.71, 0.65)]
	var people_palette: Array[Color] = [Color(0.21, 0.32, 0.39), Color(0.72, 0.34, 0.21), Color(0.76, 0.72, 0.56), Color(0.18, 0.58, 0.51), Color(0.50, 0.57, 0.65)]
	var skin_palette: Array[Color] = [Color(0.64, 0.39, 0.25), Color(0.85, 0.62, 0.43), Color(0.33, 0.21, 0.14), Color(0.72, 0.48, 0.32)]
	for side: int in range(4):
		var long_side: bool = side < 2
		var sign_value: float = -1.0 if side % 2 == 0 else 1.0
		var length: float = 66.0 if long_side else 48.0
		var columns: int = 72 if long_side else 52
		for row: int in range(7):
			var depth: float = 23.5 + float(row) * 1.15 if long_side else 35.5 + float(row) * 1.15
			var y: float = 0.4 + float(row) * 0.64
			var center: Vector3 = Vector3(sign_value * depth, y * 0.5, 0.0) if long_side else Vector3(0.0, y * 0.5, sign_value * depth)
			var size: Vector3 = Vector3(1.18, y, length) if long_side else Vector3(length, y, 1.18)
			_box(center, size, _mat("concrete_dark") if row % 2 == 0 else _mat("concrete"))
			for column: int in range(columns):
				if column % 18 < 2:
					continue
				var along: float = -length * 0.5 + (float(column) + 0.5) * length / float(columns)
				var position: Vector3 = Vector3(sign_value * depth, y + 0.3, along) if long_side else Vector3(along, y + 0.3, sign_value * depth)
				var angle: float = -sign_value * PI * 0.5 if long_side else PI if sign_value > 0.0 else 0.0
				var basis := Basis(Vector3.UP, angle)
				seat_transforms.append(Transform3D(basis, position))
				var seat_color: Color = palette[(row + int(column / 18)) % palette.size()]
				if row == 3 or column % 18 == 2:
					seat_color = Color(0.76, 0.84, 0.80)
				seat_colors.append(seat_color)
				back_transforms.append(Transform3D(basis, position + basis * Vector3(0.0, 0.19, -0.22)))
				if _rng.randf() < 0.38 and row > 1:
					crowd_transforms.append(Transform3D(basis.scaled(Vector3(0.32, 0.60, 0.27)), position + Vector3(0.0, 0.44, 0.0)))
					crowd_colors.append(people_palette[_rng.randi_range(0, people_palette.size() - 1)])
					head_transforms.append(Transform3D(Basis.IDENTITY, position + Vector3(0.0, 1.03, 0.0)))
					head_colors.append(skin_palette[_rng.randi_range(0, skin_palette.size() - 1)])
		# Roof panels, fascia, columns and triangular supports.
		var roof_depth: float = 28.0 if long_side else 40.0
		var roof_pos: Vector3 = Vector3(sign_value * roof_depth, 7.65, 0.0) if long_side else Vector3(0.0, 7.65, sign_value * roof_depth)
		_box(roof_pos, Vector3(11.5, 0.22, length + 1.0) if long_side else Vector3(length + 1.0, 0.22, 11.5), _mat("roof"))
		var fascia_pos: Vector3 = Vector3(sign_value * 22.6, 7.5, 0.0) if long_side else Vector3(0.0, 7.5, sign_value * 34.6)
		_box(fascia_pos, Vector3(0.18, 0.55, length + 1.0) if long_side else Vector3(length + 1.0, 0.55, 0.18), _mat("black"))
		_box(fascia_pos + Vector3(0.0, -0.23, 0.0), Vector3(0.20, 0.045, length) if long_side else Vector3(length, 0.045, 0.20), _mat("cyan"))
		for pillar: int in range(7):
			var along: float = -length * 0.5 + float(pillar) * length / 6.0
			var base: Vector3 = Vector3(sign_value * 32.0, 0.0, along) if long_side else Vector3(along, 0.0, sign_value * 44.0)
			var tip: Vector3 = Vector3(sign_value * 22.6, 7.4, along) if long_side else Vector3(along, 7.4, sign_value * 34.6)
			_beam(base, base + Vector3(0.0, 7.7, 0.0), 0.13, _mat("steel"))
			_beam(base + Vector3(0.0, 7.55, 0.0), tip, 0.10, _mat("steel"))
			_beam(base + Vector3(0.0, 5.8, 0.0), tip, 0.055, _mat("steel"))
	var seat_mesh := BoxMesh.new()
	seat_mesh.size = Vector3(0.68, 0.13, 0.56)
	_multimesh(seat_mesh, _mat("seat"), seat_transforms, seat_colors)
	var back_mesh := BoxMesh.new()
	back_mesh.size = Vector3(0.66, 0.38, 0.11)
	_multimesh(back_mesh, _mat("seat"), back_transforms, seat_colors)
	var person_mesh := CapsuleMesh.new()
	person_mesh.radius = 0.5
	person_mesh.height = 1.8
	person_mesh.radial_segments = 6
	person_mesh.rings = 2
	crowd_nodes.append(_multimesh(person_mesh, _mat("crowd"), crowd_transforms, crowd_colors))
	var head_mesh := SphereMesh.new()
	head_mesh.radius = 0.13
	head_mesh.height = 0.29
	head_mesh.radial_segments = 8
	head_mesh.rings = 4
	crowd_nodes.append(_multimesh(head_mesh, _mat("crowd"), head_transforms, head_colors))

func _build_floodlights() -> void:
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var base := Vector3(sx * 23.0, 0.0, sz * 30.5)
			_beam(base, base + Vector3(0.0, 15.8, 0.0), 0.16, _mat("steel"))
			var angle: float = -sx * PI * 0.5
			var rack: MeshInstance3D = _box(base + Vector3(0.0, 15.1, 0.0), Vector3(3.8, 1.1, 0.22), _mat("black"))
			rack.rotation.y = angle
			for row: int in range(2):
				for column: int in range(5):
					var offset: Vector3 = Basis(Vector3.UP, angle) * Vector3(-1.5 + float(column) * 0.75, -0.23 + float(row) * 0.50, 0.14)
					var lamp: MeshInstance3D = _box(base + Vector3(0.0, 15.1, 0.0) + offset, Vector3(0.53, 0.31, 0.045), _mat("lamp"))
					lamp.rotation.y = angle
			var light := SpotLight3D.new()
			light.position = base + Vector3(0.0, 14.5, 0.0)
			light.light_color = Color(0.79, 0.88, 1.0)
			light.light_energy = 6.0
			light.spot_range = 65.0
			light.spot_angle = 46.0
			light.spot_attenuation = 0.5
			light.light_specular = 0.06
			light.shadow_enabled = false
			add_child(light)
			light.look_at(Vector3(sx * 3.0, 0.0, sz * 8.0), Vector3.UP)
			floodlights.append(light)

func _build_details() -> void:
	# Large original scoreboards frame both goal ends.
	for sign_value: float in [-1.0, 1.0]:
		var z: float = sign_value * 41.2
		_box(Vector3(0.0, 8.8, z), Vector3(11.0, 3.1, 0.4), _mat("steel"))
		_box(Vector3(0.0, 8.8, z - sign_value * 0.23), Vector3(10.7, 2.8, 0.055), _mat("black"))
		var angle: float = PI if sign_value > 0.0 else 0.0
		_label("N U K E", Vector3(0.0, 9.27, z - sign_value * 0.28), 0.019, angle, Color(0.55, 1.0, 0.92), 68)
		_label("F O O T B A L L  /  A C A D E M Y", Vector3(0.0, 8.35, z - sign_value * 0.28), 0.0075, angle, Color(0.79, 0.85, 0.84), 48)
		_box(Vector3(0.0, 7.48, z - sign_value * 0.27), Vector3(10.0, 0.04, 0.02), _mat("cyan"))
	# Low benches and reusable training equipment outside the playing lines.
	for sign_value: float in [-1.0, 1.0]:
		_box(Vector3(sign_value * 19.9, 0.44, 6.0), Vector3(0.6, 0.15, 5.5), _mat("white"))
		_box(Vector3(sign_value * 20.1, 0.80, 6.0), Vector3(0.12, 0.52, 5.5), _mat("black"))
		for z: float in [3.8, 8.2]:
			_box(Vector3(sign_value * 19.9, 0.21, z), Vector3(0.34, 0.40, 0.16), _mat("steel"))
	for i: int in range(5):
		var cone := CylinderMesh.new()
		cone.top_radius = 0.025
		cone.bottom_radius = 0.14
		cone.height = 0.37
		cone.radial_segments = 12
		var node := MeshInstance3D.new()
		node.mesh = cone
		node.material_override = _mat("orange")
		node.position = Vector3(-19.4, 0.185, -5.5 + float(i) * 0.5)
		add_child(node)
		_box(node.position + Vector3(0.0, -0.16, 0.0), Vector3(0.32, 0.04, 0.32), _mat("orange"))
