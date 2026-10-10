class_name Footballer
extends CharacterBody3D
## Original, articulated footballer built entirely from procedural geometry.
## Feet are at local Y=0, and the unrotated figure faces local -Z.

var team_color: Color = Color("12bfcb")
var shirt_number: String = "10"
var is_keeper: bool = false

var _graphics: Node3D
var _body: Node3D
var _head: Node3D
var _left_arm: Node3D
var _right_arm: Node3D
var _left_forearm: Node3D
var _right_forearm: Node3D
var _left_leg: Node3D
var _right_leg: Node3D
var _left_shin: Node3D
var _right_shin: Node3D
var _name_label: Label3D
var _running_time: float = 0.0
var _run_blend: float = 0.0
var _kick_time: float = 0.0
var _dive_time: float = 0.0
var _dive_side: float = 1.0
var _facing: float = 0.0
var _built: bool = false


func configure(color: Color, number: String, keeper: bool = false) -> void:
	team_color = color
	shirt_number = number
	is_keeper = keeper
	if is_inside_tree() and _built:
		_build_model()


func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	floor_snap_length = 0.18
	var collision: CollisionShape3D = CollisionShape3D.new()
	var capsule: CapsuleShape3D = CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.76
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	_build_model()


func move_toward_direction(direction: Vector3, speed: float, delta: float) -> void:
	var flat_direction: Vector3 = Vector3(direction.x, 0.0, direction.z)
	if flat_direction.length_squared() > 1.0:
		flat_direction = flat_direction.normalized()
	var desired: Vector3 = flat_direction * speed
	velocity.x = move_toward(velocity.x, desired.x, 23.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 23.0 * delta)
	if is_on_floor():
		velocity.y = -0.4
	else:
		velocity.y -= 24.0 * delta
	move_and_slide()
	if flat_direction.length_squared() > 0.005:
		face_direction(flat_direction, delta)


func face_direction(direction: Vector3, delta: float = 0.016) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	var target_angle: float = atan2(-direction.x, -direction.z)
	_facing = lerp_angle(_facing, target_angle, minf(1.0, delta * 13.0))
	if is_instance_valid(_graphics):
		_graphics.rotation.y = _facing


func kick_animation() -> void:
	_kick_time = 0.34


func dive_animation(direction: float) -> void:
	_dive_side = -1.0 if direction < 0.0 else 1.0
	_dive_time = 0.9


func reset_pose() -> void:
	_kick_time = 0.0
	_dive_time = 0.0
	_running_time = 0.0
	_run_blend = 0.0
	velocity = Vector3.ZERO
	if _built:
		animate(0.0)


func _process(delta: float) -> void:
	animate(delta)


func animate(delta: float) -> void:
	if not _built:
		return
	var horizontal_speed: float = Vector2(velocity.x, velocity.z).length()
	_run_blend = move_toward(_run_blend, clampf(horizontal_speed / 5.0, 0.0, 1.0), delta * 7.0)
	_running_time += delta * (6.0 + horizontal_speed * 1.4)
	_kick_time = maxf(0.0, _kick_time - delta)
	_dive_time = maxf(0.0, _dive_time - delta)
	var stride: float = sin(_running_time) * _run_blend
	var lift: float = absf(cos(_running_time)) * _run_blend
	_body.position = Vector3(0.0, lift * 0.033, 0.0)
	_body.rotation = Vector3(-_run_blend * 0.07, sin(_running_time) * _run_blend * 0.035, 0.0)
	_head.rotation = Vector3(_run_blend * 0.045, 0.0, 0.0)
	_left_arm.rotation = Vector3(-stride * 0.68 - 0.07, 0.0, 0.11)
	_right_arm.rotation = Vector3(stride * 0.68 - 0.07, 0.0, -0.11)
	_left_forearm.rotation.x = 0.13 + _run_blend * 0.30
	_right_forearm.rotation.x = 0.13 + _run_blend * 0.30
	_left_leg.rotation = Vector3(stride * 0.69, 0.0, 0.0)
	_right_leg.rotation = Vector3(-stride * 0.69, 0.0, 0.0)
	_left_shin.rotation.x = -maxf(0.0, -stride) * 0.82
	_right_shin.rotation.x = -maxf(0.0, stride) * 0.82
	if _kick_time > 0.0:
		var kick_progress: float = 1.0 - _kick_time / 0.34
		var kick_arc: float = sin(kick_progress * PI)
		_right_leg.rotation.x = kick_arc * 1.08
		_right_shin.rotation.x = -kick_arc * 0.16
		_left_arm.rotation.x = -kick_arc * 0.40
		_right_arm.rotation.x = kick_arc * 0.34
		_body.rotation.z = -kick_arc * 0.07
	if _dive_time > 0.0:
		var dive_progress: float = 1.0 - _dive_time / 0.9
		var dive_arc: float = sin(dive_progress * PI)
		_body.rotation.z = _dive_side * dive_arc * 1.10
		_body.position.x = -_dive_side * dive_arc * 0.20
		_body.position.y += dive_arc * 0.14
		_left_arm.rotation.z = 0.11 + _dive_side * dive_arc * 1.20
		_right_arm.rotation.z = -0.11 + _dive_side * dive_arc * 1.20
		_left_arm.rotation.x = dive_arc * 0.75
		_right_arm.rotation.x = dive_arc * 0.75
		_left_leg.rotation.x = dive_arc * 0.24
		_right_leg.rotation.x = -dive_arc * 0.20


