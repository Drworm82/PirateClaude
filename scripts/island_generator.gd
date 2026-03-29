extends Node
class_name IslandGenerator

var seed_value: int = 0
var island_size: Vector2i = Vector2i(40, 40)
var tile_size: int = 16
var parent_node: Node2D
var noise: FastNoiseLite

enum Biome {DEEP_WATER, SHALLOW_WATER, SAND, GRASS, JUNGLE}

const BIOME_COLORS := {
	Biome.DEEP_WATER: Color(0.0, 0.2, 0.5),
	Biome.SHALLOW_WATER: Color(0.0, 0.4, 0.7),
	Biome.SAND: Color(1.0, 0.95, 0.8),
	Biome.GRASS: Color(0.3, 0.7, 0.2),
	Biome.JUNGLE: Color(0.1, 0.5, 0.1)
}

func setup(p_seed: int, size: Vector2i, parent: Node2D) -> void:
	seed_value = p_seed
	island_size = size
	parent_node = parent
	noise = FastNoiseLite.new()
	noise.seed = seed_value
	noise.frequency = 0.08

func generate() -> void:
	for x in range(island_size.x):
		for y in range(island_size.y):
			var biome := _get_biome_at(x, y)
			_draw_tile(Vector2i(x, y), biome)

func _get_biome_at(x: int, y: int) -> Biome:
	var nx := float(x) / float(island_size.x) * 2.0 - 1.0
	var ny := float(y) / float(island_size.y) * 2.0 - 1.0
	var dist := sqrt(nx * nx + ny * ny)
	var noise_val := noise.get_noise_2d(x, y)
	var height := noise_val * 0.5 + 0.5 - dist * 0.8
	
	if height < 0.25:
		return Biome.DEEP_WATER
	elif height < 0.35:
		return Biome.SHALLOW_WATER
	elif height < 0.45:
		return Biome.SAND
	elif height < 0.7:
		return Biome.GRASS
	else:
		return Biome.JUNGLE

func _draw_tile(pos: Vector2i, biome: Biome) -> void:
	var rect := ColorRect.new()
	rect.size = Vector2(tile_size, tile_size)
	rect.color = BIOME_COLORS[biome]
	rect.position = Vector2(pos) * tile_size
	if is_instance_valid(parent_node):
		parent_node.add_child(rect)
