extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("--- Running TestEconomy ---")
	test_tax_income_and_rates()
	test_approval_drift_and_shortage_impact()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestEconomy PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("FAILED ASSERTION: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("FAILED ASSERTION: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_tax_income_and_rates() -> void:
	var eco_sys: EconomySystem = EconomySystem.new()
	var eco: EconomyState = EconomyState.new()
	var inv: Inventory = Inventory.new(1, 300)
	
	# Initial default: Normal tax (2 coin per capita)
	assert_eq(eco.get_tax_rate_per_capita(), 2)
	assert_eq(eco.get_tax_level_name(), "Normal")
	
	# Population 20 at tick 40 -> 40 Coin collected
	eco_sys.tick_economy(eco, 20, 0, 0, inv, 40)
	assert_eq(eco.last_tax_income, 40)
	assert_eq(inv.get_quantity(&"coin"), 40)
	
	# Switch to High tax (4 coin per capita)
	eco.tax_level = EconomyState.TaxLevel.HIGH
	assert_eq(eco.get_tax_rate_per_capita(), 4)
	eco_sys.tick_economy(eco, 20, 0, 0, inv, 80)
	assert_eq(eco.last_tax_income, 80)
	assert_eq(inv.get_quantity(&"coin"), 120, "Total coins: 40 + 80 = 120")
	
	# Switch to Low tax (1 coin per capita)
	eco.tax_level = EconomyState.TaxLevel.LOW
	assert_eq(eco.get_tax_rate_per_capita(), 1)
	eco_sys.tick_economy(eco, 20, 0, 0, inv, 120)
	assert_eq(eco.last_tax_income, 20)
	assert_eq(inv.get_quantity(&"coin"), 140)

func test_approval_drift_and_shortage_impact() -> void:
	var eco_sys: EconomySystem = EconomySystem.new()
	var eco: EconomyState = EconomyState.new()
	var inv: Inventory = Inventory.new(1, 100)
	eco.approval = 60.0
	
	# High tax without shortages drifts downward toward 25.0
	eco.tax_level = EconomyState.TaxLevel.HIGH
	eco_sys.tick_economy(eco, 10, 0, 0, inv, 40)
	assert_true(eco.approval < 60.0, "Approval should decrease under High tax")
	
	# Low tax drifts upward toward 85.0
	eco.tax_level = EconomyState.TaxLevel.LOW
	eco.approval = 50.0
	eco_sys.tick_economy(eco, 10, 0, 0, inv, 80)
	assert_true(eco.approval > 50.0, "Approval should rise under Low tax")
	
	# Starvation penalty crushes approval
	# 3 hungry, 2 at-risk citizens
	eco_sys.tick_economy(eco, 10, 3, 2, inv, 120)
	# penalty = 3*5 + 2*15 = 45 -> target drops to 40
	assert_true(eco.approval < 55.0, "Starvation significantly penalizes public approval")
