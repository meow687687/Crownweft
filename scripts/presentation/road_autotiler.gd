class_name RoadAutotiler
extends RefCounted

## Road Autotiler for Crownweft
##
## Computes road autotiling bitmasks from logical road state and produces
## corresponding 16x16 tile visual variants.
##
## Bit convention:
##   North: 1  (1 << 0)
##   East:  2  (1 << 1)
##   South: 4  (1 << 2)
##   West:  8  (1 << 3)
##
## All 16 masks:
##   0: Isolated tile (no neighbours)
##   1: North endpoint
##   2: East endpoint
##   4: South endpoint
##   8: West endpoint
##   5: Vertical straight road (North + South)
##   10: Horizontal straight road (East + West)
##   3: NE corner (North + East)
##   6: SE corner (East + South)
##   12: SW corner (South + West)
##   9: NW corner (North + West)
##   7: T-junction (North + East + South)
##   11: T-junction (North + East + West)
##   13: T-junction (North + South + West)
##   14: T-junction (East + South + West)
##   15: Four-way intersection (North + East + South + West)

const MASK_NONE: int = 0
const MASK_NORTH: int = 1
const MASK_EAST: int = 2
const MASK_SOUTH: int = 4
const MASK_WEST: int = 8

const MASK_VERTICAL: int = 5    # North | South
const MASK_HORIZONTAL: int = 10 # East | West
const MASK_CORNER_NE: int = 3   # North | East
const MASK_CORNER_SE: int = 6   # East | South
const MASK_CORNER_SW: int = 12  # South | West
const MASK_CORNER_NW: int = 9   # North | West
const MASK_TEE_NES: int = 7     # North | East | South (faces West)
const MASK_TEE_NEW: int = 11    # North | East | West  (faces South)
const MASK_TEE_NSW: int = 13    # North | South | West (faces East)
const MASK_TEE_ESW: int = 14    # East | South | West  (faces North)
const MASK_CROSS: int = 15      # North | East | South | West

const TILE_WIDTH: int = 16
const TILE_HEIGHT: int = 16

# Dirt road color palette extracted from assets/pixel/tiles/road.png
const COLOR_EDGE: Color = Color(84.0 / 255.0, 68.0 / 255.0, 47.0 / 255.0, 1.0)
const COLOR_FILL_A: Color = Color(146.0 / 255.0, 115.0 / 255.0, 74.0 / 255.0, 1.0)
const COLOR_FILL_B: Color = Color(192.0 / 255.0, 154.0 / 255.0, 92.0 / 255.0, 1.0)
const COLOR_HIGHLIGHT: Color = Color(170.0 / 255.0, 135.0 / 255.0, 83.0 / 255.0, 1.0)
const COLOR_TRANSPARENT: Color = Color(0.0, 0.0, 0.0, 0.0)

# Cached variant images (mask 0..15 -> Image)
static var _variant_cache: Dictionary = {}

static func has_road(world_state: WorldState, coord: Vector2i) -> bool:
	if world_state == null or not world_state.is_valid_coord(coord):
		return false
	var tile: WorldTile = world_state.get_tile(coord)
	return tile != null and tile.road_level > 0

static func get_road_mask(world_state: WorldState, coord: Vector2i) -> int:
	if not has_road(world_state, coord):
		return MASK_NONE
		
	var mask: int = 0
	if has_road(world_state, coord + Vector2i(0, -1)):
		mask |= MASK_NORTH
	if has_road(world_state, coord + Vector2i(1, 0)):
		mask |= MASK_EAST
	if has_road(world_state, coord + Vector2i(0, 1)):
		mask |= MASK_SOUTH
	if has_road(world_state, coord + Vector2i(-1, 0)):
		mask |= MASK_WEST
	return mask

static func get_affected_coords(coord: Vector2i, world_state: WorldState = null) -> Array[Vector2i]:
	var result: Array[Vector2i] = [
		coord,
		coord + Vector2i(0, -1),
		coord + Vector2i(1, 0),
		coord + Vector2i(0, 1),
		coord + Vector2i(-1, 0)
	]
	if world_state == null:
		return result
		
	var filtered: Array[Vector2i] = []
	for c in result:
		if world_state.is_valid_coord(c):
			filtered.append(c)
	return filtered

static func get_variant_image(mask: int) -> Image:
	var clamped_mask: int = mask & 0xF
	if _variant_cache.has(clamped_mask):
		return _variant_cache[clamped_mask]
	var img: Image = _create_variant_image(clamped_mask)
	_variant_cache[clamped_mask] = img
	return img