func _build_model() -> void:
	_built = false
	if is_instance_valid(_graphics):
		remove_child(_graphics)
		_graphics.queue_free()
	if is_instance_valid(_name_label):
		remove_child(_name_label)
		_name_label.queue_free()
	_graphics = Node3D.new()
	_graphics.name = "OriginalFootballerModel"
	_graphics.rotation.y = _facing
	add_child(_graphics)
	_body = Node3D.new()
	_graphics.add_child(_body)
	var jersey: StandardMaterial3D = _material(team_color, 0.83)
	var jersey_dark: StandardMaterial3D = _material(team_color.darkened(0.27), 0.85)
	var trim: StandardMaterial3D = _material(Color("ecf8f6"), 0.66)
	var shorts: StandardMaterial3D = _material(Color("102c3f").lerp(team_color.darkened(0.6), 0.24), 0.87)
	var number_seed: int = absi(shirt_number.hash())
	var complexion: Array[Color] = [Color("b47955"), Color("d8a57e"), Color("885739"), Color("e4b793"), Color("a76743")]
	var skin: StandardMaterial3D = _material(complexion[number_seed % complexion.size()], 0.88)
	var hair: StandardMaterial3D = _material(Color("201813") if number_seed % 3 != 0 else Color("4d3521"), 0.93)
	var boot: StandardMaterial3D = _material(Color("122536"), 0.49)
	var sole: StandardMaterial3D = _material(Color("08111e"), 0.65)
	var eyes: StandardMaterial3D = _material(Color("182028"), 0.5)
	var white: StandardMaterial3D = _material(Color("f5eee0"), 0.78)
	var glove: StandardMaterial3D = _material(Color("d9fa58"), 0.58)

	# A custom tapered shirt gives broad shoulders, a waist and a fabric silhouette.
	_tapered_box(_body, Vector3(0.0, 1.27, 0.0), 0.44, 0.34, 0.43, 0.285, jersey)
	_box(_body, Vector3(0.0, 1.065, 0.0), Vector3(0.345, 0.035, 0.287), jersey_dark)
	_box(_body, Vector3(-0.175, 1.255, 0.0), Vector3(0.018, 0.335, 0.294), jersey_dark)
	_box(_body, Vector3(0.175, 1.255, 0.0), Vector3(0.018, 0.335, 0.294), jersey_dark)
	# Original diagonal chest accents and a tiny club crest.
	var chest_band: MeshInstance3D = _box(_body, Vector3(0.0, 1.34, -0.149), Vector3(0.352, 0.027, 0.008), trim)
	chest_band.rotation.z = -0.095
	_box(_body, Vector3(-0.116, 1.397, -0.15), Vector3(0.043, 0.052, 0.010), jersey_dark)
	_box(_body, Vector3(-0.116, 1.404, -0.158), Vector3(0.026, 0.008, 0.005), trim)
	_box(_body, Vector3(0.108, 1.398, -0.15), Vector3(0.034, 0.008, 0.008), trim)
	# Collar is assembled around a real neck instead of drawn onto the shirt.
	_sphere(_body, Vector3(0.0, 1.486, 0.0), Vector3(0.19, 0.053, 0.18), jersey_dark)
	_cylinder(_body, Vector3(0.0, 1.523, 0.0), 0.057, 0.058, 0.093, skin)
	_box(_body, Vector3(-0.043, 1.483, -0.074), Vector3(0.047, 0.022, 0.037), trim).rotation.z = -0.22
	_box(_body, Vector3(0.043, 1.483, -0.074), Vector3(0.047, 0.022, 0.037), trim).rotation.z = 0.22
	_box(_body, Vector3(0.0, 1.035, 0.0), Vector3(0.36, 0.066, 0.30), shorts)
	_box(_body, Vector3(0.0, 1.065, 0.0), Vector3(0.36, 0.017, 0.303), jersey_dark)

	_head = Node3D.new()
	_head.position = Vector3(0.0, 1.65, 0.0)
	_body.add_child(_head)
	_sphere(_head, Vector3.ZERO, Vector3(0.252, 0.300, 0.254), skin)
	_sphere(_head, Vector3(-0.127, -0.006, 0.0), Vector3(0.037, 0.069, 0.045), skin)
	_sphere(_head, Vector3(0.127, -0.006, 0.0), Vector3(0.037, 0.069, 0.045), skin)
	# Hair cap uses its own hemisphere so the face remains visible.
	_hair_cap(_head, hair, number_seed % 3)
	_sphere(_head, Vector3(-0.044, 0.014, -0.119), Vector3(0.032, 0.014, 0.016), white)
	_sphere(_head, Vector3(0.044, 0.014, -0.119), Vector3(0.032, 0.014, 0.016), white)
	_sphere(_head, Vector3(-0.043, 0.013, -0.128), Vector3(0.012, 0.013, 0.007), eyes)
	_sphere(_head, Vector3(0.043, 0.013, -0.128), Vector3(0.012, 0.013, 0.007), eyes)
	_box(_head, Vector3(-0.044, 0.037, -0.117), Vector3(0.036, 0.009, 0.016), hair).rotation.z = -0.10
	_box(_head, Vector3(0.044, 0.037, -0.117), Vector3(0.036, 0.009, 0.016), hair).rotation.z = 0.10
	_sphere(_head, Vector3(0.0, -0.016, -0.13), Vector3(0.027, 0.046, 0.029), skin)
	_box(_head, Vector3(0.0, -0.063, -0.111), Vector3(0.039, 0.007, 0.006), _material(complexion[number_seed % complexion.size()].darkened(0.28), 0.85))

	_left_arm = _arm(-1.0, jersey, jersey_dark, trim, skin, glove)
	_right_arm = _arm(1.0, jersey, jersey_dark, trim, skin, glove)
	_left_forearm = _left_arm.get_node("Forearm") as Node3D
	_right_forearm = _right_arm.get_node("Forearm") as Node3D
	_left_leg = _leg(-1.0, shorts, jersey, trim, skin, boot, sole)
	_right_leg = _leg(1.0, shorts, jersey, trim, skin, boot, sole)
	_left_shin = _left_leg.get_node("Shin") as Node3D
	_right_shin = _right_leg.get_node("Shin") as Node3D
	# Shirt numbers stay attached to the cloth, while the small overhead marker is readable.
	_shirt_label(_body, shirt_number, Vector3(0.0, 1.27, 0.15), 0.0, 0.0035, 68)
	_shirt_label(_body, shirt_number, Vector3(0.070, 1.21, -0.15), PI, 0.0016, 46)
	_name_label = Label3D.new()
	_name_label.text = shirt_number
	_name_label.font_size = 32
	_name_label.pixel_size = 0.0034
	_name_label.position.y = 2.04
	_name_label.modulate = Color(0.86, 0.96, 1.0, 0.85)
	_name_label.outline_size = 7
	_name_label.outline_modulate = Color(0.02, 0.05, 0.08, 0.65)
	_name_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_name_label.no_depth_test = false
	_name_label.shaded = false
	add_child(_name_label)
	_built = true
	animate(0.0)


