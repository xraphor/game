extends SceneTree
## Integration checks run the real stadium, actors, ball and HUD in Godot physics.
## Run: godot --headless --path . --script res://tests/run_tests.gd

var game
var passed: int = 0
var failed: int = 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var scene: PackedScene = load("res://scenes/main.tscn")
	if scene == null:
		push_error("Could not load the playable scene")
		quit(1)
		return
	game = scene.instantiate()
	game.testing = true
	root.add_child(game)
	await _frames(3)
	_check(game.state == game.State.MENU and game.ball.freeze, "Scene starts in the menu with the ball frozen")
	game.hud._start_button.pressed.emit()
	await _frames(3)
	_check(game.state == game.State.PLAYING and not game.ball.freeze, "Menu start button opens a live session")

	await _ball_physics()
	await _movement_and_input()
	await _shots_and_pass_cooldowns()
	await _goal_scoring()
	await _keeper_behavior()
	await _defender_behavior()
	await _partner_behavior()
	await _cone_exercise()
	await _reset_pause_and_menu()
	await _session_results()
	_quality_options()
	_release_inputs()
	paused = false
	game.queue_free()
	await process_frame
	print("RESULT: %d PASS, %d FAIL" % [passed, failed])
	quit(0 if failed == 0 else 1)


func _check(condition: bool, description: String, evidence: String = "") -> void:
	if condition:
		passed += 1
		print("PASS: ", description)
	else:
		failed += 1
		printerr("FAIL: ", description, " | ", evidence)


func _frames(count: int) -> void:
	for frame: int in range(count):
		await physics_frame
		await process_frame


func _release_inputs() -> void:
	for action: String in ["move_up", "move_down", "move_left", "move_right", "sprint", "shoot", "pass"]:
		Input.action_release(action)


func _session(exercise: int = 1, difficulty: int = 1) -> void:
	_release_inputs()
	game.exercise = exercise
	game.difficulty = difficulty
	game.defender_enabled = false
	game.testing = true
	game.start_session()
	await _frames(3)


func _action_event(action: String, pressed_value: bool) -> void:
	var event: InputEventAction = InputEventAction.new()
	event.action = action
	event.pressed = pressed_value
	Input.parse_input_event(event)
	await process_frame


func _key_event(key: int) -> void:
	var event: InputEventKey = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = true
	Input.parse_input_event(event)
	await process_frame
	event = InputEventKey.new()
	event.physical_keycode = key
	event.pressed = false
	Input.parse_input_event(event)
	await process_frame


func _ball_physics() -> void:
	print("CHECK: real gravity, bounce, floor contact and turf drag")
	await _session()
	game.ball.reset_at(Vector3(8, 3, 10))
	await _frames(12)
	_check(game.ball.global_position.y < 2.95 and game.ball.linear_velocity.y < -1.0, "Gravity makes a dropped ball fall", str(game.ball.global_position, " velocity=", game.ball.linear_velocity))
	var bounced: bool = false
	for frame: int in range(100):
		await _frames(1)
		if game.ball.linear_velocity.y > 0.7:
			bounced = true
	_check(bounced, "Ball bounces off the actual stadium surface")
	await _frames(120)
	_check(game.ball.global_position.y > 0.18 and game.ball.global_position.y < 0.29 and game.ball.linear_velocity.length() < 0.4, "Ball settles above the grass without sinking", str(game.ball.global_position, " velocity=", game.ball.linear_velocity))
	game.ball.reset_at(Vector3(0, 0.24, 12))
	game.ball.launch(Vector3.RIGHT, 7.0, 0.0, "test")
	await _frames(30)
	var ground_speed: float = Vector2(game.ball.linear_velocity.x, game.ball.linear_velocity.z).length()
	_check(game.ball.global_position.x > 1.0 and ground_speed < 6.5, "Ground ball moves freely and slows on turf", str("x=", game.ball.global_position.x, " speed=", ground_speed))
	game.ball.reset_at(Vector3(0, 3.0, 12))
	game.ball.launch(Vector3.RIGHT, 7.0, 0.0, "test")
	await _frames(30)
	var air_speed: float = Vector2(game.ball.linear_velocity.x, game.ball.linear_velocity.z).length()
	_check(game.ball.global_position.y > 1.0 and air_speed > ground_speed * 1.15, "Airborne ball retains more pace than a rolling ball", str("air=", air_speed, " ground=", ground_speed, " y=", game.ball.global_position.y))


