extends Node3D

@export var chaser_scene: PackedScene
@export var chase_distance := 24.0
@export var chase_speed_mult := 1.5
@export var chase_duration := 10.0

var _active_chaser: Node = null
var _player: Node = null
var _hud: Node = null
var _prev_c := false
var _chaser_pool: Object = null

func _ready():
	_player = get_parent().get_node_or_null("Player")
	if not _player:
		push_warning("EventManager: Player node not found as sibling of EventManager. Ensure main scene has Player named 'Player'.")
	_hud = get_parent().get_node_or_null("HUD")
	set_process(true)
	# create a chaser pool for reuse
	if chaser_scene:
		var ObjectPoolClass = preload("res://scripts/object_pool.gd")
		_chaser_pool = ObjectPoolClass.new()
		_chaser_pool.prefab = chaser_scene
		_chaser_pool.pool_size = 2
		add_child(_chaser_pool)

func start_chase():
	if _active_chaser:
		return
	if not chaser_scene:
		push_warning("EventManager: no chaser_scene configured")
		return
	if not _player:
		_player = get_parent().get_node_or_null("Player")
		if not _player:
			push_warning("EventManager: cannot find player to target")
			return

	var chaser = null
	if _chaser_pool:
		chaser = _chaser_pool.get_instance()
	else:
		chaser = chaser_scene.instantiate()
	if not chaser:
		push_warning("EventManager: failed to instance chaser_scene")
		return

	# place chaser behind the player so it can chase forward
	var pz = _player.global_transform.origin.z
	var px = _player.global_transform.origin.x

	# add to scene first so global_transform is valid
	get_parent().add_child(chaser)
	chaser.global_transform = Transform3D(chaser.global_transform.basis, Vector3(px, 0.0, pz + chase_distance))
	if chaser.has_method("start"):
		var speed = 8.0
		if _player:
			var tmp = _player.get("base_speed")
			if tmp != null:
				speed = tmp
		chaser.call("start", _player, speed * chase_speed_mult, chase_duration)
	_active_chaser = chaser
	# notify HUD if available
	if _hud and _hud.has_method("show_event"):
		_hud.call("show_event", "Chase")

func stop_chase():
	if _active_chaser:
		# if pooled, return to pool; otherwise free
		if _active_chaser.has_meta("_pool"):
			var pool = _active_chaser.get_meta("_pool")
			if pool and pool is Object:
				pool.release_instance(_active_chaser)
		else:
			if _active_chaser.get_parent():
				_active_chaser.get_parent().remove_child(_active_chaser)
			_active_chaser.queue_free()
		_active_chaser = null

func is_chase_active() -> bool:
	return _active_chaser != null

func _process(_delta):
	# debug input: press C to trigger chase
	var pressed = Input.is_key_pressed(Key.KEY_C)
	if pressed and not _prev_c:
		start_chase()
	_prev_c = pressed
