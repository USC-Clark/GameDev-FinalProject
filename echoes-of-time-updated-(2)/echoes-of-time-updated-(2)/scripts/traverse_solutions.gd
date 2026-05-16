extends RefCounted

# Admin-only solutions for Traverse levels.
# Easy to remove later: delete this file + the Solve button + related code in `traverse_manager.gd`.


static func get_solution(level_number: int) -> Array[Dictionary]:
	# IMPORTANT:
	# - This returns action-frames compatible with `echo.gd`/`player.gd` recording format.
	# - For now, this is a placeholder framework; you can fill per-level solutions as you design.
	match level_number:
		1: return _solution_level_1()
		2: return _solution_level_2()
		3: return _solution_level_3()
		4: return _solution_level_4()
		5: return _solution_level_5()
		6: return _solution_level_6()
		7: return _solution_level_7()
		8: return _solution_level_8()
		9: return _solution_level_9()
		10: return _solution_level_10()
		_:
			return []


static func _solution_level_1() -> Array[Dictionary]:
	# A very rough baseline path (will likely need tuning after you finalize level geometry).
	var frames: Array[Dictionary] = []
	# Walk right toward the ledge/button area.
	for _i in range(10):
		frames.append({"left_pressed": false, "right_pressed": true, "jump_pressed": false, "down_pressed": false})
	# Jump up once.
	frames.append({"left_pressed": false, "right_pressed": false, "jump_pressed": true, "down_pressed": false})
	# A few more right steps.
	for _i in range(3):
		frames.append({"left_pressed": false, "right_pressed": true, "jump_pressed": false, "down_pressed": false})
	# Wait (no-op frames).
	for _i in range(3):
		frames.append({"left_pressed": false, "right_pressed": false, "jump_pressed": false, "down_pressed": false})
	return frames


static func _r(steps: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for _i in range(steps):
		frames.append({"left_pressed": false, "right_pressed": true, "jump_pressed": false, "down_pressed": false})
	return frames


static func _l(steps: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for _i in range(steps):
		frames.append({"left_pressed": true, "right_pressed": false, "jump_pressed": false, "down_pressed": false})
	return frames


static func _wait(steps: int) -> Array[Dictionary]:
	var frames: Array[Dictionary] = []
	for _i in range(steps):
		frames.append({"left_pressed": false, "right_pressed": false, "jump_pressed": false, "down_pressed": false})
	return frames


static func _j() -> Dictionary:
	return {"left_pressed": false, "right_pressed": false, "jump_pressed": true, "down_pressed": false}


static func _solution_level_2() -> Array[Dictionary]:
	# Step on B1 (left side now), wait to keep it pressed.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(2))
	frames.append_array(_wait(10))
	return frames


static func _solution_level_3() -> Array[Dictionary]:
	# Step on B1 to raise the lift (now on ground), wait.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(2))
	frames.append_array(_wait(12))
	return frames


static func _solution_level_4() -> Array[Dictionary]:
	# Press B1 (left) and idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(3))
	frames.append_array(_wait(10))
	return frames


static func _solution_level_5() -> Array[Dictionary]:
	# Press B1 to enable bridge, idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(2))
	frames.append_array(_wait(14))
	return frames


static func _solution_level_6() -> Array[Dictionary]:
	# Press B1, idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(3))
	frames.append_array(_wait(16))
	return frames


static func _solution_level_7() -> Array[Dictionary]:
	# Press B1, idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(2))
	frames.append_array(_wait(12))
	return frames


static func _solution_level_8() -> Array[Dictionary]:
	# Press B1, idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(4))
	frames.append_array(_wait(12))
	return frames


static func _solution_level_9() -> Array[Dictionary]:
	# Press B1 (left), idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(3))
	frames.append_array(_wait(12))
	return frames


static func _solution_level_10() -> Array[Dictionary]:
	# Press B1, idle.
	var frames: Array[Dictionary] = []
	frames.append_array(_r(3))
	frames.append_array(_wait(20))
	return frames
