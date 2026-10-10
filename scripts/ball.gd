extends RigidBody3D
class_name Football

const RADIUS := 0.22
var last_toucher := ""
var spin_visual: MeshInstance3D

func _ready() -> void:
	mass = 0.43
	gravity_scale = 1.0
	linear_damp = 0.16
	angular_damp = 0.2
	continuous_cd = true
	collision_layer = 4
	collision_mask = 3
	contact_monitor = true
	max_contacts_reported = 8
	var physics := PhysicsMaterial.new()
	physics.friction = 0.72
	physics.bounce = 0.53
	physics_material_override = physics
	var shape := SphereShape3D.new()
	shape.radius = RADIUS
	var collider := CollisionShape3D.new()
	collider.shape = shape
	add_child(collider)
	var sphere := SphereMesh.new()
	sphere.radius = RADIUS
	sphere.height = RADIUS * 2.0
	sphere.radial_segments = 48
	sphere.rings = 24
	spin_visual = MeshInstance3D.new()
	spin_visual.mesh = sphere
	var material := StandardMaterial3D.new()
	material.albedo_texture = _create_texture()
	material.roughness = 0.38
	material.metallic = 0.08
	spin_visual.material_override = material
	add_child(spin_visual)

func _integrate_forces(state: PhysicsDirectBodyState3D) -> void:
	# Turf drag affects the ball only near the ground; airborne shots retain pace.
	if state.transform.origin.y < RADIUS + 0.11:
		var v := state.linear_velocity
		var drag := maxf(0.0, 1.0 - 0.64 * state.step)
		v.x *= drag
		v.z *= drag
		if Vector2(v.x, v.z).length() < 0.12:
			v.x = 0.0
			v.z = 0.0
		state.linear_velocity = v

func reset_at(point: Vector3) -> void:
	global_position = point
	linear_velocity = Vector3.ZERO
	angular_velocity = Vector3.ZERO
	sleeping = false
	last_toucher = ""
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_TRANSFORM, global_transform)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_LINEAR_VELOCITY, Vector3.ZERO)
	PhysicsServer3D.body_set_state(get_rid(), PhysicsServer3D.BODY_STATE_ANGULAR_VELOCITY, Vector3.ZERO)

func launch(direction: Vector3, speed: float, lift: float, toucher: String) -> void:
	var horizontal := Vector3(direction.x, 0.0, direction.z).normalized()
	linear_velocity = horizontal * speed + Vector3.UP * lift
	angular_velocity = Vector3(-horizontal.z, 0.0, horizontal.x) * speed / RADIUS
	last_toucher = toucher
	sleeping = false

func _create_texture() -> ImageTexture:
	# Original latitude/longitude panel pattern with small leather-grain variation.
	var image := Image.create(512, 256, false, Image.FORMAT_RGB8)
	for y in range(256):
		for x in range(512):
			var row: int = int(y / 43.0)
			var cell: int = int((x + (row % 2) * 32) / 64.0)
			var edge: bool = (x + (row % 2) * 32) % 64 < 2 or y % 43 < 2
			var dark: bool = (cell + row * 2) % 5 == 0
			var grain := float((x * 17 + y * 23) % 7) / 255.0
			var color := Color(0.86 + grain, 0.9 + grain, 0.86 + grain)
			if dark:
				color = Color(0.025 + grain, 0.07 + grain, 0.105 + grain)
			if edge:
				color = Color(0.2, 0.25, 0.25)
			image.set_pixel(x, y, color)
	return ImageTexture.create_from_image(image)
