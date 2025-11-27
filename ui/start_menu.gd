extends Node3D

var selection_index: int = 0
var selections: Array[String] = ["Apatosaurus", "Stegosaurus", "Triceratops", "Trex", "Parasaurolophus", "Velociraptor"]
# Map selection names to resource paths (fbx models)
const MODEL_PATHS := {
	"Apatosaurus": "res://resources/FBX/Apatosaurus.fbx",
	"Stegosaurus": "res://resources/FBX/Stegosaurus.fbx",
	"Triceratops": "res://resources/FBX/Triceratops.fbx",
	"Trex": "res://resources/FBX/Trex.fbx",
	"Parasaurolophus": "res://resources/FBX/Parasaurolophus.fbx",
	"Velociraptor": "res://resources/FBX/Velociraptor.fbx"
}

@onready var pick_button: Button = $Background/MarginContainer2/HBoxContainer/Panel/Button
@onready var display_holder: Node3D = $Background/MarginContainer2/HBoxContainer/Panel/DisplayAnimal

func _on_start_pressed() -> void:
	var tree := get_tree()
	if tree:
		tree.change_scene_to_file("res://scenes/main.tscn")

func _on_settings_pressed() -> void:
	print("Settings pressed (TODO: implement settings menu)")

func _on_exit_pressed() -> void:
	get_tree().quit()

func _on_left_pressed() -> void:
	selection_index = (selection_index - 1 + selections.size()) % selections.size()
	_update_selection_label()
	_refresh_display_model()

func _on_right_pressed() -> void:
	selection_index = (selection_index + 1) % selections.size()
	_update_selection_label()
	_refresh_display_model()

func _on_pick_pressed() -> void:
	var chosen := selections[selection_index]
	print("Picked selection: %s" % chosen)
	# Store chosen model path in GameManager for player scene to use.
	var path: String = MODEL_PATHS.get(chosen, "")
	var gm := get_tree().root.get_node_or_null("GameManager")
	if gm and path != "":
		gm.set_chosen_model_path(path)
	else:
		print_debug("GameManager not found or path empty for %s" % chosen)
	_refresh_display_model()

func _ready() -> void:
	_update_selection_label()
	_refresh_display_model()

func _update_selection_label() -> void:
	if pick_button:
		pick_button.text = selections[selection_index]

func _refresh_display_model() -> void:
	if not display_holder:
		return
	# Clear previous models
	for c in display_holder.get_children():
		c.queue_free()
	var chosen := selections[selection_index]
	var path: String = MODEL_PATHS.get(chosen, "")
	if path == "":
		print_debug("No model path for selection: %s" % chosen)
		return
	var res := load(path)
	if res == null:
		print_debug("Failed to load model: %s" % path)
		return
	var inst = null
	if res is PackedScene:
		inst = (res as PackedScene).instantiate()
	else:
		# FBX import may yield nodes; instantiate if possible or create MeshInstance wrapper if mesh
		inst = res.duplicate()
	if inst == null:
		return
	display_holder.add_child(inst)
	# Uniform scale for preview
	inst.scale = Vector3(0.02, 0.02, 0.02)
	# Center at origin; adadwwwawaadjust if model pivot off
	if inst is Node3D:
		(inst as Node3D).position = Vector3.ZERO
	# Optional: face camera (rotate 180 if backwards)
	if inst is Node3D:
		var r = (inst as Node3D).rotation_degrees
		# Heuristic: face -Z
		if abs(r.y) < 0.1:
			r.y = 180.0
		(inst as Node3D).rotation_degrees = r

func _process(delta: float) -> void:
	_rotate_display(delta)

func _rotate_display(_delta: float) -> void:
	$%DisplayAnimal.rotate_y(0.005)
