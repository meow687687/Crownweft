class_name SaveService
extends RefCounted

const DEFAULT_SAVE_PATH: String = "user://saves/quicksave.json"

static func save_game_to_file(
	world_state: WorldState,
	economy: EconomyState,
	buildings: Array[BuildingState],
	citizens: Array[CitizenState],
	military_units: Array[MilitaryUnitState],
	job_board: JobBoard,
	current_tick: int,
	sim_speed: float,
	file_path: String = DEFAULT_SAVE_PATH,
	auto_staffing_enabled: bool = false,
	government: GovernmentState = null,
	diplomacy: DiplomacyState = null
) -> bool:
	var data: Dictionary = SaveSchema.serialize(
		world_state,
		economy,
		buildings,
		citizens,
		military_units,
		job_board,
		current_tick,
		sim_speed,
		auto_staffing_enabled,
		government,
		diplomacy
	)
	var json_str: String = JSON.stringify(data, "  ")
	
	# Ensure directory exists
	var dir_path: String = file_path.get_base_dir()
	if not DirAccess.dir_exists_absolute(dir_path):
		DirAccess.make_dir_recursive_absolute(dir_path)
		
	var file: FileAccess = FileAccess.open(file_path, FileAccess.WRITE)
	if file == null:
		printerr("Failed to open save file for writing: ", file_path)
		return false
		
	file.store_string(json_str)
	file.close()
	return true

static func load_game_from_file(file_path: String = DEFAULT_SAVE_PATH) -> Dictionary:
	if not FileAccess.file_exists(file_path):
		printerr("Save file does not exist: ", file_path)
		return {}
		
	var file: FileAccess = FileAccess.open(file_path, FileAccess.READ)
	if file == null:
		return {}
		
	var json_str: String = file.get_as_text()
	file.close()
	
	var json: JSON = JSON.new()
	var error: Error = json.parse(json_str)
	if error != OK:
		printerr("Failed to parse save JSON: ", json.get_error_message())
		return {}
		
	var data: Dictionary = json.data
	return SaveSchema.deserialize(data)
