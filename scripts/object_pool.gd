
class_name ObjectPool
extends Node3D

@export var prefab: PackedScene
@export var pool_size := 8

var _pool: Array = []
var _in_use: Array = []

func _ready():
    for i in range(pool_size):
        if prefab:
            var inst = prefab.instantiate()
            # detach from tree
            _pool.append(inst)

func get_instance() -> Node3D:
    var inst: Node3D = null
    if _pool.size() > 0:
        inst = _pool.pop_back()
    else:
        if prefab:
            inst = prefab.instantiate()
    if inst:
        _in_use.append(inst)
        # mark pool so it can be returned later
        inst.set_meta("_pool", self)
    return inst

func release_instance(inst: Node) -> void:
    if inst == null:
        return
    if inst in _in_use:
        _in_use.erase(inst)
    # call reset hook if available
    if inst.has_method("reset"):
        inst.reset()
    # detach from parent so it can be reused
    if inst.get_parent():
        inst.get_parent().remove_child(inst)
    # clear transform so it doesn't keep stale global transform
    if inst is Node3D:
        inst.transform = Transform3D()
    _pool.append(inst)

