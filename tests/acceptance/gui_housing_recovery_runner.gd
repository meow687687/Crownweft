extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GameUI = preload("res://scripts/presentation/game_ui.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const ScenarioCatalog = preload("res://scripts/domain/scenario_catalog.gd")

const SCREENSHOT_DIR: String = "/home/sumeet/.gemini/antigravity-cli/brain/ecdc4db2-f55c-4f79-82b5-bd2991cfb8d0/screenshots"

func _init() -> void:
	call_deferred("_run_acceptance_tests")

func _save_screenshot(name: String) -> void:
	await process_frame
	await process_frame
	var img: Image = root.get_viewport().get_texture().get_image()
	img.save_png(SCREENSHOT_DIR + "/" + name + ".png")
	print("[SCREENSHOT] Saved: " + name + ".png")

func _run_acceptance_tests() -> void:
	print("\n==============================================")
	print(" CROWNWEFT GUI HOUSING RECOVERY RUNNER (TASK 21.1) ")
	print("==============================================")

	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)

	await process_frame
	await process_frame
	await process_frame

	var ui: GameUI = world.ui
	assert(ui != null, "UI must exist")
	var origin: Vector2i = world.world_state.start_settlement_pos
	world.camera.position = Vector2(origin.x * 16.0, origin.y * 16.0)

	# --------------------------------------------------------------------------
	# Screenshot 78: Homeless Emergency Recovery Inspector
	# --------------------------------------------------------------------------
	print("\n>> Check 1: Capturing Homeless Emergency Recovery Inspector...")
	var homeless_c: CitizenState = world.citizens[0]
	homeless_c.energy = 15.0
	world._update_housing_and_rest() # Enters resting outdoors
	world.selected_citizen = homeless_c
	world._update_citizen_inspector()
	world._update_ui_state({"fed": 10, "hungry": 0, "at_risk": 0})

	await process_frame
	await process_frame
	await _save_screenshot("78_homeless_emergency_recovery_inspector")

	# --------------------------------------------------------------------------
	# Screenshot 79: House Construction & Subsequent Housed Rest
	# --------------------------------------------------------------------------
	print("\n>> Check 2: Capturing House Construction & Subsequent Housed Rest...")
	# Place and activate a house
	var house: BuildingState = world.place_building(&"house", origin + Vector2i(4, 0), true)
	# Position citizen at house entrance and update
	homeless_c.position_tile = house.get_entrance_tile()
	world._update_housing_and_rest()
	world._update_citizen_inspector()
	world._update_ui_state({"fed": 10, "hungry": 0, "at_risk": 0})

	await process_frame
	await process_frame
	await _save_screenshot("79_house_construction_and_housed_rest")

	print("\n==============================================")
	print(" ALL HOUSING RECOVERY SCREENSHOTS CAPTURED ")
	print("==============================================")
	quit(0)
