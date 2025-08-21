extends Node

# Debug script to test near miss system
# Attach this to any node in your scene and call the test functions

# Export paths so you can assign them in inspector if needed
@export var near_miss_detector: Node
@export var near_miss_manager: Node  
@export var point_manager: Node

func _ready():
	print("=== NEAR MISS DEBUG SCRIPT READY ===")
	
	# Auto-find components if not assigned
	if not near_miss_detector:
		near_miss_detector = find_node_by_script("NearMissDetector")
	if not near_miss_manager:
		near_miss_manager = find_node_by_script("NearMissManager") 
	if not point_manager:
		point_manager = get_tree().get_first_node_in_group("point_manager")
	
	print("Auto-detected components:")
	print("- Near Miss Detector: ", near_miss_detector != null)
	print("- Near Miss Manager: ", near_miss_manager != null)
	print("- Point Manager: ", point_manager != null)

# Helper function to find nodes by script type
func find_node_by_script(script_name: String) -> Node:
	var all_nodes = get_tree().get_nodes_in_group("near_miss_detector") + get_tree().get_nodes_in_group("near_miss_manager")
	for node in get_tree().current_scene.get_children():
		if node.get_script() and node.get_script().get_global_name().contains(script_name):
			return node
	return null

# Call this function to run all tests at once
func run_all_tests():
	print("\n==================================================")
	print("RUNNING ALL NEAR MISS SYSTEM TESTS")
	print("==================================================")
	
	test_1_point_manager_basic()
	await get_tree().create_timer(0.5).timeout
	
	test_2_point_manager_from_detector()
	await get_tree().create_timer(0.5).timeout
	
	test_3_near_miss_manager_basic()
	await get_tree().create_timer(0.5).timeout
	
	test_4_near_miss_manager_to_point_manager()
	await get_tree().create_timer(0.5).timeout
	
	test_5_detector_to_near_miss_manager()
	await get_tree().create_timer(0.5).timeout
	
	test_6_full_chain_simulation()
	
	print("\n==================================================")
	print("ALL TESTS COMPLETE - CHECK OUTPUT ABOVE")
	print("==================================================")

# Test 1: Point Manager Basic Functionality
func test_1_point_manager_basic():
	print("\n--- TEST 1: Point Manager Basic ---")
	
	if not point_manager:
		print("❌ FAIL: No point manager found!")
		return
		
	print("✓ Point manager found: ", point_manager.name)
	
	if point_manager.has_method("add_points"):
		print("✓ Point manager has add_points method")
		var initial_points = point_manager.get_total_points() if point_manager.has_method("get_total_points") else 0
		print("Initial points: ", initial_points)
		
		point_manager.add_points(100, "debug_test")
		
		var final_points = point_manager.get_total_points() if point_manager.has_method("get_total_points") else 0
		print("Final points: ", final_points)
		
		if final_points > initial_points:
			print("✅ SUCCESS: Points increased!")
		else:
			print("❌ FAIL: Points did not increase")
	else:
		print("❌ FAIL: Point manager missing add_points method")

# Test 2: Point Manager Access From Detector
func test_2_point_manager_from_detector():
	print("\n--- TEST 2: Point Manager From Detector ---")
	
	if not near_miss_detector:
		print("❌ FAIL: No near miss detector found!")
		return
		
	print("✓ Near miss detector found: ", near_miss_detector.name)
	
	if near_miss_detector.has_method("test_point_manager_direct"):
		near_miss_detector.test_point_manager_direct()
	else:
		print("❌ FAIL: Detector missing test_point_manager_direct method")

# Test 3: Near Miss Manager Basic
func test_3_near_miss_manager_basic():
	print("\n--- TEST 3: Near Miss Manager Basic ---")
	
	if not near_miss_manager:
		print("❌ FAIL: No near miss manager found!")
		return
		
	print("✓ Near miss manager found: ", near_miss_manager.name)
	
	if near_miss_manager.has_method("register_near_miss"):
		print("✓ Near miss manager has register_near_miss method")
		var fake_data = {
			"speed": 15.0,
			"position": Vector3(0, 0, 0),
			"car_velocity": Vector3(10, 0, 0),
			"object": self
		}
		near_miss_manager.register_near_miss(fake_data)
	else:
		print("❌ FAIL: Near miss manager missing register_near_miss method")

# Test 4: Near Miss Manager to Point Manager Connection
func test_4_near_miss_manager_to_point_manager():
	print("\n--- TEST 4: Near Miss Manager → Point Manager ---")
	
	if not near_miss_manager:
		print("❌ FAIL: No near miss manager found!")
		return
	
	if near_miss_manager.has_method("test_point_manager_connection"):
		near_miss_manager.test_point_manager_connection()
	else:
		print("❌ FAIL: Near miss manager missing test_point_manager_connection method")

# Test 5: Detector to Near Miss Manager Connection  
func test_5_detector_to_near_miss_manager():
	print("\n--- TEST 5: Detector → Near Miss Manager ---")
	
	if not near_miss_detector:
		print("❌ FAIL: No near miss detector found!")
		return
	
	if near_miss_detector.has_method("test_near_miss_manager_direct"):
		near_miss_detector.test_near_miss_manager_direct()
	else:
		print("❌ FAIL: Detector missing test_near_miss_manager_direct method")

# Test 6: Full Chain Simulation
func test_6_full_chain_simulation():
	print("\n--- TEST 6: Full Chain Simulation ---")
	
	if not near_miss_detector:
		print("❌ FAIL: No near miss detector found!")
		return
		
	print("Simulating full near miss detection...")
	
	if near_miss_detector.has_method("test_near_miss"):
		var initial_points = 0
		if point_manager and point_manager.has_method("get_total_points"):
			initial_points = point_manager.get_total_points()
			
		near_miss_detector.test_near_miss()
		
		await get_tree().create_timer(0.1).timeout
		
		if point_manager and point_manager.has_method("get_total_points"):
			var final_points = point_manager.get_total_points()
			if final_points > initial_points:
				print("✅ SUCCESS: Full chain worked! Points went from ", initial_points, " to ", final_points)
			else:
				print("❌ FAIL: Full chain failed - no points added")
	else:
		print("❌ FAIL: Detector missing test_near_miss method")

# Convenience function for quick testing - call this from debug console
func quick_test():
	print("=== QUICK TEST ===")
	test_1_point_manager_basic()

# Manual component assignment functions
func set_detector(detector: Node):
	near_miss_detector = detector
	print("Detector manually set to: ", detector.name if detector else "null")

func set_manager(manager: Node):
	near_miss_manager = manager  
	print("Manager manually set to: ", manager.name if manager else "null")

func set_point_manager(p_manager: Node):
	point_manager = p_manager
	print("Point manager manually set to: ", p_manager.name if p_manager else "null")

# Quick status check
func status():
	print("\n=== SYSTEM STATUS ===")
	print("Near Miss Detector: ", near_miss_detector.name if near_miss_detector else "NOT FOUND")
	print("Near Miss Manager: ", near_miss_manager.name if near_miss_manager else "NOT FOUND") 
	print("Point Manager: ", point_manager.name if point_manager else "NOT FOUND")
	
	if point_manager and point_manager.has_method("get_total_points"):
		print("Current Points: ", point_manager.get_total_points())
	print("===================")
