class_name FootballGamepad
extends Node
## Godot's SDL mapping supports Xbox USB, Bluetooth and wireless adapters.
## Cached motion events allow radial deadzones and preserve the active device.
signal device_changed(connected: bool, device_name: String)
signal active_disconnected
signal source_changed(using_controller: bool)
const DEADZONE := 0.18
var active_device := -1
var using_controller := false
var _devices: Dictionary = {}
var _axes: Dictionary = {}
var _buttons: Dictionary = {}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	Input.joy_connection_changed.connect(_connection_changed)
	for device in Input.get_connected_joypads():
		_connection_changed(device, true)

func _connection_changed(device: int, connected: bool) -> void:
	if connected:
		_devices[device] = Input.get_joy_name(device)
		if active_device < 0:
			active_device = device
			_use_controller(true)
			device_changed.emit(true, str(_devices[device]))
	else:
		_devices.erase(device)
		if device == active_device:
			stop_vibration()
			_axes.clear()
			_buttons.clear()
			active_device = -1 if _devices.is_empty() else int(_devices.keys()[0])
			_use_controller(active_device >= 0)
			device_changed.emit(active_device >= 0, str(_devices.get(active_device, "")))
			active_disconnected.emit()

func _input(event: InputEvent) -> void:
	if event is InputEventJoypadMotion or event is InputEventJoypadButton:
		if not _devices.has(event.device):
			return
		if active_device != event.device:
			_axes.clear()
			_buttons.clear()
			active_device = event.device
			device_changed.emit(true, str(_devices[active_device]))
		if event is InputEventJoypadMotion:
			_axes[event.axis] = event.axis_value
			if absf(event.axis_value) > DEADZONE:
				_use_controller(true)
		else:
			_buttons[event.button_index] = event.pressed
			if event.pressed:
				_use_controller(true)
	elif (event is InputEventKey and event.pressed) or (event is InputEventMouseMotion and event.relative.length() > 2.0) or (event is InputEventMouseButton and event.pressed):
		_use_controller(false)

func _use_controller(enabled: bool) -> void:
	if using_controller != enabled:
		using_controller = enabled
		source_changed.emit(enabled)

static func radial_deadzone(value: Vector2) -> Vector2:
	var magnitude := value.length()
	if magnitude <= DEADZONE:
		return Vector2.ZERO
	return value.normalized() * clampf((magnitude - DEADZONE) / (1.0 - DEADZONE), 0.0, 1.0)

func stick(right: bool = false) -> Vector2:
	if active_device < 0 or not using_controller:
		return Vector2.ZERO
	var x := JOY_AXIS_RIGHT_X if right else JOY_AXIS_LEFT_X
	var y := JOY_AXIS_RIGHT_Y if right else JOY_AXIS_LEFT_Y
	return radial_deadzone(Vector2(float(_axes.get(x, 0.0)), float(_axes.get(y, 0.0))))

func sprinting() -> bool:
	return using_controller and (bool(_buttons.get(JOY_BUTTON_RIGHT_SHOULDER, false)) or float(_axes.get(JOY_AXIS_TRIGGER_RIGHT, 0.0)) > 0.35)

func precision() -> bool:
	return using_controller and float(_axes.get(JOY_AXIS_TRIGGER_LEFT, 0.0)) > 0.35

func vibrate(weak: float, strong: float, duration: float) -> void:
	if active_device >= 0 and using_controller:
		Input.start_joy_vibration(active_device, weak, strong, duration)

func stop_vibration() -> void:
	if active_device >= 0:
		Input.stop_joy_vibration(active_device)