func _arm(side: float, jersey: StandardMaterial3D, jersey_dark: StandardMaterial3D, trim: StandardMaterial3D, skin: StandardMaterial3D, glove: StandardMaterial3D) -> Node3D:
	var arm: Node3D = Node3D.new()
	arm.position = Vector3(side * 0.224, 1.424, 0.0)
	_body.add_child(arm)
	_sphere(arm, Vector3(0.0, -0.015, 0.0), Vector3(0.176, 0.188, 0.18), jersey)
	_cylinder(arm, Vector3(0.0, -0.135, 0.0), 0.078, 0.068, 0.19, jersey)
	_cylinder(arm, Vector3(0.0, -0.223, 0.0), 0.070, 0.069, 0.026, jersey_dark)
	_cylinder(arm, Vector3(0.0, -0.240, 0.0), 0.070, 0.069, 0.009, trim)
	var forearm: Node3D = Node3D.new()
	forearm.name = "Forearm"
	forearm.position.y = -0.27
	arm.add_child(forearm)
	_sphere(forearm, Vector3.ZERO, Vector3(0.119, 0.122, 0.12), skin)
	_cylinder(forearm, Vector3(0.0, -0.117, 0.0), 0.057, 0.042, 0.235, skin)
	if is_keeper:
		_cylinder(forearm, Vector3(0.0, -0.224, 0.0), 0.052, 0.053, 0.052, glove)
		_sphere(forearm, Vector3(0.0, -0.286, -0.014), Vector3(0.13, 0.139, 0.092), glove)
		_box(forearm, Vector3(0.0, -0.282, -0.054), Vector3(0.064, 0.04, 0.009), trim)
	else:
		_cylinder(forearm, Vector3(0.0, -0.217, 0.0), 0.045, 0.043, 0.026, trim)
		_sphere(forearm, Vector3(0.0, -0.267, -0.012), Vector3(0.085, 0.108, 0.069), skin)
		_sphere(forearm, Vector3(-side * 0.038, -0.248, -0.025), Vector3(0.036, 0.06, 0.042), skin)
	return arm


