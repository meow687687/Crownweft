extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("--- Running TestNeeds ---")
	test_citizen_feeding_and_shortage()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestNeeds PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_citizen_feeding_and_shortage() -> void:
	var needs_sys: NeedsSystem = NeedsSystem.new()
	var storehouse_inv: Inventory = Inventory.new(501, 100, [&"bread"])
	storehouse_inv.add_resource(&"bread", 2, "INITIAL_FOOD")
	
	var c1: CitizenState = CitizenState.new(1)
	var c2: CitizenState = CitizenState.new(2)
	var citizens: Array[CitizenState] = [c1, c2]
	
	# Simulate meal times
	# c1 eats when (tick + 1) % 24 == 0 -> tick = 23
	var res1: Dictionary = needs_sys.tick_citizens(citizens, [storehouse_inv], 23)
	assert_eq(c1.food_state, CitizenState.FoodState.FED)
	assert_eq(storehouse_inv.get_quantity(&"bread"), 1, "1 bread consumed by c1")
	
	# c2 eats when (tick + 2) % 24 == 0 -> tick = 22
	var res2: Dictionary = needs_sys.tick_citizens(citizens, [storehouse_inv], 22)
	assert_eq(c2.food_state, CitizenState.FoodState.FED)
	assert_eq(storehouse_inv.get_quantity(&"bread"), 0, "Last bread consumed by c2")
	
	# Next meal with empty storehouse -> causes hunger
	needs_sys.tick_citizens(citizens, [storehouse_inv], 23 + 24)
	assert_eq(c1.food_state, CitizenState.FoodState.HUNGRY, "c1 must become hungry when food empty")
	assert_eq(c1.hunger_counter, 1)
	
	# Two more missed meals -> becomes AT_RISK
	needs_sys.tick_citizens(citizens, [storehouse_inv], 23 + 48)
	needs_sys.tick_citizens(citizens, [storehouse_inv], 23 + 72)
	assert_eq(c1.food_state, CitizenState.FoodState.AT_RISK, "Repeated shortages make citizen AT_RISK")
	assert_eq(c1.hunger_counter, 3)
