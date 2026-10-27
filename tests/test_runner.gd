extends SceneTree

const SUITES: Array[String] = [
	"res://tests/unit/test_inventory.gd",
	"res://tests/unit/test_job_board.gd",
	"res://tests/unit/test_production.gd",
	"res://tests/unit/test_world_gen.gd",
	"res://tests/unit/test_pathfinding.gd",
	"res://tests/unit/test_needs.gd",
	"res://tests/unit/test_combat.gd",
	"res://tests/unit/test_economy.gd",
	"res://tests/unit/test_save_load.gd",
	"res://tests/unit/test_construction.gd",
	"res://tests/unit/test_entrances.gd",
	"res://tests/unit/test_road_autotiling.gd",
	"res://tests/unit/test_citizen_skills_needs.gd",
	"res://tests/unit/test_configurable_footprints.gd",
	"res://tests/unit/test_workforce_management.gd",
	"res://tests/unit/test_species_foundation.gd",
	"res://tests/unit/test_social_classes.gd",
	"res://tests/unit/test_culture_beliefs.gd",
	"res://tests/unit/test_government_laws.gd",
	"res://tests/unit/test_political_agents.gd",
	"res://tests/unit/test_war_peace_military.gd",
	"res://tests/unit/test_regional_world.gd",
	"res://tests/unit/test_regional_armies.gd",
	"res://tests/unit/test_regional_campaigns.gd",
	"res://tests/unit/test_regional_trade.gd",
	"res://tests/integration/test_simulation_proof.gd",
	"res://tests/integration/test_military_slice.gd",
	"res://tests/integration/test_physical_hauling.gd",
	"res://tests/integration/test_end_to_end_scenario.gd",
	"res://tests/integration/test_long_running_simulation.gd",
	"res://tests/integration/test_adversarial_failures.gd",
	"res://tests/integration/test_save_load_determinism.gd",
	"res://tests/integration/test_playable_alpha.gd",
	"res://tests/integration/test_alpha_hardening.gd",
	"res://tests/integration/test_scenario_variety.gd",
	"res://tests/integration/test_residential_life.gd",
	"res://tests/integration/test_housing_recovery.gd",
	"res://tests/integration/test_civic_incidents.gd"
]

func _init() -> void:
	print("\n==============================================")
	print("           CROWNWEFT TEST SUITE RUNNER       ")
	print("==============================================")
	
	var all_passed: bool = true
	var godot_bin: String = OS.get_executable_path()
	
	for suite_path: String in SUITES:
		print("\n>> Executing: %s" % suite_path)
		var output: Array = []
		var exit_code: int = OS.execute(godot_bin, ["--headless", "--path", ProjectSettings.globalize_path("res://"), "--script", suite_path], output, true)
		for line in output:
			print(line)
		if exit_code != 0:
			printerr("!! Suite FAILED with exit code: %d" % exit_code)
			all_passed = false
			break
			
	if all_passed:
		print("\n==============================================")
		print("  ALL SUITES PASSED — EXIT GATES SATISFIED!   ")
		print("==============================================\n")
		quit(0)
	else:
		printerr("\nTEST RUNNER FAILED.")
		quit(1)