func _movement_and_input() -> void:
	print("CHECK: floor support and keyboard movement")
	await _session()
	game.camera_mode = 1
	game._update_camera(1.0, true)
	game.ball.reset_at(Vector3(-12, 0.26, 12))
	await _frames(15)
	_check(game.player.is_on_floor() and absf(game.player.global_position.y) < 0.12, "Player stands on the stadium floor", str(game.player.global_position))
	var start: Vector3 = game.player.global_position
	Input.action_press("move_right")
	await _frames(40)
	Input.action_release("move_right")
	var walk_distance: float = game.player.global_position.distance_to(start)
	_check(walk_distance > 2.5 and game.player.global_position.x > start.x + 2.5, "Movement action moves the player in camera-relative direction", str("walk=", walk_distance, " position=", game.player.global_position))
	game.player.global_position = start
	game.player.velocity = Vector3.ZERO
	Input.action_press("move_right")
	Input.action_press("sprint")
	await _frames(40)
	_release_inputs()
	var sprint_distance: float = game.player.global_position.distance_to(start)
	_check(sprint_distance > walk_distance * 1.25, "Shift sprint covers more distance than walking", str("sprint=", sprint_distance, " walk=", walk_distance))
	await _frames(26)
	_check(Vector2(game.player.velocity.x, game.player.velocity.z).length() < 0.1, "Releasing movement decelerates the player to a stop", str(game.player.velocity))
	var initial_camera: int = game.camera_mode
	await _key_event(KEY_C)
	_check(game.camera_mode == (initial_camera + 1) % 3, "C shortcut cycles camera mode")


func _shots_and_pass_cooldowns() -> void:
	print("CHECK: shot power, proximity, cooldowns and charge input")
	await _session()
	var low_origin: Vector3 = game.ball.global_position
	_check(game.shoot_ball(0.0), "Nearby low-power shot is accepted")
	var low_speed: float = game.ball.linear_velocity.length()
	_check(game.attempts == 1 and not game.shoot_ball(1.0) and game.attempts == 1, "Shot cooldown prevents duplicate attempts")
	await _frames(20)
	var low_distance: float = game.ball.global_position.distance_to(low_origin)
	var low_height: float = game.ball.global_position.y
	game._reset_positions()
	await _frames(3)
	var high_origin: Vector3 = game.ball.global_position
	_check(game.shoot_ball(1.0), "Nearby high-power shot is accepted after reset")
	var high_speed: float = game.ball.linear_velocity.length()
	await _frames(20)
	_check(high_speed > low_speed * 1.8 and game.ball.global_position.distance_to(high_origin) > low_distance * 1.5 and game.ball.global_position.y > low_height + 0.6, "More shot power produces faster, farther, higher flight in physics", str("speeds=", low_speed, "/", high_speed, " distance=", low_distance, "/", game.ball.global_position.distance_to(high_origin), " heights=", low_height, "/", game.ball.global_position.y))
	game._reset_positions()
	await _frames(3)
	var attempts_before: int = game.attempts
	game.ball.reset_at(game.player.global_position + Vector3(5, 0.22, 0))
	_check(not game.shoot_ball(0.5) and game.attempts == attempts_before and game.kick_cooldown <= 0.0, "Remote shot is rejected without consuming an attempt or cooldown")
	game._reset_positions()
	await _frames(3)
	_check(game.pass_ball() and game.attempts == attempts_before and game.kick_cooldown > 0.0, "Pass launches the ball and sets a cooldown without counting a shot")
	_check(not game.shoot_ball(0.3) and game.attempts == attempts_before, "Pass cooldown also prevents an immediate shot")
	game._reset_positions()
	await _frames(3)
	await _action_event("shoot", true)
	await _frames(24)
	_check(game.charging and game.shot_charge > 0.25 and game.attempts == attempts_before, "Holding shoot charges without taking an attempt", str("charging=", game.charging, " power=", game.shot_charge))
	await _action_event("shoot", false)
	_check(not game.charging and game.shot_charge == 0.0 and game.attempts == attempts_before + 1 and game.ball.last_toucher == "player", "Releasing shoot launches exactly one charged shot")