func _leg(side: float, shorts: StandardMaterial3D, jersey: StandardMaterial3D, trim: StandardMaterial3D, skin: StandardMaterial3D, boot: StandardMaterial3D, sole: StandardMaterial3D) -> Node3D:
	var leg: Node3D = Node3D.new()
	leg.position = Vector3(side * 0.105, 1.01, 0.0)
	_body.add_child(leg)
	_cylinder(leg, Vector3(0.0, -0.091, 0.0), 0.108, 0.104, 0.215, shorts)
	_box(leg, Vector3(side * 0.101, -0.098, 0.0), Vector3(0.012, 0.163, 0.139), trim)
	_cylinder(leg, Vector3(0.0, -0.275, 0.0), 0.091, 0.074, 0.20, skin)
	_sphere(leg, Vector3(0.0, -0.395, -0.006), Vector3(0.151, 0.14, 0.148), skin)
	var shin: Node3D = Node3D.new()
	shin.name = "Shin"
	shin.position.y = -0.405
	leg.add_child(shin)
	_cylinder(shin, Vector3(0.0, -0.095, 0.0), 0.073, 0.063, 0.19, skin)
	_cylinder(shin, Vector3(0.0, -0.300, 0.0), 0.078, 0.052, 0.40, jersey)
	_cylinder(shin, Vector3(0.0, -0.104, 0.0), 0.079, 0.077, 0.037, trim)
	_cylinder(shin, Vector3(0.0, -0.137, 0.0), 0.077, 0.076, 0.011, trim)
	_box(shin, Vector3(0.0, -0.187, -0.073), Vector3(0.03, 0.043, 0.008), trim)
	_sphere(shin, Vector3(0.0, -0.5325, -0.062), Vector3(0.18, 0.145, 0.32), boot)
	_box(shin, Vector3(0.0, -0.5925, -0.067), Vector3(0.177, 0.025, 0.303), sole)
	_box(shin, Vector3(side * 0.078, -0.524, -0.074), Vector3(0.008, 0.018, 0.138), jersey)
	for lace_index: int in range(3):
		_box(shin, Vector3(0.0, -0.4695, -0.041 - float(lace_index) * 0.022), Vector3(0.065, 0.008, 0.008), trim)
	return leg


func _material(color: Color, roughness: float) -> StandardMaterial3D:
	var material: StandardMaterial3D = StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	return material


