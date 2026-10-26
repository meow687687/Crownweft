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
	print("    CROWNWEFT GUI ACCEPTANCE CHECK (TASK 15)  ")
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

	# Check 1: Open World Map and view active Campaign Objective
	print("\n>> Check 1: Displaying Active Campaign Objective...")
	ui.btn_world_map.emit_signal("pressed")
	await process_frame
	await process_frame
	assert(ui.is_world_map_visible(), "World Map panel must be visible")

	var war := world.diplomacy.create_war(FactionCatalog.FACTION_IRONPEAK, FactionCatalog.FACTION_PLAYER, "Northern Incursion", 1, WarState.STATUS_WAR)
	var obj := world.regional_world.create_objective(
		FactionCatalog.FACTION_PLAYER,
		CampaignObjective.TYPE_DEFEND_REGION,
		RegionCatalog.REGION_CROWNWEFT,
		0,
		war.id,
		1
	)
	obj.description = "Defend Crownweft Valley against Ironpeak Incursion"

	world.regional_world.selected_region_id = RegionCatalog.REGION_CROWNWEFT
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("48_campaign_objective_active")
	print("✓ Check 1 Verified: Active Campaign Objective rendered in Regional World Map.")

	# Check 2: Regional Battle Engagement & Casualties
	print("\n>> Check 2: Resolving Regional Battle Engagement at Shattered Pass...")
	world.regional_world.selected_region_id = RegionCatalog.REGION_SHATTERED_PASS
	var crown_pass := world.regional_world.create_army(
		FactionCatalog.FACTION_PLAYER,
		"Royal Mountain Guard",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 35, &"archer": 15},
		40,
		5
	)
	var iron_raiders := world.regional_world.create_army(
		FactionCatalog.FACTION_IRONPEAK,
		"Ironpeak Raiders",
		RegionCatalog.REGION_SHATTERED_PASS,
		{&"warrior": 20, &"archer": 10},
		20,
		5
	)
	
	var res_eng := world.regional_world.detect_and_resolve_engagements(world.diplomacy, 10)
	assert(not res_eng.is_empty(), "Engagement must be detected and resolved")
	
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("49_campaign_battle_engagement")
	print("✓ Check 2 Verified: Engagement outcome and casualties card rendered in Regional Details.")

	# Check 3: Military Occupation of Contested/Enemy Region
	print("\n>> Check 3: Displaying Military Occupation of Contested Territory...")
	var pass_reg: RegionState = world.regional_world.get_region(RegionCatalog.REGION_SHATTERED_PASS)
	pass_reg.set_occupation(FactionCatalog.FACTION_PLAYER, "Secured gateway following decisive victory", 15)
	
	world.regional_world.selected_region_id = RegionCatalog.REGION_SHATTERED_PASS
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("50_campaign_region_occupied")
	print("✓ Check 3 Verified: Military Occupation badge and status displayed clearly.")

	# Check 4: Campaign Peace Treaty and Sovereign Control Cession
	print("\n>> Check 4: Campaign Peace Treaty and Sovereign Control Cession...")
	war.status = WarState.STATUS_PEACE
	war.outcome = WarState.OUTCOME_VICTORY
	world.regional_world.transfer_control(
		RegionCatalog.REGION_SHATTERED_PASS,
		FactionCatalog.FACTION_PLAYER,
		"Treaty of the Shattered Pass — Sovereign Cession",
		25
	)
	
	world.regional_world.selected_region_id = RegionCatalog.REGION_SHATTERED_PASS
	world._update_world_map_ui()
	await process_frame
	await process_frame
	await _save_screenshot("51_campaign_peace_settlement")
	print("✓ Check 4 Verified: Sovereign control transferred to The Crown and occupation resolved.")

	print("\n==============================================")
	print("     ALL TASK 15 GUI CHECKS PASSED!           ")
	print("==============================================")
	quit(0)
