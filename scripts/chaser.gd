extends Area3D

@export var damage := 30.0
@export var momentum_loss := 40.0
@export var speed := 12.0
@export var life_time := 12.0

var _target: Node = null
var _time_left := 0.0
var _active := false

func _ready():
    connect("body_entered", Callable(self, "_on_body_entered"))
    _time_left = life_time

func start(target: Node, start_speed: float, duration: float = 10.0):
    _target = target
    speed = start_speed
    _time_left = duration
    _active = true
    visible = true
    if has_method("set_monitoring"):
        set_monitoring(true)

func _physics_process(delta):
    if not _active:
        return
    _time_left -= delta
    if _time_left <= 0:
        _finish()
        return

    # simple pursuit: move forward towards negative z (towards player's forward)
    translate(Vector3(0, 0, -speed * delta))

    # optionally, track lateral x to follow player's lane
    if _target:
        var tx = _target.global_transform.origin.x
        var pos = global_transform.origin
        pos.x = lerp(pos.x, tx, 6.0 * delta)
        global_transform = Transform3D(global_transform.basis, pos)

func _on_body_entered(body):
    if not body:
        return
    if body.has_method("apply_obstacle_hit"):
        body.apply_obstacle_hit(damage, momentum_loss)
    # after hitting the player, the chaser continues or despawns; here we despawn
    _finish()

func _finish():
    _active = false
    # if pooled, return to pool; else free
    if has_meta("_pool"):
        var pool = get_meta("_pool")
        if pool and pool is Object:
            pool.release_instance(self)
            return
    queue_free()

func disable_temporarily():
    _active = false
    visible = false
    if has_method("set_monitoring"):
        set_monitoring(false)

func reset():
    _active = false
    visible = true
    if has_method("set_monitoring"):
        set_monitoring(true)
    _time_left = life_time
