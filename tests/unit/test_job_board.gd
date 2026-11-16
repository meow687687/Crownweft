extends SceneTree

# quit() does not stop a running _init, so failures are counted and the exit code is decided once at the end.
var _failed_assertions: int = 0

func _init() -> void:
	print("--- Running TestJobBoard ---")
	test_job_lifecycle()
	test_job_cancellation_release_once()
	test_insufficient_stock_or_capacity()
	if _failed_assertions > 0:
		printerr("!! SUITE FAILED with %d assertion errors" % _failed_assertions)
		quit(1)
		return
	print("--- TestJobBoard PASSED ---\n")
	quit(0)

func assert_true(cond: bool, msg: String = "") -> void:
	if not cond:
		printerr("Assertion failed: ", msg)
		_failed_assertions += 1

func assert_eq(a, b, msg: String = "") -> void:
	if a != b:
		printerr("Assertion failed: expected %s, got %s. %s" % [str(b), str(a), msg])
		_failed_assertions += 1

func test_job_lifecycle() -> void:
	var board: JobBoard = JobBoard.new()
	var src: Inventory = Inventory.new(101, 50)
	var dst: Inventory = Inventory.new(102, 20)
	
	src.add_resource(&"grain", 30, "START_STOCK")
	
	# Create haul job for 15 grain
	var job: HaulJob = board.create_job(&"grain", 15, src, dst, 1, 10)
	assert_true(job != null, "Job should be created")
	assert_eq(job.status, HaulJob.Status.RESERVED)
	assert_eq(src.get_available_outgoing(&"grain"), 15, "Source should have 15 available outgoing")
	assert_eq(src.get_reserved_out(&"grain"), 15, "Source should have 15 reserved out")
	assert_eq(dst.get_free_capacity(), 5, "Dest capacity 20 - 15 reserved_in = 5")
	assert_eq(dst.get_reserved_in(&"grain"), 15)
	
	# Assign hauler
	var assign_ok: bool = board.assign_job(job, 77)
	assert_true(assign_ok)
	assert_eq(job.status, HaulJob.Status.ASSIGNED)
	assert_eq(job.assigned_citizen_id, 77)
	
	# Execute pickup
	var pickup_ok: bool = board.execute_pickup(job, src)
	assert_true(pickup_ok)
	assert_eq(job.status, HaulJob.Status.IN_TRANSIT)
	assert_eq(src.get_quantity(&"grain"), 15, "Grain physically left source")
	assert_eq(src.get_reserved_out(&"grain"), 0, "Source reservation resolved")
	assert_eq(dst.get_reserved_in(&"grain"), 15, "Dest reservation still held during transit")
	
	# Execute delivery
	var deliver_ok: bool = board.execute_delivery(job, dst)
	assert_true(deliver_ok)
	assert_eq(job.status, HaulJob.Status.DELIVERED)
	assert_eq(dst.get_quantity(&"grain"), 15, "Grain delivered to dest")
	assert_eq(dst.get_reserved_in(&"grain"), 0, "Dest reservation resolved")
	assert_eq(dst.get_free_capacity(), 5, "Dest free capacity remains 5")

func test_job_cancellation_release_once() -> void:
	var board: JobBoard = JobBoard.new()
	var src: Inventory = Inventory.new(201, 50)
	var dst: Inventory = Inventory.new(202, 50)
	
	src.add_resource(&"timber", 25, "START_STOCK")
	var job: HaulJob = board.create_job(&"timber", 10, src, dst, 1, 5)
	assert_true(job != null)
	assert_eq(src.get_available_outgoing(&"timber"), 15)
	assert_eq(dst.get_free_capacity(), 40)
	
	# Cancel job before pickup
	board.cancel_job(job, src, dst, "TEST_CANCEL")
	assert_eq(job.status, HaulJob.Status.CANCELLED)
	assert_eq(src.get_available_outgoing(&"timber"), 25, "Source reservation fully restored")
	assert_eq(dst.get_free_capacity(), 50, "Dest capacity reservation fully restored")
	assert_eq(src.get_reserved_out(&"timber"), 0)
	assert_eq(dst.get_reserved_in(&"timber"), 0)
	
	# Calling cancel again should be a no-op (idempotent, no double-release)
	board.cancel_job(job, src, dst, "TEST_CANCEL_AGAIN")
	assert_eq(src.get_available_outgoing(&"timber"), 25)
	assert_eq(dst.get_free_capacity(), 50)

func test_insufficient_stock_or_capacity() -> void:
	var board: JobBoard = JobBoard.new()
	var src: Inventory = Inventory.new(301, 20)
	var dst: Inventory = Inventory.new(302, 5)
	
	src.add_resource(&"stone", 10, "START_STOCK")
	
	# Exceeds destination capacity (demand 10, cap 5)
	var job_overflow: HaulJob = board.create_job(&"stone", 10, src, dst, 1, 1)
	assert_true(job_overflow == null, "Should not create job if dest cannot hold it")
	assert_eq(src.get_reserved_out(&"stone"), 0, "Source must not hold reservation on rejected job")
	
	# Exceeds source available stock
	var dst_big: Inventory = Inventory.new(303, 100)
	var job_lack: HaulJob = board.create_job(&"stone", 50, src, dst_big, 1, 1)
	assert_true(job_lack == null, "Should not create job if source lacks stock")
	assert_eq(dst_big.get_reserved_in(&"stone"), 0)