func _goal_scoring() -> void:
	print("CHECK: real shot through the goal and geometric edge cases")
	await _session()
	game.player.global_position = Vector3(0, 0.02, -24)
	game.ball.reset_at(Vector3(0, 0.3, -25.2))
	game.last_ball_position = game.ball.global_position
	game.aim_direction = Vector3.FORWARD
	_check(game.shoot_ball(0.4), "Scoring test starts with an actual player shot")
	for frame: int in range(50):
		await _frames(1)
		if game.ball_scored:
			break
	_check(game.goals == 1 and game.ball_scored and game.ball.global_position.z < -28.22 and game.pending_reset > 0.0, "Real ball crossing the complete goal line increments the score", str("goals=", game.goals, " ball=", game.ball.global_position, " reset=", game.pending_reset))
	await _frames(40)
	_check(game.goals == 1, "Ball remaining in the net does not score twice")
	_check(game.is_goal_crossing(Vector3(0, 1, -27.9), Vector3(0, 1, -28.4)), "Goal opening accepts a full inward crossing")
	_check(not game.is_goal_crossing(Vector3(0, 1, -27.9), Vector3(0, 1, -28.1)), "Partial ball crossing is not a goal")
	_check(not game.is_goal_crossing(Vector3(3.55, 1, -27.9), Vector3(3.55, 1, -28.4)), "Ball overlapping a side post is outside the goal opening")
	_check(not game.is_goal_crossing(Vector3(0, 2.35, -27.9), Vector3(0, 2.35, -28.4)), "Ball above the available crossbar clearance does not score")
	_check(not game.is_goal_crossing(Vector3(0, 1, -28.4), Vector3(0, 1, -27.9)), "Ball leaving the net does not score")


func _keeper_behavior() -> void:
	print("CHECK: goalkeeper reaction and an actual save")
	await _session(0, 2)
	game.player.global_position = Vector3(10, 0.02, -12)
	game.ball.reset_at(Vector3(2.5, 0.5, -18))
	game.ball.launch(Vector3.FORWARD, 12.0, 0.0, "player")
	game.last_ball_position = game.ball.global_position
	game.bot_clock = 0.0
	var keeper_start: Vector3 = game.keeper.global_position
	await _frames(12)
	_check(game.keeper_target.x > 1.8 and game.keeper.global_position.x > keeper_start.x + 0.25 and game.keeper.global_position.x < keeper_start.x + 1.4, "Goalkeeper predicts a shot and moves toward it at a bounded speed", str("keeper=", game.keeper.global_position, " target=", game.keeper_target))
	game._reset_positions()
	game.player.global_position = Vector3(8, 0.02, -20)
	game.ball.reset_at(Vector3(0, 0.55, -25.0))
	game.ball.launch(Vector3.FORWARD, 8.0, 0.0, "player")
	game.last_ball_position = game.ball.global_position
	for frame: int in range(35):
		await _frames(1)
		if game.ball.last_toucher == "keeper":
			break
	_check(game.ball.last_toucher == "keeper" and game.ball.linear_velocity.z > 0.0 and game.keeper_cooldown > 0.0 and game.keeper._dive_time > 0.0 and game.goals == 0, "Goalkeeper saves a real incoming ball and starts a dive", str("toucher=", game.ball.last_toucher, " velocity=", game.ball.linear_velocity, " cooldown=", game.keeper_cooldown))


func _defender_behavior() -> void:
	print("CHECK: defender pursuit and tackle without teleporting")
	await _session(4)
	game.player.global_position = Vector3(0, 0.02, 10)
	game.defender.global_position = Vector3(5, 0.02, -4)
	game.defender.velocity = Vector3.ZERO
	game.defender_cooldown = 0.0
	game.ball.reset_at(Vector3(1, 0.26, -5))
	game.last_ball_position = game.ball.global_position
	game.bot_clock = 0.0
	var initial_distance: float = game.defender.global_position.distance_to(game.ball.global_position)
	var largest_step: float = 0.0
	for frame: int in range(32):
		var previous: Vector3 = game.defender.global_position
		await _frames(1)
		largest_step = maxf(largest_step, previous.distance_to(game.defender.global_position))
	_check(game.defender.global_position.distance_to(game.ball.global_position) < initial_distance - 0.7 and largest_step < 0.2, "Defender closes the distance using continuous physical movement", str("distance=", initial_distance, "/", game.defender.global_position.distance_to(game.ball.global_position), " largest step=", largest_step))
	for frame: int in range(100):
		await _frames(1)
		if game.ball.last_toucher == "defender":
			break
	_check(game.ball.last_toucher == "defender" and game.ball.linear_velocity.length() > 5.0 and game.defender_cooldown > 0.0, "Defender reaches a nearby ball and tackles it away", str("toucher=", game.ball.last_toucher, " ball=", game.ball.global_position, " defender=", game.defender.global_position))