func _box(parent: Node3D, position_value: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var primitive: BoxMesh = BoxMesh.new()
	primitive.size = dimensions
	return _mesh(parent, primitive, position_value, material)


func _sphere(parent: Node3D, position_value: Vector3, dimensions: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var primitive: SphereMesh = SphereMesh.new()
	primitive.radius = 0.5
	primitive.height = 1.0
	primitive.radial_segments = 16
	primitive.rings = 8
	var instance: MeshInstance3D = _mesh(parent, primitive, position_value, material)
	instance.scale = dimensions
	return instance


func _cylinder(parent: Node3D, position_value: Vector3, top_radius: float, bottom_radius: float, height_value: float, material: StandardMaterial3D) -> MeshInstance3D:
	var primitive: CylinderMesh = CylinderMesh.new()
	primitive.top_radius = top_radius
	primitive.bottom_radius = bottom_radius
	primitive.height = height_value
	primitive.radial_segments = 16
	return _mesh(parent, primitive, position_value, material)


func _mesh(parent: Node3D, primitive: Mesh, position_value: Vector3, material: StandardMaterial3D) -> MeshInstance3D:
	var instance: MeshInstance3D = MeshInstance3D.new()
	instance.mesh = primitive
	instance.material_override = material
	instance.position = position_value
	parent.add_child(instance)
	return instance


func _tapered_box(parent: Node3D, position_value: Vector3, top_width: float, bottom_width: float, height_value: float, depth: float, material: StandardMaterial3D) -> void:
	var upper: float = top_width * 0.5
	var lower: float = bottom_width * 0.5
	var half_height: float = height_value * 0.5
	var half_depth: float = depth * 0.5
	var corners: Array[Vector3] = [
		Vector3(-lower, -half_height, -half_depth), Vector3(lower, -half_height, -half_depth),
		Vector3(lower, -half_height, half_depth), Vector3(-lower, -half_height, half_depth),
		Vector3(-upper, half_height, -half_depth), Vector3(upper, half_height, -half_depth),
		Vector3(upper, half_height, half_depth), Vector3(-upper, half_height, half_depth),
	]
	var faces: Array[Array] = [[0, 4, 5, 1], [2, 6, 7, 3], [3, 7, 4, 0], [1, 5, 6, 2], [4, 7, 6, 5], [3, 0, 1, 2]]
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for face: Array in faces:
		for index: int in [0, 1, 2, 0, 2, 3]:
			surface.add_vertex(corners[face[index]])
	surface.generate_normals()
	var generated: ArrayMesh = surface.commit()
	_mesh(parent, generated, position_value, material)


func _hair_cap(parent: Node3D, material: StandardMaterial3D, haircut: int) -> void:
	var surface: SurfaceTool = SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var sections: int = 18
	var rows: int = 5
	for row: int in range(rows):
		for section: int in range(sections):
			var theta_a: float = float(row) / float(rows) * 1.42
			var theta_b: float = float(row + 1) / float(rows) * 1.42
			var phi_a: float = float(section) / float(sections) * TAU
			var phi_b: float = float(section + 1) / float(sections) * TAU
			var points: Array[Vector3] = [
				_hair_point(theta_a, phi_a, haircut), _hair_point(theta_b, phi_a, haircut),
				_hair_point(theta_b, phi_b, haircut), _hair_point(theta_a, phi_b, haircut),
			]
			for index: int in [0, 2, 1, 0, 3, 2]:
				surface.add_vertex(points[index])
	surface.generate_normals()
	_mesh(parent, surface.commit(), Vector3.ZERO, material)
	# Short sideburns and a distinct swept fringe vary the silhouettes.
	_box(parent, Vector3(-0.117, 0.016, 0.001), Vector3(0.016, 0.075, 0.067), material)
	_box(parent, Vector3(0.117, 0.016, 0.001), Vector3(0.016, 0.075, 0.067), material)
	if haircut == 1:
		var fringe: MeshInstance3D = _sphere(parent, Vector3(-0.026, 0.104, -0.072), Vector3(0.173, 0.088, 0.096), material)
		fringe.rotation.z = -0.17
	elif haircut == 2:
		for ridge: int in range(4):
			_sphere(parent, Vector3(-0.066 + float(ridge) * 0.042, 0.134, -0.023), Vector3(0.05, 0.053, 0.17), material)


func _hair_point(theta: float, phi: float, haircut: int) -> Vector3:
	var swell: float = 0.011 if haircut == 1 else 0.004
	return Vector3(sin(theta) * cos(phi) * 0.130, cos(theta) * (0.153 + swell), sin(theta) * sin(phi) * 0.130)


func _shirt_label(parent: Node3D, value: String, position_value: Vector3, yaw: float, pixel: float, font: int) -> void:
	var label: Label3D = Label3D.new()
	label.text = value
	label.font_size = font
	label.pixel_size = pixel
	label.position = position_value
	label.rotation.y = yaw
	label.modulate = Color("f3fcfb")
	label.outline_size = 2
	label.outline_modulate = team_color.darkened(0.5)
	label.shaded = true
	label.double_sided = false
	parent.add_child(label)
