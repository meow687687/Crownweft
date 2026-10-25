extends SceneTree

func _init() -> void:
	print("--- Running TestInventory ---")
	test_capacity_and_bounds()
	test_reservations()
	test_atomic_transfer()
	print("--- TestInventory PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		quit(1)

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		quit(1)

func test_capacity_and_bounds() -> void:
	var inv: Inventory = Inventory.new(1, 20, [&"grain", &"bread"])
	assert_eq(inv.get_free_capacity(), 20, "Initial free capacity should be 20")
	
	# Cannot add negative or zero
	assert_true(not inv.add_resource(&"grain", -5, "TEST"), "Negative add should fail")
	assert_true(not inv.add_resource(&"grain", 0, "TEST"), "Zero add should fail")
	
	# Add valid amount
	assert_true(inv.add_resource(&"grain", 15, "TEST"), "Add 15 grain should succeed")
	assert_eq(inv.get_quantity(&"grain"), 15, "Grain quantity should be 15")
	assert_eq(inv.get_free_capacity(), 5, "Free capacity should be 5")
	
	# Exceed capacity
	assert_true(not inv.add_resource(&"grain", 10, "TEST"), "Adding 10 more to cap 20 should fail")
	assert_eq(inv.get_quantity(&"grain"), 15, "Grain should still be 15")
	
	# Reject unaccepted resource
	assert_true(not inv.add_resource(&"stone", 2, "TEST"), "Stone should be rejected")
	
	# Remove valid amount
	assert_true(inv.remove_resource(&"grain", 5, "TEST"), "Remove 5 grain should succeed")
	assert_eq(inv.get_quantity(&"grain"), 10, "Grain should now be 10")
	
	# Cannot remove more than available
	assert_true(not inv.remove_resource(&"grain", 20, "TEST"), "Removing 20 when 10 exist should fail")
	assert_eq(inv.get_quantity(&"grain"), 10, "Grain should remain 10")

func test_reservations() -> void:
	var inv: Inventory = Inventory.new(2, 30)
	inv.add_resource(&"timber", 20, "TEST")
	
	# Outbound reservation
	assert_true(inv.reserve_out(&"timber", 8), "Reserve out 8 should succeed")
	assert_eq(inv.get_available_outgoing(&"timber"), 12, "Available outgoing should be 12")
	assert_true(not inv.reserve_out(&"timber", 15), "Reserving more than available should fail")
	
	# Inbound reservation accounts for free capacity
	# Total qty = 20, cap = 30. Free cap = 10.
	assert_eq(inv.get_free_capacity(), 10, "Free cap should be 10")
	assert_true(inv.reserve_in(&"stone", 6), "Reserve in 6 should succeed")
	assert_eq(inv.get_free_capacity(), 4, "Free cap after reserve_in should be 4")
	assert_true(not inv.reserve_in(&"stone", 5), "Reserve in 5 when free cap 4 should fail")
	
	# Release reservations
	inv.release_reserved_out(&"timber", 8)
	assert_eq(inv.get_available_outgoing(&"timber"), 20, "Outgoing available restored to 20")
	inv.release_reserved_in(&"stone", 6)
	assert_eq(inv.get_free_capacity(), 10, "Free cap restored to 10")

func test_atomic_transfer() -> void:
	var src: Inventory = Inventory.new(10, 50)
	var dst: Inventory = Inventory.new(20, 10)
	
	src.add_resource(&"bread", 25, "TEST")
	
	# Transfer 5 (fits in dst cap 10)
	var ok: bool = Inventory.transfer_atomic(src, dst, &"bread", 5, "TEST_TRANSFER")
	assert_true(ok, "Transfer 5 bread should succeed")
	assert_eq(src.get_quantity(&"bread"), 20)
	assert_eq(dst.get_quantity(&"bread"), 5)
	
	# Transfer 10 (dst has 5, cap 10, free 5 -> cannot take 10)
	var fail_overflow: bool = Inventory.transfer_atomic(src, dst, &"bread", 10, "TEST_TRANSFER")
	assert_true(not fail_overflow, "Transfer exceeding dst capacity must fail")
	assert_eq(src.get_quantity(&"bread"), 20, "Source must remain unchanged on failure")
	assert_eq(dst.get_quantity(&"bread"), 5, "Dest must remain unchanged on failure")
	
	# Transfer more than src has
	var dst2: Inventory = Inventory.new(30, 100)
	var fail_lack: bool = Inventory.transfer_atomic(src, dst2, &"bread", 100, "TEST_TRANSFER")
	assert_true(not fail_lack, "Transfer exceeding source stock must fail")
	assert_eq(src.get_quantity(&"bread"), 20)
	assert_eq(dst2.get_quantity(&"bread"), 0)
