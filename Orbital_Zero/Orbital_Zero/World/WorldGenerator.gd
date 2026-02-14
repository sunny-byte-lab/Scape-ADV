extends Node3D

const CHUNK_SIZE = 32
const RENDER_DISTANCE = 3
const CHUNK_UPDATE_INTERVAL = 0.5 

var chunks = {}
var noise = FastNoiseLite.new()
var player: CharacterBody3D
var last_player_chunk_pos = Vector2i(0, 0)
var time_since_last_update = 0.0

func _ready():
	noise.seed = randi()
	noise.noise_type = FastNoiseLite.TYPE_PERLIN
	noise.frequency = 0.03
	
	player = get_node("../Player")
	update_chunks()

func _process(delta):
	if not player:
		return

	time_since_last_update += delta
	if time_since_last_update < CHUNK_UPDATE_INTERVAL:
		return
	
	time_since_last_update = 0.0
	
	var player_pos = player.global_position
	# Convert player position to chunk coordinates
	var current_chunk_x = int(round(player_pos.x / CHUNK_SIZE))
	var current_chunk_z = int(round(player_pos.z / CHUNK_SIZE))
	var current_chunk_pos = Vector2i(current_chunk_x, current_chunk_z)
	
	if current_chunk_pos != last_player_chunk_pos:
		last_player_chunk_pos = current_chunk_pos
		update_chunks()

func update_chunks():
	var needed_chunks = []
	
	# Determine which chunks should exist
	for x in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
		for z in range(-RENDER_DISTANCE, RENDER_DISTANCE + 1):
			var chunk_coord = Vector2i(last_player_chunk_pos.x + x, last_player_chunk_pos.y + z)
			needed_chunks.append(chunk_coord)
			
			if not chunks.has(chunk_coord):
				create_chunk(chunk_coord.x, chunk_coord.y)
	
	# Remove chunks that are too far
	var chunks_to_remove = []
	for chunk_coord in chunks.keys():
		if not chunk_coord in needed_chunks:
			chunks_to_remove.append(chunk_coord)
			
	for chunk_coord in chunks_to_remove:
		remove_chunk(chunk_coord)

func create_chunk(x, z):
	var chunk = Chunk.new(x, z, noise)
	add_child(chunk)
	chunks[Vector2i(x, z)] = chunk

func remove_chunk(coord):
	if chunks.has(coord):
		chunks[coord].queue_free()
		chunks.erase(coord)
