extends Node3D

@export var obstacle_scene: PackedScene
@export var low_barrier_scene: PackedScene
@export var tall_barrier_scene: PackedScene
@export var pit_scene: PackedScene
@export var moving_obstacle_scene: PackedScene
@export var perfect_scene: PackedScene
@export var spawn_interval := 1.4
@export var spawn_distance := 30.0
@export var lanes := 3
@export var lane_width := 2.0
@export var initial_spawn_count := 6
@export var pool_size := 10

@onready var timer := $Timer
var player = null

var _obstacle_pool: Object = null
var _perfect_pool: Object = null
var _moving_pool: Object = null

func _ready():
    player = get_parent().get_node_or_null("Player")
    if not player:
        print("Spawner: Player not found in parent scene")

    # create object pools using ObjectPool
    var ObjectPoolClass = preload("res://scripts/object_pool.gd")
    _obstacle_pool = ObjectPoolClass.new()
    _obstacle_pool.prefab = obstacle_scene
    _obstacle_pool.pool_size = pool_size
    add_child(_obstacle_pool)

    _perfect_pool = ObjectPoolClass.new()
    _perfect_pool.prefab = perfect_scene
    _perfect_pool.pool_size = pool_size
    add_child(_perfect_pool)

    if moving_obstacle_scene:
        _moving_pool = ObjectPoolClass.new()
        _moving_pool.prefab = moving_obstacle_scene
        _moving_pool.pool_size = pool_size
        add_child(_moving_pool)

    timer.wait_time = spawn_interval
    timer.one_shot = false
    timer.connect("timeout", Callable(self, "_on_Timer_timeout"))
    timer.start()

    # prefill obstacles ahead
    for i in range(initial_spawn_count):
        _spawn_wave(spawn_distance + i * 6)

func _process(_delta):
    # recycle objects that fell behind the player
    if not player:
        return
    var world = get_parent()
    # iterate a copy because we may remove children
    for child in world.get_children():
        if child == player:
            continue
        if child is Node3D:
            var posz = child.global_transform.origin.z
            if posz > player.global_transform.origin.z + 6.0:
                # behind player: remove and store back in its pool if available
                if child.has_meta("_pool"):
                    var pool = child.get_meta("_pool")
                    if pool and pool is Object:
                        pool.release_instance(child)
                    else:
                        # fallback: just remove
                        world.remove_child(child)
                else:
                    world.remove_child(child)

func _on_Timer_timeout():
    _spawn_wave(spawn_distance)

func _spawn_wave(dist: float) -> void:
    var lane = randi() % lanes
    var center = float(lanes - 1) / 2.0
    var x = (lane - center) * lane_width
    var z = -dist

    var obstacle = null
    # decide which obstacle variant to spawn
    var spawn_moving = false
    if moving_obstacle_scene and (randi() % 6) == 0:
        spawn_moving = true

    if spawn_moving:
        if _moving_pool:
            obstacle = _moving_pool.get_instance()
        elif moving_obstacle_scene:
            obstacle = moving_obstacle_scene.instantiate()
    else:
        # collect available static obstacle variants
        var variants := []
        if obstacle_scene:
            variants.append(obstacle_scene)
        if low_barrier_scene:
            variants.append(low_barrier_scene)
        if tall_barrier_scene:
            variants.append(tall_barrier_scene)
        if pit_scene:
            variants.append(pit_scene)

        if variants.size() == 0:
            obstacle = null
        else:
            var pick = randi() % variants.size()
            var chosen = variants[pick]
            # try to get from generic obstacle pool when chosen equals the main obstacle_scene
            if _obstacle_pool and chosen == obstacle_scene:
                obstacle = _obstacle_pool.get_instance()
            else:
                obstacle = chosen.instantiate()
    if obstacle:
        obstacle.translation = Vector3(x, 0.0, z)
        get_parent().add_child(obstacle)

    if randi() % 4 == 0:
        var p = null
        if _perfect_pool:
            p = _perfect_pool.get_instance()
        if p == null and perfect_scene:
            p = perfect_scene.instantiate()
        if p:
            p.translation = Vector3(x, 0.0, z - 2.0)
            get_parent().add_child(p)
