extends Control

signal accepted
signal timeout

@export var input_action: StringName = &"move_left"
@export var duration_sec: float = 1.5
@export var hold_required: bool = false
@export var ring_radius: float = 64.0
@export var ring_thickness: float = 10.0
@export var ring_color_bg: Color = Color(1, 1, 1, 0.2)
@export var ring_color_fg: Color = Color(1, 1, 1, 0.9)

var _elapsed: float = 0.0
var _held_time: float = 0.0
var _progress_ratio: float = 0.0

func _ready():
	visible = true
	set_process(true)
	refresh_hint()
	queue_redraw()

func _process(delta: float) -> void:
	_elapsed += delta
	if _elapsed >= duration_sec:
		emit_signal("timeout")
		queue_free()
		return

	var just_pressed := Input.is_action_just_pressed(input_action)
	var pressed := Input.is_action_pressed(input_action)

	if hold_required:
		if pressed:
			_held_time += delta
			_update_progress(_held_time / max(0.001, duration_sec))
			if _held_time >= duration_sec:
				emit_signal("accepted")
				queue_free()
		else:
			_held_time = 0.0
			_update_progress(0.0)
	else:
		# Tap within the window accepts immediately
		if just_pressed:
			emit_signal("accepted")
			queue_free()
		else:
			_update_progress((_elapsed) / max(0.001, duration_sec))

func refresh_hint():
	# Determine display key from InputMap for given action (prefer first physical key)
	var display_key := String(input_action)
	var events = InputMap.action_get_events(input_action)
	for e in events:
		if e is InputEventKey:
			var key_evt := e as InputEventKey
			if key_evt.keycode != KEY_NONE:
				display_key = OS.get_keycode_string(key_evt.keycode)
				break
	# Update hint label if present
	var hint := get_node_or_null("Hint")
	if hint and hint is Label:
		(hint as Label).text = "Press: " + display_key

func set_input_action(action: StringName):
	input_action = action
	refresh_hint()

func _update_progress(ratio: float) -> void:
	_progress_ratio = clamp(ratio, 0.0, 1.0)
	queue_redraw()

func _draw() -> void:
	var center := size * 0.5
	# Background full ring
	draw_arc(center, ring_radius, -PI * 0.5, -PI * 0.5 + TAU, 96, ring_color_bg, ring_thickness)
	# Foreground progress ring
	var end_angle := -PI * 0.5 + TAU * _progress_ratio
	draw_arc(center, ring_radius, -PI * 0.5, end_angle, 96, ring_color_fg, ring_thickness)
