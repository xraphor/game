extends RigidBody3D
class_name Football

const RADIUS := 0.22
var last_toucher := ""
var spin_visual: Node3D

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
	spin_visual = preload("res://assets/models/football.glb").instantiate()
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
