extends SceneTree

const WorldScene = preload("res://scenes/world/world.gd")
const GameUI = preload("res://scripts/presentation/game_ui.gd")
const BuildingState = preload("res://scripts/domain/building_state.gd")
const CitizenState = preload("res://scripts/domain/citizen_state.gd")
const LawCatalog = preload("res://scripts/domain/law_catalog.gd")
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
	print(" CROWNWEFT GUI RESIDENTIAL LIFE RUNNER (TASK 21) ")
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
	# Screenshot 73: House Occupancy Inspector
	# --------------------------------------------------------------------------
	print("\n>> Check 1: Capturing House Occupancy Inspector...")
	var house: BuildingState = world.place_building(&"house", origin + Vector2i(4, 0), true)
	world._update_housing_and_rest()
	world.selected_building = house
	world._update_building_inspector()
	world._update_ui_state({"fed": 10, "hungry": 0, "at_risk": 0})

	await process_frame
	await process_frame
	await _save_screenshot("73_house_occupancy_inspector")

	# --------------------------------------------------------------------------
	# Screenshot 74: Citizen Residence Details
	# --------------------------------------------------------------------------
	print("\n>> Check 2: Capturing Citizen Residence Details...")
	world.selected_building = null
	var housed_citizen: CitizenState = world.citizens[0]
	world.selected_citizen = housed_citizen
	world._update_citizen_inspector()

	await process_frame
	await process_frame
	await _save_screenshot("74_citizen_residence_details")

	# --------------------------------------------------------------------------
	# Screenshot 75: Housing Shortage & Homeless Exhaustion HUD
	# --------------------------------------------------------------------------
	print("\n>> Check 3: Capturing Housing Shortage & Homeless Rest Blocker...")
	# Destroy house to create complete shortage
	house.is_destroyed = true
	world._update_housing_and_rest()
	var homeless_c: CitizenState = world.citizens[1]
	homeless_c.energy = 15.0 # Exhausted
	world._update_housing_and_rest() # Enters resting with blocker
	world.selected_citizen = homeless_c
	world._update_citizen_inspector()
	world._update_ui_state({"fed": 10, "hungry": 0, "at_risk": 0})

	await process_frame
	await process_frame
	await _save_screenshot("75_housing_shortage_hud")

	# --------------------------------------------------------------------------
	# Screenshot 76: Migration Arrival Event & Notification
	# --------------------------------------------------------------------------
	print("\n>> Check 4: Capturing Migration Arrival Event...")
	# Re-create ample housing
	house.is_destroyed = false
	var house2: BuildingState = world.place_building(&"house", origin + Vector2i(4, 3), true)
	var house3: BuildingState = world.place_building(&"house", origin + Vector2i(4, 6), true)
	world._update_housing_and_rest()

	# Provide food and approval
	var town_hall: BuildingState = world.buildings[0]
	town_hall.inventory.add_resource(&"bread", 80, "START")
	world.economy.approval = 85.0
	world.selected_citizen = null
	ui.show_citizen_details(null)

	# Trigger newcomer arrival
	world.migration_progress = 98.0
	world.tick_migration({"fed": 10, "hungry": 0, "at_risk": 0})
	world._update_ui_state({"fed": 11, "hungry": 0, "at_risk": 0})

	await process_frame
	await process_frame
	await _save_screenshot("76_migration_arrival_event")

	# --------------------------------------------------------------------------
	# Screenshot 77: Immigration Policy Decree
	# --------------------------------------------------------------------------
	print("\n>> Check 5: Capturing Immigration Policy Decree in Laws Panel...")
	ui.toggle_government_panel()
	world._update_government_ui()

	await process_frame
	await process_frame
	await _save_screenshot("77_immigration_policy_decree")
	ui.toggle_government_panel()

	print("\n==============================================")
	print(" ALL 5 RESIDENTIAL LIFE SCREENSHOTS CAPTURED ")
	print("==============================================")
	quit(0)
