@tool
extends Node3D

@export var terrain_size: Vector2 = Vector2(256, 256)
@export var subdivisions: int = 127 # Must be careful not to exceed vertex limits too much
@export var height_scale: float = 10.0
@export var noise: FastNoiseLite
@export var grass_mesh: Mesh
@export var grass_count: int = 10000
@export var tree_mesh: Mesh
@export var tree_count: int = 500

@onready var mesh_instance: MeshInstance3D = $MeshInstance3D
@onready var static_body: StaticBody3D = $MeshInstance3D/StaticBody3D
@onready var collision_shape: CollisionShape3D = $MeshInstance3D/StaticBody3D/CollisionShape3D
@onready var grass_multimesh: MultiMeshInstance3D = $GrassMultiMesh
@onready var tree_multimesh: MultiMeshInstance3D = $TreeMultiMesh

func _ready() -> void:
	if not noise:
		noise = FastNoiseLite.new()
		noise.seed = randi()
		noise.frequency = 0.02
		noise.fractal_type = FastNoiseLite.FRACTAL_FBM

	generate_terrain()
	generate_grass()
	generate_trees()

# ... (generate_terrain and generate_grass remain mostly the same, ensuring they don't break)

func generate_trees() -> void:
	if not tree_mesh:
		tree_mesh = create_simple_tree_mesh()
		
	if not tree_multimesh:
		return

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = tree_mesh
	multimesh.instance_count = tree_count
	
	var rng = RandomNumberGenerator.new()
	var placed_count = 0
	
	# Simple Poisson-disc-like or just random with retry? Random is fine for now.
	
	for i in range(tree_count):
		var x = rng.randf_range(-terrain_size.x / 2.0, terrain_size.x / 2.0)
		var z = rng.randf_range(-terrain_size.y / 2.0, terrain_size.y / 2.0)
		
		var y = noise.get_noise_2d(x, z) * height_scale
		
		# Avoid underwater or very steep slopes (simple check: if y is too low/high?)
		# Let's say trees only grow on "land" (y > 0.2 * height_scale) and not peaks (y < 0.8)
		if y < height_scale * 0.1 or y > height_scale * 0.8:
			# Move it somewhere else or just hide it under map? 
			# Ideally retry, but for speed let's just scale to 0
			multimesh.set_instance_transform(i, Transform3D().scaled(Vector3.ZERO))
			continue

		var transform = Transform3D()
		transform.origin = Vector3(x, y, z)
		
		var scale = rng.randf_range(1.5, 2.5)
		transform = transform.rotated(Vector3.UP, rng.randf() * TAU)
		transform = transform.scaled(Vector3(scale, scale, scale))
		
		multimesh.set_instance_transform(i, transform)
		placed_count += 1
		
	tree_multimesh.multimesh = multimesh
	print("Placed ", placed_count, " trees.")

func create_simple_tree_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Trunk (Brown)
	var trunk_color = Color(0.4, 0.3, 0.2)
	var trunk_height = 2.0
	var trunk_radius = 0.4
	
	# Simple box/pyramid trunk? merging geometries is hard with just vertices manual
	# Let's make a simple pyramid trunk
	# Base
	st.set_color(trunk_color)
	st.add_vertex(Vector3(-trunk_radius, 0, -trunk_radius))
	st.add_vertex(Vector3(trunk_radius, 0, -trunk_radius))
	st.add_vertex(Vector3(trunk_radius, 0, trunk_radius))
	
	st.add_vertex(Vector3(-trunk_radius, 0, -trunk_radius))
	st.add_vertex(Vector3(trunk_radius, 0, trunk_radius))
	st.add_vertex(Vector3(-trunk_radius, 0, trunk_radius))
	
	# Sides to top of trunk
	var top = Vector3(0, trunk_height, 0)
	# Side 1
	st.add_vertex(Vector3(-trunk_radius, 0, -trunk_radius))
	st.add_vertex(top)
	st.add_vertex(Vector3(trunk_radius, 0, -trunk_radius))
	# Side 2
	st.add_vertex(Vector3(trunk_radius, 0, -trunk_radius))
	st.add_vertex(top)
	st.add_vertex(Vector3(trunk_radius, 0, trunk_radius))
	# Side 3
	st.add_vertex(Vector3(trunk_radius, 0, trunk_radius))
	st.add_vertex(top)
	st.add_vertex(Vector3(-trunk_radius, 0, trunk_radius))
	# Side 4
	st.add_vertex(Vector3(-trunk_radius, 0, trunk_radius))
	st.add_vertex(top)
	st.add_vertex(Vector3(-trunk_radius, 0, -trunk_radius))
	
	# Leaves (Green Cone)
	var leaves_color = Color(0.1, 0.6, 0.2)
	var leaves_base_y = trunk_height * 0.8
	var leaves_height = 3.0
	var leaves_radius = 1.5
	
	st.set_color(leaves_color)
	
	# Base of leaves
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, -leaves_radius))
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, -leaves_radius))
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, leaves_radius))
	
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, -leaves_radius))
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, leaves_radius))
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, leaves_radius))
	
	# Sides to top of leaves
	var leaf_top = Vector3(0, leaves_base_y + leaves_height, 0)
	
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, -leaves_radius))
	st.add_vertex(leaf_top)
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, -leaves_radius))
	
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, -leaves_radius))
	st.add_vertex(leaf_top)
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, leaves_radius))
	
	st.add_vertex(Vector3(leaves_radius, leaves_base_y, leaves_radius))
	st.add_vertex(leaf_top)
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, leaves_radius))
	
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, leaves_radius))
	st.add_vertex(leaf_top)
	st.add_vertex(Vector3(-leaves_radius, leaves_base_y, -leaves_radius))
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mesh.surface_set_material(0, mat)
	
	return mesh

