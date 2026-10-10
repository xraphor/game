class_name Footballer
extends CharacterBody3D
## Anatomical CC0 mesh, original kit and a 18-bone procedural sports rig.
## Feet at Y=0; the visible model faces local -Z.
const ATHLETE = preload("res://assets/models/athlete.glb")
const FABRIC = preload("res://shaders/fabric.gdshader")
const SKIN = preload("res://shaders/skin.gdshader")
var team_color := Color("12bfcb")
var shirt_number := "10"
var is_keeper := false
var _graphics: Node3D
var _body: Node3D
var _skeleton: Skeleton3D
var _bones: Dictionary = {}
var _rest_rotations: Dictionary = {}
var _local_rest: Dictionary = {}
var _running_time := 0.0
var _run_blend := 0.0
var _kick_time := 0.0
var _dive_time := 0.0
var _dive_side := 1.0
var _facing := 0.0
var _built := false

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
	var collision := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.23
	capsule.height = 1.76
	collision.shape = capsule
	collision.position.y = 0.88
	add_child(collision)
	_build_model()

func move_toward_direction(direction: Vector3, speed: float, delta: float) -> void:
	var flat := Vector3(direction.x, 0.0, direction.z).limit_length()
	var desired := flat * speed
	velocity.x = move_toward(velocity.x, desired.x, 23.0 * delta)
	velocity.z = move_toward(velocity.z, desired.z, 23.0 * delta)
	velocity.y = -0.4 if is_on_floor() else velocity.y - 24.0 * delta
	move_and_slide()
	if flat.length_squared() > 0.005:
		face_direction(flat, delta)

func face_direction(direction: Vector3, delta: float = 0.016) -> void:
	if Vector2(direction.x, direction.z).length_squared() < 0.0001:
		return
	_facing = lerp_angle(_facing, atan2(-direction.x, -direction.z), minf(1.0, delta * 13.0))
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

func _pose(bone_name: String, angles: Vector3) -> void:
	var rest: Quaternion = _rest_rotations[bone_name]
	var world_rotation := Quaternion.from_euler(angles)
	_skeleton.set_bone_pose_rotation(_bones[bone_name], _local_rest[bone_name] * rest.inverse() * world_rotation * rest)

func animate(delta: float) -> void:
	if not _built:
		return
	var speed := Vector2(velocity.x, velocity.z).length()
	_run_blend = move_toward(_run_blend, clampf(speed / 5.0, 0.0, 1.0), delta * 7.0)
	_running_time += delta * (5.0 + speed * 1.6)
	_kick_time = maxf(0.0, _kick_time - delta)
	_dive_time = maxf(0.0, _dive_time - delta)
	var stride := sin(_running_time) * _run_blend
	var kick := sin((1.0 - _kick_time / 0.34) * PI) if _kick_time > 0.0 else 0.0
	var dive := sin((1.0 - _dive_time / 0.9) * PI) if _dive_time > 0.0 else 0.0
	_body.position = Vector3(-_dive_side * dive * 0.20, absf(cos(_running_time)) * _run_blend * 0.025 + dive * 0.14, 0.0)
	_body.rotation = Vector3(-_run_blend * 0.065, stride * 0.025, _dive_side * dive * 1.1 - kick * 0.07)
	_pose("Chest", Vector3(0.01 + _run_blend * 0.025, -stride * 0.03, 0))
	_pose("Head", Vector3(0, stride * 0.025, 0))
	_pose("UpperArm.L", Vector3(-stride * 0.58 - kick * 0.4 + dive * 0.7, 0, -0.68 + dive * _dive_side))
	_pose("UpperArm.R", Vector3(stride * 0.58 + kick * 0.34 + dive * 0.7, 0, 0.68 + dive * _dive_side))
	_pose("LowerArm.L", Vector3(_run_blend * 0.30, 0, 0))
	_pose("LowerArm.R", Vector3(_run_blend * 0.30, 0, 0))
	_pose("Thigh.L", Vector3(stride * 0.67 + dive * 0.24, 0, -0.12))
	_pose("Thigh.R", Vector3(-stride * 0.67 + kick * 1.08 - dive * 0.24, 0, 0.12))
	_pose("Shin.L", Vector3(-maxf(0.0, -stride) * 0.85, 0, 0))
	_pose("Shin.R", Vector3(-maxf(0.0, stride) * 0.85 - kick * 0.16, 0, 0))
	_pose("Foot.L", Vector3(maxf(0.0, stride) * 0.18, 0, 0))
	_pose("Foot.R", Vector3(maxf(0.0, -stride) * 0.18, 0, 0))

func _fabric(color: Color, striped: bool = false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = FABRIC
	material.set_shader_parameter("team_color", color)
	material.set_shader_parameter("striped", striped)
	return material

func _build_model() -> void:
	_built = false
	if is_instance_valid(_graphics):
		remove_child(_graphics)
		_graphics.queue_free()
	_graphics = Node3D.new()
	_graphics.name = "SkinnedAthlete"
	_graphics.rotation.y = _facing
	add_child(_graphics)
	_body = Node3D.new()
	_graphics.add_child(_body)
	var model := ATHLETE.instantiate()
	_body.add_child(model)
	_skeleton = model.find_children("*", "Skeleton3D", true, false)[0] as Skeleton3D
	_bones.clear()
	_rest_rotations.clear()
	_local_rest.clear()
	for index in _skeleton.get_bone_count():
		var bone_name := _skeleton.get_bone_name(index)
		_bones[bone_name] = index
		_local_rest[bone_name] = _skeleton.get_bone_rest(index).basis.get_rotation_quaternion()
		_rest_rotations[bone_name] = (_body.global_basis.inverse() * _skeleton.global_basis * _skeleton.get_bone_global_rest(index).basis).get_rotation_quaternion()
	var complexions: Array[Color] = [Color("b47955"), Color("d8a57e"), Color("885739"), Color("e4b793"), Color("a76743")]
	var skin := ShaderMaterial.new()
	skin.shader = SKIN
	skin.set_shader_parameter("complexion", complexions[absi(shirt_number.hash()) % complexions.size()])
	var glove := StandardMaterial3D.new()
	glove.albedo_color = Color("c8e4a6")
	glove.roughness = 0.72
	var materials := {"Skin": skin, "Hands": glove if is_keeper else skin,
		"Jersey": _fabric(team_color, true), "Shorts": _fabric(Color("132631")), "Socks": _fabric(team_color.darkened(0.15))}
	for mesh: MeshInstance3D in model.find_children("*", "MeshInstance3D", true, false):
		for surface in mesh.mesh.get_surface_count():
			var original := mesh.mesh.surface_get_material(surface)
			if original and materials.has(original.resource_name):
				mesh.set_surface_override_material(surface, materials[original.resource_name])
	# Numbers and original club lettering on the fabric; no real team branding.
	_shirt_label(shirt_number, Vector3(0, 1.31, 0.152), 0.0, 0.0024, 64)
	_shirt_label("NUKE", Vector3(0, 1.39, -0.151), PI, 0.00085, 44)
	_built = true
	animate(0.0)

func _shirt_label(text: String, point: Vector3, angle: float, pixel: float, font: int) -> void:
	var label := Label3D.new()
	label.text = text
	label.position = point
	label.rotation.y = angle
	label.pixel_size = pixel
	label.font_size = font
	label.modulate = Color("f0f2e9")
	label.outline_size = 0
	label.shaded = true
	_body.add_child(label)
