extends Node3D
class_name FootballGame

const AvatarScript = preload("res://scripts/footballer.gd")
const StadiumScript = preload("res://scripts/stadium.gd")
const HUDScript = preload("res://scripts/hud.gd")
const BallScript = preload("res://scripts/ball.gd")
const SoundScript = preload("res://scripts/sound.gd")
const GamepadScript = preload("res://scripts/gamepad.gd")
const SESSION_TIME := 90.0
const GOAL_Z := -28.0
const GOAL_HALF_WIDTH := 3.66
const GOAL_HEIGHT := 2.44
const BALL_RADIUS := 0.22
const CONE_ROUTE: Array[Vector3] = [Vector3(-4, 0, 4), Vector3(4, 0, -2), Vector3(-4, 0, -9), Vector3(4, 0, -16), Vector3(0, 0, -22)]
enum State { MENU, PLAYING, PAUSED, FINISHED }

var state := State.MENU
var testing := false
var difficulty := 1
var exercise := 0
var defender_enabled := true
var camera_mode := 1
var goals := 0
var attempts := 0
var passes_completed := 0
var cone_index := 0
var targets_hit: Array[bool] = [false, false, false]
var elapsed := 0.0
var shot_charge := 0.0
var charging := false
var aim_direction := Vector3.FORWARD
var move_direction := Vector3.ZERO
var mouse_aim := false
var pending_reset := -1.0
var last_ball_position := Vector3.ZERO
var ball_scored := false
var dribble_cooldown := 0.0
var kick_cooldown := 0.0
var defender_cooldown := 0.0
var keeper_cooldown := 0.0
var partner_cooldown := 0.0
var bot_clock := 0.0
var keeper_target := Vector3(0, 0, -26.8)
var defender_target := Vector3(3, 0, -6)
var defender_state := "MARCAR"
var companion_state := "APOIAR"
var player
var keeper
var defender
var partner
var ball
var stadium
var hud
var sound
var gamepad: GamepadScript
var camera: Camera3D
var aim_arrow: Node3D
var trajectory: Array[MeshInstance3D] = []
var exercise_objects: Node3D
var cone_rings: Array[MeshInstance3D] = []
var goal_targets: Array[MeshInstance3D] = []
var capture_frames := 0
var capture_path := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_setup_input()
	stadium = StadiumScript.new()
	stadium.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(stadium)
	player = _make_footballer("Você", Color("18bcd3"), "10")
	var player_ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 0.46
	ring_mesh.outer_radius = 0.51
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	player_ring.mesh = ring_mesh
	player_ring.material_override = _bright_material(Color("dbff78"))
	player_ring.position.y = 0.025
	player_ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	player.add_child(player_ring)
	keeper = _make_footballer("Goleiro", Color("ff9c48"), "01", true)
	defender = _make_footballer("Defensor", Color("ef5d52"), "04")
	partner = _make_footballer("Apoio", Color("18bcd3"), "07")
	ball = BallScript.new()
	ball.name = "Bola"
	ball.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(ball)
	sound = SoundScript.new()
	add_child(sound)
	camera = Camera3D.new()
	camera.fov = 58.0
	camera.near = 0.1
	camera.far = 250.0
	add_child(camera)
	camera.current = true
	camera.position = Vector3(17, 8.5, 22)
	camera.look_at(Vector3(-1, 0.4, -9))
	_build_aim_indicator()
	_build_exercise_objects()
	hud = HUDScript.new()
	add_child(hud)
	hud.start_requested.connect(start_session)
	hud.resume_requested.connect(resume_game)
	hud.restart_requested.connect(start_session)
	hud.menu_requested.connect(return_to_menu)
	hud.difficulty_changed.connect(func(index: int): difficulty = index)
	hud.exercise_changed.connect(_change_exercise)
	hud.quality_changed.connect(_change_quality)
	hud.defender_changed.connect(func(enabled: bool): defender_enabled = enabled; _update_visibility())
	gamepad = GamepadScript.new()
	gamepad.device_changed.connect(func(connected: bool, _device_name: String): hud.set_controller(gamepad.using_controller, connected))
	gamepad.source_changed.connect(func(using_controller: bool): hud.set_controller(using_controller, gamepad.active_device >= 0))
	gamepad.active_disconnected.connect(_controller_disconnected)
	add_child(gamepad)
	hud.set_controller(gamepad.using_controller, gamepad.active_device >= 0)
	_change_quality(2)
	_reset_positions()
	_update_visibility()
	ball.freeze = true
	hud.show_menu()
	for argument in OS.get_cmdline_user_args():
		if argument == "--showcase":
			start_session()
		if argument.begins_with("--capture="):
			capture_path = argument.trim_prefix("--capture=")

