extends Node3D
# Procedural terrain segment with height variation
# Generates a sloped/noisy ground mesh and matching concave collider.

@export var length_z: float = 60.0
@export var width_x: float = 6.0
@export var base_y: float = 0.0
@export var lane_count: int = 3
@export var lane_width: float = 2.0
@export var subdivisions_z: int = 60
@export var subdivisions_x: int = 12
@export var amplitude: float = 2.0
@export var frequency: float = 0.05
@export var octave_count: int = 3
@export var persistence: float = 0.5
@export var noise_seed: int = 12345
@export var smooth_edges: bool = true
@export var edge_falloff_z: float = 6.0
@export var material: Material
@export var debug: bool = true

var start_z: float
var end_z: float
var _noise: FastNoiseLite
var _mesh_instance: MeshInstance3D
var _body: StaticBody3D

func _ready():
	start_z = global_transform.origin.z
	end_z = start_z - length_z
	_init_noise()
	_regenerate()
	if debug:
		print("[HeightSegment] generated segment start_z=", start_z, " end_z=", end_z)

func _init_noise():
	_noise = FastNoiseLite.new()
	_noise.seed = noise_seed
	_noise.frequency = frequency
	_noise.fractal_octaves = octave_count
	_noise.fractal_gain = persistence

func get_lane_x(lane_index: int) -> float:
	var center = float(lane_count - 1) / 2.0
	return (lane_index - center) * lane_width

func contains_z(z_val: float) -> bool:
	return z_val <= start_z and z_val >= end_z

func world_height(x: float, z: float) -> float:
	var h = _noise.get_noise_2d(x, z) * amplitude
	if smooth_edges:
		# Fade heights near segment start/end to reduce seams
		var dz_start = clamp((start_z - z) / edge_falloff_z, 0.0, 1.0)
		var dz_end = clamp((z - end_z) / edge_falloff_z, 0.0, 1.0)
		# Both go from 0 at edge to 1 interior; take min for overall interior factor
		var interior = min(dz_start, dz_end)
		h *= interior
	return base_y + h

func _clear_children():
	if _mesh_instance and is_instance_valid(_mesh_instance):
		remove_child(_mesh_instance)
		_mesh_instance.queue_free()
		_mesh_instance = null
	if _body and is_instance_valid(_body):
		remove_child(_body)
		_body.queue_free()
		_body = null

func _regenerate():
	_clear_children()
	if _noise == null:
		_init_noise()
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	if material:
		st.set_material(material)

	var verts = []
	var vert_count := 0
	var face_points: PackedVector3Array = PackedVector3Array()
	for zi in range(subdivisions_z + 1):
		var z_local = - (length_z * (float(zi) / float(subdivisions_z)))
		var z_world = start_z + z_local
		for xi in range(subdivisions_x + 1):
			var x_local = width_x * ((float(xi) / float(subdivisions_x)) - 0.5)
			var x_world = x_local # world x unaffected by segment origin aside from transform
			var y = world_height(x_world, z_world)
			verts.append(Vector3(x_local, y, z_local))
			vert_count += 1

	# Build triangles
	for zi in range(subdivisions_z):
		for xi in range(subdivisions_x):
			var i0 = zi * (subdivisions_x + 1) + xi
			var i1 = i0 + 1
			var i2 = i0 + (subdivisions_x + 1)
			var i3 = i2 + 1
			# Use CCW winding (viewed from above) to ensure upward-facing triangles
			# First tri: i0, i1, i2
			var v0 = verts[i0]
			var v1 = verts[i1]
			var v2 = verts[i2]
			st.add_vertex(v0)
			st.add_vertex(v1)
			st.add_vertex(v2)
			face_points.append_array([v0, v1, v2])
			# Second tri: i1, i3, i2
			var v3 = verts[i1]
			var v4 = verts[i3]
			var v5 = verts[i2]
			st.add_vertex(v3)
			st.add_vertex(v4)
			st.add_vertex(v5)
			face_points.append_array([v3, v4, v5])

	# Generate normals and indices for visual/physical correctness
	st.generate_normals()
	st.index()
	var mesh: ArrayMesh = st.commit()
	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.name = "GroundMesh"
	_mesh_instance.mesh = mesh
	if material:
		_mesh_instance.material_override = material
		if material is BaseMaterial3D:
			(material as BaseMaterial3D).cull_mode = BaseMaterial3D.CULL_DISABLED
	add_child(_mesh_instance)
	if debug:
		print("[HeightSegment] mesh verts=", vert_count, " tris=", subdivisions_z * subdivisions_x * 2, " surfaces=", mesh.get_surface_count())

	# Build collider from the committed mesh to ensure robust triangle data
	var shape: ConcavePolygonShape3D = mesh.create_trimesh_shape()
	_body = StaticBody3D.new()
	_body.name = "GroundBody"
	_body.collision_layer = 1
	_body.collision_mask = 1
	var col = CollisionShape3D.new()
	col.name = "GroundCollider"
	col.shape = shape
	_body.add_child(col)
	add_child(_body)
	if debug:
		print("[HeightSegment] collider ready at z-range [", start_z, ", ", end_z, "]  shape points=", shape.get_faces().size())

func set_origin_z(front_z: float):
	var t = global_transform
	t.origin.z = front_z
	global_transform = t
	start_z = front_z
	end_z = front_z - length_z
	if debug:
		print("[HeightSegment] moved to start_z=", start_z, " end_z=", end_z)
	_regenerate()

func initialize_at(front_z: float):
	set_origin_z(front_z)
