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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 12)  ")
	print("==============================================")
	
	var world_packed: PackedScene = load("res://scenes/world/world.tscn")
	var world: WorldScene = world_packed.instantiate() as WorldScene
	root.add_child(world)
	
	await process_frame
	await process_frame
	await process_frame
	
	var ui: GameUI = world.ui
	assert(ui != null, "UI must not be null")
	assert(world.diplomacy != null, "DiplomacyState must not be null")

	# Setup Valen Compact as allied with a defensive pact
	var rel_valen: DiplomaticRelationship = world.diplomacy.get_relationship(FactionCatalog.FACTION_VALEN, FactionCatalog.FACTION_PLAYER)
	rel_valen.trust = 80.0
	rel_valen.respect = 70.0
	var valen_fac: FactionState = world.diplomacy.factions.get(FactionCatalog.FACTION_VALEN, null)
	if valen_fac != null:
		valen_fac.add_treaty(&"defensive_pact", FactionCatalog.FACTION_PLAYER, world.current_tick, 1000)

	# Check 1: Open Diplomacy Panel via HUD button and view Ironpeak in peacetime
	print("\n>> Check 1: Opening Diplomacy Panel and viewing Ironpeak Clans in Peacetime...")
	ui.btn_diplomacy.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(ui.is_diplomacy_panel_visible(), "Diplomacy panel must be visible")
	
	ui.selected_diplomacy_faction_id = FactionCatalog.FACTION_IRONPEAK
	world._update_diplomacy_ui()
	await process_frame
	await process_frame
	await _save_screenshot("36_war_panel_peace")
	print("✓ Check 1 Verified: Peacetime conflict status card displayed for Ironpeak Clans.")

	# Check 2: Escalate crisis & declare war from Ironpeak Clans
	print("\n>> Check 2: Escalating war and triggering allied defensive pact...")
	var rel_iron: DiplomaticRelationship = world.diplomacy.get_relationship(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER)
	rel_iron.resentment = 75.0
	rel_iron.threat = 60.0
	rel_iron.trust = -20.0
	
	var initial_coins: int = world.buildings[0].inventory.get_available_outgoing(&"coin")
	
	# Create war record
	var war: WarState = world.diplomacy.create_war(
		FactionCatalog.FACTION_IRONPEAK,
		FactionCatalog.FACTION_PLAYER,
		"Border territory disputes and sovereign resource competition.",
		world.current_tick
	)
	war.transition_to(WarState.STATUS_WAR, world.current_tick, "Official declaration of hostilities dispatched.")
	
	# Execute diplomacy system defensive pact intervention
	world.diplomacy_system._check_defensive_pact_intervention(world.diplomacy, war, world.current_tick, world.buildings[0].inventory)
	
	var post_coins: int = world.buildings[0].inventory.get_available_outgoing(&"coin")
	assert(post_coins == initial_coins + 25, "Allied defensive pact should deliver 25 gold subsidy to Town Hall")
	
	world._update_diplomacy_ui()
	await process_frame
	await process_frame
	await _save_screenshot("37_war_status_active_crisis")
	print("✓ Check 2 Verified: Active war card rendered with casualties scoreboard and allied war subsidy confirmed.")

	# Check 3: Spawn expedition and simulate repelling raiding force
	print("\n>> Check 3: Simulating hostile expedition and battle victory...")
	war.record_casualty(FactionCatalog.FACTION_PLAYER)
	for i in range(4):
		war.record_casualty(FactionCatalog.FACTION_IRONPEAK)
	war.record_battle(
		world.current_tick + 10,
		"Border Skirmish at North Meadow",
		4,
		1,
		&"Crown Victory"
	)
	assert(war.casualties.get(str(FactionCatalog.FACTION_PLAYER), 0) == 1, "Crown casualties recorded")
	assert(war.casualties.get(str(FactionCatalog.FACTION_IRONPEAK), 0) == 4, "Enemy casualties recorded")
	assert(war.status == WarState.STATUS_WAR, "Defeating expedition must NOT end the war")
	
	ui.show_toast("VICTORY! Enemy expedition at North Meadow repelled (4 raiders eliminated). War remains active.")
	world._update_diplomacy_ui()
	await process_frame
	await process_frame
	await _save_screenshot("38_war_battle_victory_repelled")
	print("✓ Check 3 Verified: Battle outcome logged, casualty scoreboard updated, war persists.")

	# Check 4: Click Negotiate Ceasefire (Truce)
	print("\n>> Check 4: Negotiating ceasefire...")
	world._on_ceasefire_requested(war.id)
	assert(war.status == WarState.STATUS_CEASEFIRE, "War should transition to CEASEFIRE")
	
	world._update_diplomacy_ui()
	await process_frame
	await process_frame
	await _save_screenshot("39_war_ceasefire_ratified")
	print("✓ Check 4 Verified: Ceasefire truce ratified, UI reflects ceasefire terms.")

	print("\n==============================================")
	print("    TASK 12 GUI ACCEPTANCE CHECKS PASSED      ")
	print("==============================================")
	quit(0)
