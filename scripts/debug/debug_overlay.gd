extends CanvasLayer

var lbl: Label = null
var toggle_hint: Label = null

var _visible := true
var _current_scene: Node = null
var _player: Node = null
var _spawner: Node = null
var _event_manager: Node = null

func _ready():
	set_process(true)
	_current_scene = get_tree().get_current_scene()
	_find_nodes()
	# ensure a runtime InputMap action exists so users can remap in Project Settings
	var action_name = "toggle_debug"
	if not InputMap.has_action(action_name):
		InputMap.add_action(action_name)
		var ev := InputEventKey.new()
		ev.keycode = Key.KEY_TAB
		InputMap.action_add_event(action_name, ev)
	if toggle_hint:
		toggle_hint.text = "Toggle debug overlay: Tab (or bind 'toggle_debug')"
	# resolve UI nodes safely
	lbl = get_node_or_null("VBoxContainer/InfoLabel")
	toggle_hint = get_node_or_null("VBoxContainer/HintLabel")
	if not lbl:
		print("[DebugOverlay] InfoLabel not found in scene; overlay may not render UI")
	if not toggle_hint:
		print("[DebugOverlay] HintLabel not found in scene")
	print("[DebugOverlay] ready; visible=", str(visible))
	visible = true

func _find_nodes():
	_current_scene = get_tree().get_current_scene()
	if not _current_scene:
		return
	_player = _current_scene.get_node_or_null("Player")
	_spawner = _current_scene.get_node_or_null("Spawner")
	_event_manager = _current_scene.get_node_or_null("EventManager")

func _process(_delta):
	# Toggle via InputMap action (preferred). Default binding is Tab.
	if Input.is_action_just_pressed("toggle_debug"):
		_visible = not _visible
		visible = _visible
		if not _visible:
			return

	if not visible:
		return

	_find_nodes()

	var lines := []
	lines.append("Debug Overlay")
	lines.append("---------------------------")

	# Player info
	if _player:
		var ppos = _player.global_transform.origin
		var stamina = "?"
		var momentum = "?"
		if _player.has_method("get"):
			var s = _player.get("stamina")
			var m = _player.get("momentum")
			stamina = s if s != null else stamina
			momentum = m if m != null else momentum
		lines.append("Player: x=%.2f z=%.2f" % [ppos.x, ppos.z])
		lines.append("  Stamina: %s   Momentum: %s" % [str(stamina), str(momentum)])
	else:
		lines.append("Player: (not found)")

	# Scene counts
	var area_count = 0
	if _current_scene:
		for n in _current_scene.get_children():
			if n is Area3D:
				area_count += 1
	lines.append("Active Areas: %d" % area_count)

	# Pools (search for ObjectPool nodes under scene root and children)
	var pool_nodes = []
	if _current_scene:
		for n in _current_scene.get_children():
			for c in n.get_children():
				if c.has_method("get_pool_count"):
					pool_nodes.append(c)
			if n.has_method("get_pool_count"):
				pool_nodes.append(n)

	if pool_nodes.size() == 0:
		lines.append("Pools: none found")
	else:
		lines.append("Pools:")
		for p in pool_nodes:
			var pool_name = p.name
			var pool_count = p.get_pool_count() if p.has_method("get_pool_count") else "?"
			var in_use = p.get_in_use_count() if p.has_method("get_in_use_count") else "?"
			var cap = p.get_total_capacity() if p.has_method("get_total_capacity") else "?"
			lines.append("  %s : pool=%s in_use=%s cap=%s" % [pool_name, str(pool_count), str(in_use), str(cap)])

	# Event manager
	if _event_manager:
		lines.append("EventManager: chase_active=%s" % [str(_event_manager.is_chase_active())])

	lbl.text = "\n".join(lines)

func _notification(what):
	# ensure overlay is visible initially
	if what == NOTIFICATION_ENTER_TREE:
		visible = true
		_find_nodes()