func _make_footballer(actor_name: String, color: Color, number: String, goalkeeper: bool = false):
	var actor = AvatarScript.new()
	actor.name = actor_name
	actor.configure(color, number, goalkeeper)
	actor.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(actor)
	actor.collision_mask = 3
	return actor

func _setup_input() -> void:
	_action("move_up", [KEY_W, KEY_UP])
	_action("move_down", [KEY_S, KEY_DOWN])
	_action("move_left", [KEY_A, KEY_LEFT])
	_action("move_right", [KEY_D, KEY_RIGHT])
	_action("sprint", [KEY_SHIFT], JOY_BUTTON_RIGHT_SHOULDER)
	_action("shoot", [KEY_SPACE], JOY_BUTTON_A, MOUSE_BUTTON_LEFT)
	_action("pass", [KEY_E], JOY_BUTTON_X)
	_action("reset", [KEY_R], JOY_BUTTON_Y)
	_action("camera", [KEY_C], JOY_BUTTON_B)
	_action("pause", [KEY_ESCAPE], JOY_BUTTON_START)
	_action("zoom_in", [], -1, MOUSE_BUTTON_WHEEL_UP)
	_action("zoom_out", [], -1, MOUSE_BUTTON_WHEEL_DOWN)
	_action("controls", [KEY_F1], JOY_BUTTON_BACK)
	for mapping in [["camera", JOY_BUTTON_LEFT_SHOULDER], ["zoom_in", JOY_BUTTON_DPAD_UP], ["zoom_out", JOY_BUTTON_DPAD_DOWN]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = mapping[1]
		InputMap.action_add_event(mapping[0], event)
	# Built-in UI defaults can be limited to device 0; accept every mapped pad.
	for mapping in [["ui_accept", JOY_BUTTON_A], ["ui_cancel", JOY_BUTTON_B], ["ui_up", JOY_BUTTON_DPAD_UP], ["ui_down", JOY_BUTTON_DPAD_DOWN], ["ui_left", JOY_BUTTON_DPAD_LEFT], ["ui_right", JOY_BUTTON_DPAD_RIGHT]]:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = mapping[1]
		InputMap.action_add_event(mapping[0], event)
	for mapping in [["ui_up", JOY_AXIS_LEFT_Y, -1.0], ["ui_down", JOY_AXIS_LEFT_Y, 1.0], ["ui_left", JOY_AXIS_LEFT_X, -1.0], ["ui_right", JOY_AXIS_LEFT_X, 1.0]]:
		var event := InputEventJoypadMotion.new()
		event.device = -1
		event.axis = mapping[1]
		event.axis_value = mapping[2]
		InputMap.action_add_event(mapping[0], event)


func _action(action: String, keys: Array, joy_button: int = -1, mouse_button: int = -1) -> void:
	if InputMap.has_action(action):
		return
	InputMap.add_action(action)
	for key in keys:
		var event := InputEventKey.new()
		event.physical_keycode = key
		InputMap.action_add_event(action, event)
	if joy_button >= 0:
		var event := InputEventJoypadButton.new()
		event.device = -1
		event.button_index = joy_button
		InputMap.action_add_event(action, event)
	if mouse_button >= 0:
		var event := InputEventMouseButton.new()
		event.button_index = mouse_button
		InputMap.action_add_event(action, event)

func start_session() -> void:
	get_tree().paused = false
	state = State.PLAYING
	goals = 0
	attempts = 0
	passes_completed = 0
	cone_index = 0
	elapsed = 0.0
	targets_hit = [false, false, false]
	charging = false
	shot_charge = 0.0
	aim_direction = Vector3.FORWARD
	mouse_aim = false
	_reset_positions()
	ball.freeze = false
	_update_visibility()
	hud.show_game()
	hud.toast("Treino iniciado • mire no gol e solte o chute", 3.5)
	_update_camera(1.0, true)

func _reset_positions() -> void:
	player.global_position = Vector3(0, 0.04, 9)
	keeper.global_position = Vector3(0, 0.04, -26.8)
	defender.global_position = Vector3(4, 0.04, -8)
	partner.global_position = Vector3(-8, 0.04, 0)
	for actor in [player, keeper, defender, partner]:
		actor.velocity = Vector3.ZERO
		actor.rotation.y = 0.0
		actor.reset_pose()
	player.face_direction(Vector3.FORWARD, 1.0)
	defender.face_direction(Vector3.BACK, 1.0)
	keeper.face_direction(Vector3.BACK, 1.0)
	partner.face_direction(player.global_position - partner.global_position, 1.0)
	ball.reset_at(Vector3(0, 0.26, 7.45))
	last_ball_position = ball.global_position
	pending_reset = -1.0
	ball_scored = false
	dribble_cooldown = 0.0
	kick_cooldown = 0.0
	defender_cooldown = 0.8
	keeper_cooldown = 0.0
	partner_cooldown = 0.4
	bot_clock = 0.0
	keeper_target = keeper.global_position
	defender_target = defender.global_position
	charging = false
	shot_charge = 0.0
	_update_marker_colors()

func reset_exercise() -> void:
	if state == State.PLAYING:
		_reset_positions()
		hud.toast("Bola reposta. Vamos de novo!")

func pause_game() -> void:
	if state != State.PLAYING:
		return
	state = State.PAUSED
	gamepad.stop_vibration()
	charging = false
	shot_charge = 0.0
	get_tree().paused = true
	hud.show_pause()

func resume_game() -> void:
	if state == State.FINISHED:
		start_session()
		return
	if state != State.PAUSED:
		return
	state = State.PLAYING
	get_tree().paused = false
	hud.show_game()

func return_to_menu() -> void:
	get_tree().paused = false
	state = State.MENU
	charging = false
	shot_charge = 0.0
	_reset_positions()
	ball.freeze = true
	hud.show_menu()

func _controller_disconnected() -> void:
	if state == State.PLAYING:
		pause_game()
	hud.toast("Controle desconectado. Reconecte ou use o teclado.", 4.0)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("controls"):
		if state == State.PLAYING:
			pause_game()
		if state == State.PAUSED:
			hud.toast("Os comandos completos estão no painel de pausa.", 3.0)
		get_viewport().set_input_as_handled()
		return
	if event is InputEventJoypadButton and event.pressed and event.button_index == JOY_BUTTON_B and state in [State.PAUSED, State.FINISHED]:
		if state == State.PAUSED:
			resume_game()
		else:
			return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if event.is_action_pressed("pause") and not event.is_echo():
		if state == State.PAUSED:
			resume_game()
		elif state == State.PLAYING:
			pause_game()
		elif state == State.FINISHED:
			return_to_menu()
		get_viewport().set_input_as_handled()
		return
	if state != State.PLAYING:
		return
	if event is InputEventMouseMotion:
		mouse_aim = true
	if event.is_action_pressed("reset"):
		reset_exercise()
	if event.is_action_pressed("camera"):
		camera_mode = (camera_mode + 1) % 3
		hud.toast(["Câmera de treino", "Câmera em terceira pessoa", "Câmera de transmissão"][camera_mode])
	if event.is_action_pressed("pass"):
		pass_ball()
	if event.is_action_pressed("shoot") and kick_cooldown <= 0.0:
		charging = true
		shot_charge = 0.0
	if event.is_action_released("shoot") and charging:
		shoot_ball(shot_charge)
		charging = false
		shot_charge = 0.0
	if event.is_action_pressed("zoom_in"):
		camera.fov = maxf(40.0, camera.fov - 3.0)
	if event.is_action_pressed("zoom_out"):
		camera.fov = minf(76.0, camera.fov + 3.0)

func _physics_process(delta: float) -> void:
	if state != State.PLAYING:
		return
	elapsed += delta
	dribble_cooldown -= delta
	kick_cooldown -= delta
	defender_cooldown -= delta
	keeper_cooldown -= delta
	partner_cooldown -= delta
	_update_aim()
	_move_player(delta)
	if charging:
		shot_charge = minf(1.0, shot_charge + delta / 1.15)
	_dribble()
	_update_bots(delta)
	_check_goal()
	_check_cones()
	_check_bounds(delta)
	last_ball_position = ball.global_position
	if elapsed >= SESSION_TIME and not testing:
		_finish_session(false)
	elif _objective_completed() and not testing:
		_finish_session(true)

func _process(delta: float) -> void:
	_update_camera(delta)
	if state == State.PLAYING:
		aim_arrow.visible = true
		aim_arrow.global_position = Vector3(ball.global_position.x, 0.035, ball.global_position.z)
		aim_arrow.rotation.y = atan2(-aim_direction.x, -aim_direction.z)
		_update_trajectory()
		hud.update_stats(goals, attempts, maxf(0.0, SESSION_TIME - elapsed), shot_charge, _objective_text())
		hud.update_minimap(player.global_position, ball.global_position, keeper.global_position, defender.global_position, partner.global_position, _defender_active())
	else:
		aim_arrow.visible = false
		for dot in trajectory:
			dot.visible = false
	if not capture_path.is_empty():
		capture_frames += 1
		if capture_frames == 24 and DisplayServer.get_name() != "headless":
			await RenderingServer.frame_post_draw
			var capture := get_viewport().get_texture().get_image()
			var result := capture.save_png(capture_path)
			print("CAPTURE ", capture_path, " status=", result)
			get_tree().quit(0 if result == OK else 1)

func _move_player(delta: float) -> void:
	var stick := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	var pad := gamepad.stick()
	if gamepad.using_controller:
		stick = pad
	var forward := -camera.global_basis.z
	forward.y = 0.0
	forward = forward.normalized()
	var right := camera.global_basis.x
	right.y = 0.0
	right = right.normalized()
	move_direction = (right * stick.x + forward * -stick.y).limit_length()
	var speed := 8.0 if Input.is_action_pressed("sprint") or gamepad.sprinting() else 5.4
	if gamepad.precision():
		speed = 3.2
	if charging:
		speed *= 0.5
	player.move_toward_direction(move_direction, speed, delta)
	# Keep the controlled athlete within the playable pitch.
	player.global_position.x = clampf(player.global_position.x, -17.4, 17.4)
	player.global_position.z = clampf(player.global_position.z, -27.0, 27.0)
	if charging or move_direction.length_squared() < 0.01:
		player.face_direction(aim_direction, delta)

func _update_aim() -> void:
	var pad := gamepad.stick(true)
	if pad.length() > 0.05:
		var forward := -camera.global_basis.z
		forward.y = 0.0
		aim_direction = (camera.global_basis.x * pad.x + forward.normalized() * -pad.y).normalized()
		aim_direction.y = 0.0
		mouse_aim = false
		return
	if mouse_aim:
		var mouse := get_viewport().get_mouse_position()
		var point: Variant = Plane(Vector3.UP, 0.22).intersects_ray(camera.project_ray_origin(mouse), camera.project_ray_normal(mouse))
		if point != null:
			var direction: Vector3 = point - ball.global_position
			direction.y = 0.0
			if direction.length() > 0.5:
				aim_direction = direction.normalized()
	elif move_direction.length_squared() > 0.04:
		aim_direction = move_direction.normalized()

func _dribble() -> void:
	if move_direction.length() < 0.1 or charging or kick_cooldown > 0.0 or dribble_cooldown > 0.0:
		return
	var offset: Vector3 = ball.global_position - player.global_position
	offset.y = 0.0
	if offset.length() < 1.65 and ball.global_position.y < 0.65 and ball.linear_velocity.length() < 11.0:
		var speed: float = Vector2(player.velocity.x, player.velocity.z).length()
		# Separate, spaced foot touches: the ball is never attached to the player.
		if offset.dot(move_direction) < 1.2:
			ball.launch(move_direction, speed + 1.8, 0.38, "player")
			dribble_cooldown = 0.2

func can_touch_ball() -> bool:
	var offset: Vector3 = ball.global_position - player.global_position
	offset.y = 0.0
	return offset.length() < 1.9 and ball.global_position.y < 1.25 and kick_cooldown <= 0.0

func shoot_ball(power: float) -> bool:
	if state != State.PLAYING or not can_touch_ball():
		if state == State.PLAYING:
			hud.toast("Aproxime-se da bola para chutar", 1.4)
		return false
	var charge := clampf(power, 0.0, 1.0)
	ball.launch(aim_direction, lerpf(12.0, 29.0, charge), lerpf(0.65, 2.1, charge) if gamepad.precision() else lerpf(1.8, 6.4, charge), "player")
	player.kick_animation()
	sound.kick()
	gamepad.vibrate(0.24, 0.42, 0.16)
	attempts += 1
	kick_cooldown = 0.65
	dribble_cooldown = 0.65
	return true

func pass_ball() -> bool:
	if state != State.PLAYING or not can_touch_ball():
		return false
	var target: Vector3 = partner.global_position + partner.velocity * 0.3
	var offset: Vector3 = target - ball.global_position
	ball.launch(offset, clampf(offset.length() * 1.12, 10.0, 23.0), 0.65, "player_pass")
	player.kick_animation()
	sound.pass_ball()
	kick_cooldown = 0.55
	dribble_cooldown = 0.65
	companion_state = "RECEBER"
	return true

func _update_bots(delta: float) -> void:
	bot_clock -= delta
	if bot_clock <= 0.0:
		bot_clock = [0.4, 0.26, 0.16][difficulty]
		var observed: Vector3 = ball.global_position
		var observed_velocity: Vector3 = ball.linear_velocity
		keeper_target = Vector3(clampf(observed.x * 0.48, -2.9, 2.9), 0, -26.8)
		if observed_velocity.z < -3.0 and observed.z < -8.0:
			var arrival: float = (-26.8 - observed.z) / observed_velocity.z
			if arrival > 0.0 and arrival < 2.5:
				keeper_target.x = clampf(observed.x + observed_velocity.x * arrival, -3.1, 3.1)
		if ball.last_toucher.begins_with("player") and observed_velocity.length() > 8.0:
			defender_state = "INTERCEPTAR"
			defender_target = observed + observed_velocity * 0.2
		elif observed.z < 0.0:
			defender_state = "PRESSIONAR"
			defender_target = observed
		else:
			defender_state = "MARCAR"
			defender_target = Vector3(player.global_position.x * 0.65, 0, player.global_position.z - 5.0)
		defender_target.y = 0.0
	if _keeper_active():
		_move_actor(keeper, keeper_target, [3.6, 4.8, 6.0][difficulty], delta)
		_keeper_save()
	if _defender_active():
		_move_actor(defender, defender_target, [3.0, 4.15, 5.15][difficulty], delta)
		_defender_tackle()
	var support := Vector3(-8.5 if player.global_position.x >= -3.0 else 8.5, 0.0, clampf(player.global_position.z - 7.0, -20.0, 14.0))
	if ball.last_toucher == "player_pass":
		support = ball.global_position + ball.linear_velocity * 0.22
		support.y = 0.0
		companion_state = "RECEBER"
	else:
		companion_state = "APOIAR"
	_move_actor(partner, support, 4.0, delta)
	_partner_return()

func _move_actor(actor, target: Vector3, speed: float, delta: float) -> void:
	var offset: Vector3 = target - actor.global_position
	offset.y = 0.0
	actor.move_toward_direction(offset.normalized() if offset.length() > 0.2 else Vector3.ZERO, minf(speed, offset.length() * 3.0), delta)
	actor.global_position.x = clampf(actor.global_position.x, -17.4, 17.4)
	actor.global_position.z = clampf(actor.global_position.z, -27.1, 26.0)
	if offset.length() <= 0.2:
		actor.face_direction(ball.global_position - actor.global_position, delta)

func _keeper_save() -> bool:
	if keeper_cooldown > 0.0 or ball_scored or ball.last_toucher == "keeper":
		return false
	var offset: Vector3 = ball.global_position - keeper.global_position
	var reach: float = [0.7, 0.95, 1.2][difficulty]
	if absf(offset.z) < 0.95 and absf(offset.x) < reach and ball.global_position.y < 2.35 and ball.linear_velocity.z < -0.5:
		keeper.dive_animation(signf(offset.x) if absf(offset.x) > 0.1 else 1.0)
		var direction := Vector3(signf(offset.x) * 0.65, 0.0, 1.0).normalized()
		ball.launch(direction, 9.0, 2.4, "keeper")
		keeper_cooldown = 1.1
		hud.toast("DEFESA! Busque o canto do gol", 1.6)
		sound.pass_ball()
		return true
	return false

func _defender_tackle() -> bool:
	if defender_cooldown > 0.0 or ball_scored:
		return false
	var offset: Vector3 = ball.global_position - defender.global_position
	offset.y = 0.0
	if offset.length() < 1.0 and ball.global_position.y < 0.7:
		var clear := Vector3(0.8 if ball.global_position.x >= 0.0 else -0.8, 0.0, 0.6)
		ball.launch(clear, 10.0, 0.8, "defender")
		defender.kick_animation()
		defender_cooldown = [2.0, 1.5, 1.0][difficulty]
		defender_state = "RECUPERAR"
		hud.toast("O defensor roubou a bola. Recupere ou pressione R", 1.8)
		return true
	return false

func _partner_return() -> bool:
	if partner_cooldown > 0.0 or ball.last_toucher != "player_pass":
		return false
	var offset: Vector3 = ball.global_position - partner.global_position
	offset.y = 0.0
	if offset.length() < 1.35 and ball.global_position.y < 0.8:
		var return_target: Vector3 = player.global_position + move_direction * 1.4
		var direction: Vector3 = return_target - ball.global_position
		ball.launch(direction, clampf(direction.length() * 1.12, 10.0, 22.0), 0.65, "partner")
		partner.kick_animation()
		partner_cooldown = 1.2
		companion_state = "DEVOLVER"
		passes_completed += 1
		hud.toast("Tabela completa! %d / 3" % passes_completed, 1.6)
		sound.pass_ball()
		return true
	return false

static func is_goal_crossing(previous: Vector3, current: Vector3) -> bool:
	# The complete ball must cross the line within the goal opening.
	var crossing_z := GOAL_Z - BALL_RADIUS
	if previous.z <= crossing_z or current.z > crossing_z or current.z >= previous.z:
		return false
	var fraction := (crossing_z - previous.z) / (current.z - previous.z)
	var crossing := previous.lerp(current, fraction)
	return absf(crossing.x) <= GOAL_HALF_WIDTH - BALL_RADIUS and crossing.y >= BALL_RADIUS - 0.03 and crossing.y <= GOAL_HEIGHT - BALL_RADIUS

func _check_goal() -> void:
	if ball_scored or not is_goal_crossing(last_ball_position, ball.global_position):
		return
	ball_scored = true
	gamepad.vibrate(0.55, 0.75, 0.4)
	goals += 1
	sound.goal()
	hud.toast("GOOOOL!  •  %d" % goals, 2.4)
	if exercise == 1:
		for index in range(3):
			var center := Vector2((index - 1) * 2.35, 1.15)
			var hit := Vector2(ball.global_position.x, ball.global_position.y)
			if hit.distance_to(center) < 0.8:
				targets_hit[index] = true
		_update_marker_colors()
	pending_reset = 2.0

func _check_cones() -> void:
	if exercise != 3 or cone_index >= CONE_ROUTE.size():
		return
	var center: Vector3 = CONE_ROUTE[cone_index]
	var ball_flat: Vector3 = ball.global_position
	ball_flat.y = 0.0
	var player_flat: Vector3 = player.global_position
	player_flat.y = 0.0
	if ball_flat.distance_to(center) < 1.4 and player_flat.distance_to(center) < 2.2 and ball.global_position.y < 0.65:
		cone_index += 1
		_update_marker_colors()
		hud.toast("Portão %d / 5 concluído" % cone_index, 1.3)

func _check_bounds(delta: float) -> void:
	if pending_reset > 0.0:
		pending_reset -= delta
		if pending_reset <= 0.0:
			_reset_positions()
		return
	var point: Vector3 = ball.global_position
	if absf(point.x) > 18.4 or point.z > 28.5 or (point.z < -28.6 and not ball_scored) or point.y < -2.0:
		pending_reset = 1.6
		hud.toast("Bola fora • reposição automática", 1.5)

func _objective_completed() -> bool:
	match exercise:
		0, 4: return goals >= 5
		1: return targets_hit.all(func(hit: bool): return hit)
		2: return passes_completed >= 3
		3: return cone_index >= CONE_ROUTE.size()
	return false

func _objective_text() -> String:
	match exercise:
		1: return "ALVOS  •  Acerte os três círculos: %d / 3" % targets_hit.count(true)
		2: return "TABELAS  •  Passe com E e receba de volta: %d / 3" % passes_completed
		3: return "CONDUÇÃO  •  Leve a bola pelos portões: %d / 5" % cone_index
		4: return "1 CONTRA 1  •  Vença o marcador e faça cinco gols"
	return "FINALIZAÇÃO  •  Faça cinco gols em 90 segundos"

func _finish_session(success: bool) -> void:
	state = State.FINISHED
	charging = false
	shot_charge = 0.0
	get_tree().paused = true
	var title := "DESAFIO CONCLUÍDO" if success else "TEMPO ENCERRADO"
	var detail := "%d gols • %d chutes • %.0f segundos\n%s" % [goals, attempts, elapsed, "Você atingiu a meta. Vamos outra vez?" if success else "Ajuste sua mira e tente novamente."]
	hud.show_result(title, detail)

func _keeper_active() -> bool:
	return exercise == 0 or exercise == 4

func _defender_active() -> bool:
	return exercise == 4 or (exercise == 0 and defender_enabled)

func _update_visibility() -> void:
	keeper.visible = _keeper_active()
	keeper.collision_layer = 2 if keeper.visible else 0
	defender.visible = _defender_active()
	defender.collision_layer = 2 if defender.visible else 0
	for index in range(cone_rings.size()):
		var gate := cone_rings[index].get_parent()
		gate.visible = exercise == 3
		for child in gate.get_children():
			if child is StaticBody3D:
				child.collision_layer = 1 if exercise == 3 else 0
	for target in goal_targets:
		target.visible = exercise == 1
	_update_marker_colors()

func _change_exercise(index: int) -> void:
	exercise = index
	_update_visibility()

func _change_quality(index: int) -> void:
	stadium.set_quality(index)
	get_viewport().msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_4X][index]