func generate_terrain() -> void:
	# 1. Create PlaneMesh
	var plane_mesh = PlaneMesh.new()
	plane_mesh.size = terrain_size
	plane_mesh.subdivide_width = subdivisions
	plane_mesh.subdivide_depth = subdivisions
	
	# 2. Use SurfaceTool to modify vertices
	var st = SurfaceTool.new()
	st.create_from(plane_mesh, 0)
	
	var array_mesh = st.commit()
	var mdt = MeshDataTool.new()
	mdt.create_from_surface(array_mesh, 0)
	
	for i in range(mdt.get_vertex_count()):
		var vertex = mdt.get_vertex(i)
		var height = noise.get_noise_2d(vertex.x, vertex.z) * height_scale
		vertex.y = height
		
		# Simple vertex coloring
		var color = Color(0.2, 0.6, 0.1) # Green
		if height > height_scale * 0.4:
			color = color.lerp(Color(0.5, 0.4, 0.3), (height - height_scale * 0.4) / (height_scale * 0.6)) # Fade to brown
		
		mdt.set_vertex_color(i, color)
		mdt.set_vertex(i, vertex)
	
	# 3. Commit changes and regenerate normals
	array_mesh.clear_surfaces()
	mdt.commit_to_surface(array_mesh)
	
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	st.create_from(array_mesh, 0)
	st.generate_normals()
	
	var final_mesh = st.commit()
	
	# Set Material to use Vertex Colors
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.roughness = 0.9
	final_mesh.surface_set_material(0, mat)
	
	mesh_instance.mesh = final_mesh
	
	# 4. Update Collision
	if collision_shape:
		collision_shape.shape = final_mesh.create_trimesh_shape()

func generate_grass() -> void:
	if not grass_mesh:
		grass_mesh = create_simple_grass_mesh()
		
	if not grass_multimesh:
		return

	var multimesh = MultiMesh.new()
	multimesh.transform_format = MultiMesh.TRANSFORM_3D
	multimesh.mesh = grass_mesh
	multimesh.instance_count = grass_count
	
	var rng = RandomNumberGenerator.new()
	
	# Pre-calculate noise for speed or just call it 
	# (FastNoiseLite is fast enough for 10k instances usually)
	
	for i in range(grass_count):
		var x = rng.randf_range(-terrain_size.x / 2.0, terrain_size.x / 2.0)
		var z = rng.randf_range(-terrain_size.y / 2.0, terrain_size.y / 2.0)
		
		var y = noise.get_noise_2d(x, z) * height_scale
		
		# Simple mask: Don't place on steep slopes (check normal later?) or underwater
		# For now just place everywhere
		
		var transform = Transform3D()
		transform.origin = Vector3(x, y, z)
		
		# Random rotation and scale
		var scale = rng.randf_range(0.8, 1.5)
		# Random Y rotation
		transform = transform.rotated(Vector3.UP, rng.randf() * TAU)
		# Add a slight random tilt
		transform = transform.rotated(Vector3.RIGHT, rng.randf_range(-0.1, 0.1))
		transform = transform.scaled(Vector3(scale, scale, scale))
		
		multimesh.set_instance_transform(i, transform)
		
	grass_multimesh.multimesh = multimesh

func create_simple_grass_mesh() -> ArrayMesh:
	var st = SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	
	# Simple low-poly blade: 3 vertices? Or a quad?
	# Triangle is cheapest.
	#    ^
	#   / \
	#  /   \
	# /_____\
	
	# Vertex 0: Top
	st.set_uv(Vector2(0.5, 1.0))
	st.set_color(Color(0.2, 0.8, 0.2)) # Light green tip
	st.add_vertex(Vector3(0, 1.0, 0))
	
	# Vertex 1: Bottom Right
	st.set_uv(Vector2(1.0, 0.0))
	st.set_color(Color(0.1, 0.4, 0.1)) # Dark green base
	st.add_vertex(Vector3(0.1, 0, 0))
	
	# Vertex 2: Bottom Left
	st.set_uv(Vector2(0.0, 0.0))
	st.set_color(Color(0.1, 0.4, 0.1)) # Dark green base
	st.add_vertex(Vector3(-0.1, 0, 0))
	
	# Double sided? Add reverse triangle
	st.set_uv(Vector2(0.5, 1.0))
	st.set_color(Color(0.2, 0.8, 0.2))
	st.add_vertex(Vector3(0, 1.0, 0))
	
	st.set_uv(Vector2(0.0, 0.0))
	st.set_color(Color(0.1, 0.4, 0.1))
	st.add_vertex(Vector3(-0.1, 0, 0))
	
	st.set_uv(Vector2(1.0, 0.0))
	st.set_color(Color(0.1, 0.4, 0.1))
	st.add_vertex(Vector3(0.1, 0, 0))
	
	st.generate_normals()
	var mesh = st.commit()
	
	var mat = StandardMaterial3D.new()
	mat.vertex_color_use_as_albedo = true
	mat.cull_mode = BaseMaterial3D.CULL_DISABLED # Render both sides
	mat.shading_mode = BaseMaterial3D.SHADING_MODE_PER_VERTEX # Cheaper
	mesh.surface_set_material(0, mat)
	
	return mesh
