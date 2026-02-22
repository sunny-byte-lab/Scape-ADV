extends MeshInstance3D
class_name Chunk

const CHUNK_SIZE = 32
const HEIGHT_SCALE = 0.0

var x_coord: int
var z_coord: int
var noise: FastNoiseLite

func _init(x: int, z: int, p_noise: FastNoiseLite):
	x_coord = x
	z_coord = z
	noise = p_noise
	
	# Create mesh
	mesh = PlaneMesh.new()
	mesh.size = Vector2(CHUNK_SIZE, CHUNK_SIZE)
	mesh.subdivide_width = CHUNK_SIZE
	mesh.subdivide_depth = CHUNK_SIZE
	
	# Generate surface
	var surface_tool = SurfaceTool.new()
	surface_tool.create_from(mesh, 0)
	
	var array_plane = surface_tool.commit()
	var data_tool = MeshDataTool.new()
	data_tool.create_from_surface(array_plane, 0)
	
	for i in range(data_tool.get_vertex_count()):
		var vertex = data_tool.get_vertex(i)
		# Global coordinates
		var global_x = vertex.x + x_coord * CHUNK_SIZE
		var global_z = vertex.z + z_coord * CHUNK_SIZE
		
		# Sample noise
		var height = noise.get_noise_2d(global_x, global_z) * HEIGHT_SCALE
		vertex.y = height
		
		data_tool.set_vertex(i, vertex)
	
	# Commit mesh
	array_plane.clear_surfaces()
	data_tool.commit_to_surface(array_plane)
	surface_tool.begin(Mesh.PRIMITIVE_TRIANGLES)
	surface_tool.create_from(array_plane, 0)
	surface_tool.generate_normals()
	
	mesh = surface_tool.commit()
	
	# Collision
	create_trimesh_collision()
	
	# Position the chunk
	position = Vector3(x_coord * CHUNK_SIZE, 0, z_coord * CHUNK_SIZE)
