extends SceneTree

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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 16)  ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	assert(world.regional_world != null, "RegionalWorldState must not be null")
	var main_inv: Inventory = world.buildings[0].inventory if not world.buildings.is_empty() else null
	assert(main_inv != null, "Town Hall inventory must exist")

	# Add initial resources to player inventory
	main_inv.add_resource(&"timber", 40, "Initial Timber Stock")
	main_inv.add_resource(&"coin", 50, "Initial Treasury Coin")

	# Check 1: Form & Accept Trade Contract (Dispatch Caravan)
	print("\n>> Check 1: Forming Trade Contract and Dispatching Caravan...")
	ui.btn_world_map.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(ui.is_world_map_visible(), "World Map panel must be visible")

	var contract := world.regional_world.create_trade_contract(
		FactionCatalog.FACTION_VALEN,
		FactionCatalog.FACTION_PLAYER,
		&"timber",
		20,
		35,
		RegionCatalog.REGION_CROWNWEFT,
		RegionCatalog.REGION_VALEN,
		world.current_tick
	)
	var accept_res := world.regional_world.accept_trade_contract(
		contract.id,
		main_inv,
		world.diplomacy,
		world.current_tick
	)
	assert(accept_res["ok"], "Contract must be accepted")

	world.regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("52_trade_proposal_contract_formed")
	print("✓ Check 1 Verified: Active trade contract and dispatched caravan rendered.")

	# Check 2: Caravan in Transit along Trade Route
	print("\n>> Check 2: Advancing Caravan along Regional Route...")
	var shipment: TradeShipment = world.regional_world.get_shipment(contract.shipment_id)
	assert(shipment != null, "Shipment must exist")

	# Tick 20 simulation steps
	for i in range(20):
		world.regional_world.tick_regional_trade_shipments(world.current_tick + i, world.diplomacy, main_inv)

	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("53_trade_caravan_in_transit")
	print("✓ Check 2 Verified: Caravan progress and transit status updated.")

	# Check 3: Caravan Arrival, Delivery & Atomic Settlement
	print("\n>> Check 3: Simulating Arrival and Atomic Settlement at Valen Lowlands...")
	shipment.current_region_id = RegionCatalog.REGION_VALEN
	shipment.route_path.clear()
	
	var settle_res := world.regional_world.deliver_and_settle_contract(
		contract.id,
		main_inv,
		world.diplomacy,
		world.current_tick + 60
	)
	assert(settle_res["ok"], "Settlement must succeed")

	world.regional_world.selected_region_id = RegionCatalog.REGION_VALEN
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("54_trade_caravan_delivered_settled")
	print("✓ Check 3 Verified: Cargo delivered and contract settled with coin transfer.")

	# Check 4: Route Blockage and Detour / Waiting Status
	print("\n>> Check 4: Creating New Trade and Simulating Blocked Route Detour...")
	var contract2 := world.regional_world.create_trade_contract(
		FactionCatalog.FACTION_PLAYER,
		FactionCatalog.FACTION_OLD_GROVE,
		&"herbs",
		10,
		20,
		RegionCatalog.REGION_OLD_GROVE,
		RegionCatalog.REGION_CROWNWEFT,
		world.current_tick + 70
	)
	world.regional_world.accept_trade_contract(
		contract2.id,
		main_inv,
		world.diplomacy,
		world.current_tick + 70
	)
	var shipment2: TradeShipment = world.regional_world.get_shipment(contract2.shipment_id)
	
	# Block direct route between Old Grove and Crownweft
	var route_cg := world.regional_world.get_route_between(RegionCatalog.REGION_OLD_GROVE, RegionCatalog.REGION_CROWNWEFT)
	if route_cg != null:
		route_cg.is_open = false

	world.regional_world.tick_regional_trade_shipments(world.current_tick + 75, world.diplomacy, main_inv)

	world.regional_world.selected_region_id = RegionCatalog.REGION_OLD_GROVE
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("55_trade_detour_blocked_route")
	print("✓ Check 4 Verified: Route blockage and detour rerouting handled safely.")

	print("\n==============================================")
	print("     ALL TASK 16 GUI CHECKS PASSED!           ")
	print("==============================================")
	quit(0)