func _update_camera(delta: float, snap: bool = false) -> void:
	var desired: Vector3
	var target: Vector3
	if state == State.MENU:
		var drift := sin(Time.get_ticks_msec() * 0.00018) * 1.0
		desired = Vector3(17 + drift, 8.5, 22)
		target = Vector3(-1, 0.4, -9)
	else:
		var p: Vector3 = player.global_position
		match camera_mode:
			1:
				desired = p + Vector3(2.7, 3.8, 7.4)
				target = p + Vector3(0, 1, -9)
			2:
				desired = Vector3(28, 21, clampf(p.z + 15, -7, 25))
				target = Vector3(p.x * 0.3, 0, p.z - 6)
			_:
				desired = Vector3(p.x * 0.65, 21, p.z + 13)
				target = Vector3(p.x * 0.6, 0, p.z - 15)
	var weight := 1.0 if snap else 1.0 - exp(-delta * 5.0)
	camera.global_position = camera.global_position.lerp(desired, weight)
	camera.look_at(target, Vector3.UP)

func _build_aim_indicator() -> void:
	aim_arrow = Node3D.new()
	add_child(aim_arrow)
	var material := _bright_material(Color("dbff78"))
	var shaft := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.09, 0.015, 1.15)
	shaft.mesh = box
	shaft.position.z = -1.05
	shaft.material_override = material
	aim_arrow.add_child(shaft)
	var tip := MeshInstance3D.new()
	var cone := CylinderMesh.new()
	cone.top_radius = 0.0
	cone.bottom_radius = 0.18
	cone.height = 0.42
	cone.radial_segments = 3
	tip.mesh = cone
	tip.rotation.x = -PI / 2
	tip.position.z = -1.76
	tip.material_override = material
	aim_arrow.add_child(tip)
	for index in range(16):
		var dot := MeshInstance3D.new()
		var sphere := SphereMesh.new()
		sphere.radius = 0.055
		sphere.height = 0.11
		dot.mesh = sphere
		dot.material_override = material
		dot.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(dot)
		dot.visible = false
		trajectory.append(dot)