static func _create_variant_image(mask: int) -> Image:
	var img: Image = Image.create(TILE_WIDTH, TILE_HEIGHT, false, Image.FORMAT_RGBA8)
	img.fill(COLOR_TRANSPARENT)

	# 1. Base center hub (x: 4..11, y: 4..11)
	for y in range(4, 12):
		for x in range(4, 12):
			var col: Color = COLOR_FILL_B if ((x + y) % 3 == 0) else COLOR_FILL_A
			img.set_pixel(x, y, col)

	# 2. North Arm (x: 4..11, y: 0..3)
	if (mask & MASK_NORTH) != 0:
		for y in range(0, 4):
			img.set_pixel(4, y, COLOR_EDGE)
			img.set_pixel(11, y, COLOR_EDGE)
			for x in range(5, 11):
				var col: Color = COLOR_FILL_B if ((x + y) % 3 == 0) else COLOR_FILL_A
				img.set_pixel(x, y, col)
	else:
		# Closed North edge on center hub
		for x in range(4, 12):
			img.set_pixel(x, 4, COLOR_EDGE)

	# 3. East Arm (x: 12..15, y: 4..11)
	if (mask & MASK_EAST) != 0:
		for x in range(12, 16):
			img.set_pixel(x, 4, COLOR_EDGE)
			img.set_pixel(x, 11, COLOR_EDGE)
			for y in range(5, 11):
				var col: Color = COLOR_FILL_B if ((x + y) % 3 == 0) else COLOR_FILL_A
				img.set_pixel(x, y, col)
	else:
		# Closed East edge on center hub
		for y in range(4, 12):
			img.set_pixel(11, y, COLOR_EDGE)

	# 4. South Arm (x: 4..11, y: 12..15)
	if (mask & MASK_SOUTH) != 0:
		for y in range(12, 16):
			img.set_pixel(4, y, COLOR_EDGE)
			img.set_pixel(11, y, COLOR_EDGE)
			for x in range(5, 11):
				var col: Color = COLOR_FILL_B if ((x + y) % 3 == 0) else COLOR_FILL_A
				img.set_pixel(x, y, col)
	else:
		# Closed South edge on center hub
		for x in range(4, 12):
			img.set_pixel(x, 11, COLOR_EDGE)

	# 5. West Arm (x: 0..3, y: 4..11)
	if (mask & MASK_WEST) != 0:
		for x in range(0, 4):
			img.set_pixel(x, 4, COLOR_EDGE)
			img.set_pixel(x, 11, COLOR_EDGE)
			for y in range(5, 11):
				var col: Color = COLOR_FILL_B if ((x + y) % 3 == 0) else COLOR_FILL_A
				img.set_pixel(x, y, col)
	else:
		# Closed West edge on center hub
		for y in range(4, 12):
			img.set_pixel(4, y, COLOR_EDGE)

	# 6. Corner resolution
	# Top-Left (4, 4)
	if (mask & MASK_NORTH) != 0 and (mask & MASK_WEST) != 0:
		img.set_pixel(4, 4, COLOR_EDGE) # Inner corner
	elif (mask & MASK_NORTH) == 0 and (mask & MASK_WEST) == 0:
		img.set_pixel(4, 4, COLOR_EDGE) # Outer corner
	
	# Top-Right (11, 4)
	if (mask & MASK_NORTH) != 0 and (mask & MASK_EAST) != 0:
		img.set_pixel(11, 4, COLOR_EDGE)
	elif (mask & MASK_NORTH) == 0 and (mask & MASK_EAST) == 0:
		img.set_pixel(11, 4, COLOR_EDGE)
		
	# Bottom-Left (4, 11)
	if (mask & MASK_SOUTH) != 0 and (mask & MASK_WEST) != 0:
		img.set_pixel(4, 11, COLOR_EDGE)
	elif (mask & MASK_SOUTH) == 0 and (mask & MASK_WEST) == 0:
		img.set_pixel(4, 11, COLOR_EDGE)
		
	# Bottom-Right (11, 11)
	if (mask & MASK_SOUTH) != 0 and (mask & MASK_EAST) != 0:
		img.set_pixel(11, 11, COLOR_EDGE)
	elif (mask & MASK_SOUTH) == 0 and (mask & MASK_EAST) == 0:
		img.set_pixel(11, 11, COLOR_EDGE)

	return img