func _partner_behavior() -> void:
	print("CHECK: actual pass and companion return")
	await _session(2)
	game.player.global_position = Vector3(0, 0.02, 4)
	game.partner.global_position = Vector3(-3, 0.02, 0)
	game.partner.velocity = Vector3.ZERO
	game.ball.reset_at(Vector3(0, 0.3, 3))
	game.partner_cooldown = 0.0
	_check(game.pass_ball(), "Player can pass toward the support player")
	for frame: int in range(90):
		await _frames(1)
		if game.passes_completed > 0:
			break
	var return_direction: Vector3 = game.player.global_position - game.ball.global_position
	_check(game.passes_completed == 1 and game.ball.last_toucher == "partner" and game.ball.linear_velocity.dot(return_direction) > 0.0 and game.partner_cooldown > 0.0, "Moving support player receives a real pass and sends it back", str("passes=", game.passes_completed, " toucher=", game.ball.last_toucher, " positions=", game.ball.global_position, "/", game.partner.global_position))
	await _frames(10)
	_check(game.passes_completed == 1 and game.attempts == 0, "A single passing exchange counts once and does not create a shot attempt")


func _cone_exercise() -> void:
	print("CHECK: ordered gates require ball and athlete proximity")
	await _session(1)
	var obstacles: Array[StaticBody3D] = []
	for ring: MeshInstance3D in game.cone_rings:
		for child: Node in ring.get_parent().get_children():
			if child is StaticBody3D:
				obstacles.append(child)
	var inactive: bool = obstacles.size() == 10
	for obstacle: StaticBody3D in obstacles:
		inactive = inactive and obstacle.collision_layer == 0 and not obstacle.get_parent().visible
	_check(inactive, "Cones outside their exercise are hidden and have no collision layer")
	var cone_position: Vector3 = obstacles[0].global_position
	var cone_ray: PhysicsRayQueryParameters3D = PhysicsRayQueryParameters3D.create(cone_position + Vector3.LEFT * 0.5, cone_position + Vector3.RIGHT * 0.5, 1)
	_check(game.get_world_3d().direct_space_state.intersect_ray(cone_ray).is_empty(), "Actual physics ray passes through an inactive cone position")
	await _session(3)
	var active: bool = obstacles.size() == 10
	for obstacle: StaticBody3D in obstacles:
		active = active and obstacle.collision_layer == 1 and obstacle.get_parent().visible
	_check(active, "Cone exercise enables every visible cone collider")
	var cone_hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(cone_ray)
	_check(not cone_hit.is_empty() and cone_hit.get("collider") == obstacles[0], "Actual physics ray collides with the active cone")
	game.ball.reset_at(game.CONE_ROUTE[0] + Vector3.UP * 0.26)
	await _frames(3)
	_check(game.cone_index == 0, "Remote ball reaching a gate alone does not complete it")
	game.player.global_position = game.CONE_ROUTE[1] + Vector3(0, 0.02, 1)
	game.ball.reset_at(game.CONE_ROUTE[1] + Vector3.UP * 0.26)
	await _frames(3)
	_check(game.cone_index == 0, "Later gate cannot be completed before the first gate")
	game.player.global_position = game.CONE_ROUTE[0] + Vector3(0, 0.02, 1)
	game.ball.reset_at(game.CONE_ROUTE[0] + Vector3.UP * 1.2)
	await _frames(2)
	_check(game.cone_index == 0, "Airborne ball over a gate is not treated as dribbling")
	for index: int in range(game.CONE_ROUTE.size()):
		game.player.global_position = game.CONE_ROUTE[index] + Vector3(0, 0.02, 1)
		game.player.velocity = Vector3.ZERO
		game.ball.reset_at(game.CONE_ROUTE[index] + Vector3.UP * 0.26)
		await _frames(3)
		_check(game.cone_index == index + 1, "Player and grounded ball complete gate %d in sequence" % (index + 1), str("index=", game.cone_index))
	_check(game._objective_completed(), "All five gates complete the dribbling objective")
	game._reset_positions()
	game.ball.reset_at(Vector3(9, 0.26, 9))
	_check(not game.shoot_ball(1.0) and game.attempts == 0, "Cone mode rejects remote shooting just like other exercises")