func _update_trajectory() -> void:
	for index in range(trajectory.size()):
		var dot := trajectory[index]
		dot.visible = charging and can_touch_ball()
		if dot.visible:
			var time := (index + 1) * 0.09
			var lift := lerpf(0.65, 2.1, shot_charge) if gamepad.precision() else lerpf(1.8, 6.4, shot_charge)
			var velocity := aim_direction * lerpf(12.0, 29.0, shot_charge) + Vector3.UP * lift
			var predicted: Vector3 = ball.global_position + velocity * time + Vector3.DOWN * 4.9 * time * time
			predicted.y = maxf(0.07, predicted.y)
			dot.global_position = predicted

func _bright_material(color: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.emission_enabled = true
	material.emission = color
	return material

func _build_exercise_objects() -> void:
	exercise_objects = Node3D.new()
	add_child(exercise_objects)
	for point in CONE_ROUTE:
		var gate := Node3D.new()
		gate.position = point
		exercise_objects.add_child(gate)
		for x in [-1.65, 1.65]:
			var cone := MeshInstance3D.new()
			var mesh := CylinderMesh.new()
			mesh.top_radius = 0.045
			mesh.bottom_radius = 0.23
			mesh.height = 0.6
			cone.mesh = mesh
			cone.position = Vector3(x, 0.3, 0)
			var material := StandardMaterial3D.new()
			material.albedo_color = Color("ff773f")
			material.roughness = 0.3
			cone.material_override = material
			gate.add_child(cone)
			var obstacle := StaticBody3D.new()
			obstacle.collision_layer = 1
			obstacle.collision_mask = 0
			obstacle.position = cone.position
			var shape := CylinderShape3D.new()
			shape.radius = 0.18
			shape.height = 0.6
			var collider := CollisionShape3D.new()
			collider.shape = shape
			obstacle.add_child(collider)
			gate.add_child(obstacle)
		var ring := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.85
		mesh.outer_radius = 0.94
		mesh.rings = 32
		mesh.ring_segments = 6
		ring.mesh = mesh
		ring.position.y = 0.025
		ring.material_override = _bright_material(Color("dbff78"))
		gate.add_child(ring)
		cone_rings.append(ring)
	for index in range(3):
		var target := MeshInstance3D.new()
		var mesh := TorusMesh.new()
		mesh.inner_radius = 0.55
		mesh.outer_radius = 0.63
		mesh.rings = 32
		mesh.ring_segments = 8
		target.mesh = mesh
		target.position = Vector3((index - 1) * 2.35, 1.15, -28.8)
		target.rotation.x = PI / 2
		target.material_override = _bright_material(Color("ffbd5e"))
		exercise_objects.add_child(target)
		goal_targets.append(target)

func _update_marker_colors() -> void:
	for index in range(cone_rings.size()):
		var material: StandardMaterial3D = cone_rings[index].material_override
		material.albedo_color = Color("29caad") if index < cone_index else (Color("dbff78") if index == cone_index else Color("708780"))
		material.emission = material.albedo_color
	for index in range(goal_targets.size()):
		var material: StandardMaterial3D = goal_targets[index].material_override
		material.albedo_color = Color("29caad") if targets_hit[index] else Color("ffbd5e")
		material.emission = material.albedo_color
