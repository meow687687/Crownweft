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
	"res://tests/integration/test_simulation_proof.gd",
	"res://tests/integration/test_military_slice.gd",
	"res://tests/integration/test_physical_hauling.gd"
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