func _reset_pause_and_menu() -> void:
	print("CHECK: reset state, real pause, menu and restart")
	await _session()
	game.goals = 2
	game.attempts = 4
	game.player.global_position = Vector3(12, 1, 20)
	game.player.velocity = Vector3(3, 4, 5)
	game.ball.launch(Vector3.LEFT, 20, 5, "player")
	game.charging = true
	game.shot_charge = 0.8
	game.pending_reset = 0.2
	game.ball_scored = true
	for actor in [game.player, game.keeper, game.defender, game.partner]:
		actor.rotation.y = 0.74
		actor.face_direction(Vector3.LEFT, 1.0)
	game._reset_positions()
	_check(game.player.global_position.distance_to(Vector3(0, 0.04, 9)) < 0.001 and game.player.velocity == Vector3.ZERO and game.ball.linear_velocity == Vector3.ZERO and game.ball.angular_velocity == Vector3.ZERO and game.ball.last_toucher == "", "Reset restores positions and removes ball and actor momentum")
	_check((-game.player._graphics.global_basis.z).normalized().dot(Vector3.FORWARD) > 0.99, "Reset makes the player's visible model face the goal")
	_check((-game.keeper._graphics.global_basis.z).normalized().dot(Vector3.BACK) > 0.99, "Reset makes the goalkeeper's visible model face the player side")
	_check((-game.defender._graphics.global_basis.z).normalized().dot(Vector3.BACK) > 0.99, "Reset makes the defender's visible model face the player side")
	var partner_direction: Vector3 = game.player.global_position - game.partner.global_position
	partner_direction.y = 0.0
	_check((-game.partner._graphics.global_basis.z).normalized().dot(partner_direction.normalized()) > 0.99, "Reset makes the support player's visible model face the player")
	_check(not game.charging and game.shot_charge == 0.0 and not game.ball_scored and game.pending_reset < 0.0 and game.kick_cooldown == 0.0, "Reset clears charge, scoring latch, pending reset and cooldowns")
	_check(game.goals == 2 and game.attempts == 4, "Exercise reset preserves session statistics")
	game.ball.reset_at(Vector3(5, 0.3, 12))
	await _key_event(KEY_R)
	_check(game.ball.global_position.distance_to(Vector3(0, 0.26, 7.45)) < 0.1, "R shortcut resets the exercise through the input pipeline")
	game.ball.reset_at(Vector3(5, 0.3, 12))
	game.ball.launch(Vector3.RIGHT, 6, 2, "test")
	Input.action_press("move_right")
	await _frames(5)
	game.charging = true
	game.shot_charge = 0.4
	await _key_event(KEY_ESCAPE)
	_check(game.state == game.State.PAUSED and paused and not game.charging and game.shot_charge == 0.0, "Escape pauses the session and cancels charge")
	var ball_position: Vector3 = game.ball.global_position
	var player_position: Vector3 = game.player.global_position
	var partner_position: Vector3 = game.partner.global_position
	var elapsed_before: float = game.elapsed
	await _frames(20)
	_check(game.ball.global_position.distance_to(ball_position) < 0.00001 and game.player.global_position.distance_to(player_position) < 0.00001 and game.partner.global_position.distance_to(partner_position) < 0.00001 and game.elapsed == elapsed_before, "Paused physics keeps the ball, player, bots and clock stationary")
	await _key_event(KEY_ESCAPE)
	await _frames(15)
	_release_inputs()
	_check(game.state == game.State.PLAYING and not paused and game.ball.global_position.distance_to(ball_position) > 0.3 and game.elapsed > elapsed_before, "Escape resumes actual physics and the session clock")
	game.hud.menu_requested.emit()
	await _frames(3)
	_check(game.state == game.State.MENU and game.ball.freeze and not paused, "Menu action restores the frozen menu state")
	game.passes_completed = 2
	game.cone_index = 3
	game.targets_hit.fill(true)
	game.hud.start_requested.emit()
	await _frames(3)
	_check(game.state == game.State.PLAYING and game.goals == 0 and game.attempts == 0 and game.passes_completed == 0 and game.cone_index == 0 and game.targets_hit.count(true) == 0 and game.elapsed < 0.3, "Starting from the menu resets every session statistic")


func _session_results() -> void:
	print("CHECK: timed finish and challenge completion")
	await _session()
	game.testing = false
	game.elapsed = game.SESSION_TIME
	await _frames(2)
	_check(game.state == game.State.FINISHED and paused, "Time expiry opens the result screen and pauses the field")
	game.hud.restart_requested.emit()
	await _frames(3)
	_check(game.state == game.State.PLAYING and not paused and game.elapsed < 0.3 and game.goals == 0, "Result restart begins a fresh live session")
	game.exercise = 3
	game.cone_index = game.CONE_ROUTE.size()
	await _frames(2)
	_check(game.state == game.State.FINISHED and paused, "Completing the exercise opens the victory result")
	game.testing = true
	game.start_session()


func _quality_options() -> void:
	print("CHECK: visual quality configuration")
	for index: int in range(3):
		game.hud.quality_changed.emit(index)
		var expected_msaa: int = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][index]
		var crowd_visible: bool = game.stadium.crowd_nodes[0].visible
		_check(game.stadium.quality == index and game.get_viewport().msaa_3d == expected_msaa and game.stadium.sun.shadow_enabled == (index > 0) and crowd_visible == (index > 0), "Quality option %d updates stadium and viewport settings" % index)
