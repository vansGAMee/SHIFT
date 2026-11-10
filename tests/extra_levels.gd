extends Node

# Actual-scene regression for the two later SHIFT chambers.
# Run via main with -- --extra-test; automation never writes the player's save.
var game: Node
var failures: Array[String] = []
var assertions := 0
var quit_at_end := true

func check(condition: bool, description: String):
	assertions += 1
	if condition:
		print("EXTRA PASS: ",description)
	else:
		failures.append(description)
		push_error("EXTRA FAIL: "+description)

func frames(count: int = 3):
	for i in range(count):
		await get_tree().physics_frame
	await get_tree().process_frame
	await get_tree().physics_frame

func place(position: Vector3):
	game.player.position = position
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	await frames(4)

func aim(position: Vector3):
	var direction: Vector3 = (position-game.camera.global_position).normalized()
	game.yaw = atan2(-direction.x,-direction.z)
	game.pitch = asin(direction.y)
	game.player.rotation.y = game.yaw
	game.camera.rotation = Vector3(game.pitch,game.yaw,0)
	await frames(2)

func target_at(position: Vector3, expected: String, description: String):
	await aim(position)
	var actual: String = game.get_target()
	check(actual==expected,description+" (target="+actual+")")

func swap_pair(first: String, second: String) -> bool:
	game.selected.clear()
	game.select_item(first)
	game.select_item(second)
	return game.perform_shift()

func ray(start: Vector3, finish: Vector3, mask: int = 1) -> Dictionary:
	var query := PhysicsRayQueryParameters3D.create(start,finish,mask)
	return game.camera.get_world_3d().direct_space_state.intersect_ray(query)

func move_to(position: Vector3, maximum_frames: int = 300):
	for i in range(maximum_frames):
		var displacement: Vector3 = position-game.player.position
		displacement.y = 0
		if displacement.length()<0.025: break
		game.player.move_and_collide(displacement.limit_length(0.08))
		await get_tree().physics_frame

func wait_for_stage(expected: String, timeout: float = 8.0):
	var elapsed := 0.0
	while game.stage!=expected and elapsed<timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	check(game.stage==expected,"Connected flow reaches "+expected)
	await frames(4)

func find_marker(parent: Node, id: String) -> Node3D:
	for child in parent.get_children():
		if child is Node3D and child.has_meta("item") and child.get_meta("item")==id:
			return child
		var nested: Node3D = find_marker(child,id)
		if nested: return nested
	return null

func touch(id: String):
	var marker := find_marker(game.world,id)
	if not marker:
		check(false,"Scene contains selectable "+id)
		return
	var point := marker.global_position
	var approach := Vector3(point.x,0.05,point.z+1.8)
	if id.begins_with("valve_") or id=="archive_cell":
		# Valve recesses are entered from the central aisle, between their real walls.
		approach = Vector3(point.x-signf(point.x)*1.7,0.05,point.z)
	await place(approach)
	await target_at(point,id,"Real ray reaches "+id)
	game.interact(id)
	await frames(2)

func prepare_archive():
	for id in ["relay_a","relay_c","relay_d"]:
		await touch(id)
	await touch("archive_cell")

func approach_archive_door():
	# The large cabinet is solid; this uses its actual left-hand service passage.
	await place(Vector3(-6.1,0.05,-16.7))
	await move_to(Vector3(-6.1,0.05,-20.0))
	check(game.player.position.z<-19.8,"Capsule can walk around the archive cabinet")
	await move_to(Vector3(0,0.05,-22.0))
	await target_at(Vector3(0,1.7,-23.75),"archive_door","Archive exit socket is visible beyond the cabinet")

func mark_pressure_pair():
	await place(Vector3(0,0.05,-22.2))
	game.selected.clear()
	await target_at(Vector3(-2,0.85,-24),"ventilator","Exit relay selects the same ventilator state")
	game.select_item(game.get_target())
	await target_at(Vector3(2,0.85,-24),"release","Exit drive is a separate real SHIFT endpoint")
	game.select_item(game.get_target())

func run(owner_game: Node):
	game = owner_game
	game.automating = true
	game.has_ammo = false
	game.loaded_round = false
	game.build_scene("chamber3")
	game.ui.fade.color.a = 0
	await frames(4)
	print("SHIFT EXTRA INTEGRATION START")
	check(game.extra_level!=null and game.extra_level.level==3,"Third room builds its own module")
	check(game.states=={"archive_cell":false,"archive_door":false},"Archive begins with two inactive electrical endpoints")
	check(game.extra_level.sensors()==[true,true,true,false,true,false],"Six archive lamps begin in the documented binary pattern")
	check(not game.extra_level.balanced(),"Initial archive configuration cannot supply charge")
	check(not game.door_roots.archive_door.shape.disabled,"Archive exit initially has real closed-door collision")
	await touch("archive_cell")
	check(not game.states.archive_cell,"Unbalanced relay bank rejects physical charging")
	check(not swap_pair("archive_cell","archive_door"),"Equal-state archive exchange is rejected")
	check(not game.used_shift,"Rejected archive exchange preserves its one charge")
	game.selected.clear()
	game.select_item("relay_a")
	check(game.selected.is_empty(),"Brass mechanical controls are distinct from SHIFT sockets")
	await touch("relay_a")
	check(game.extra_level.sensors()==[false,false,true,false,true,false],"Relay A flips exactly sensors one and two")
	await touch("archive_cell")
	check(not game.states.archive_cell,"Partly solved archive still rejects charge")
	await touch("relay_c")
	check(game.extra_level.sensors()==[false,false,false,true,true,false],"Relay C flips exactly sensors three and four")
	await touch("relay_d")
	check(game.extra_level.balanced(),"A,C,D preparation darkens all six lamps")
	check(game.extra_level.relay_bits==[true,false,true,true,false],"Archive reaches the independently proven unique configuration")
	await touch("archive_cell")
	check(game.states.archive_cell and not game.states.archive_door,"Balanced bank physically charges only the source")
	game.selected.clear()
	game.select_item("archive_cell")
	await approach_archive_door()
	game.select_item(game.get_target())
	check(game.perform_shift(),"Archive uses its single prepared source-to-exit SHIFT")
	await get_tree().create_timer(1.5).timeout
	check(not game.states.archive_cell and game.states.archive_door and game.used_shift,"Archive swap conserves the active state and consumes once")
	check(game.door_roots.archive_door.shape.disabled,"Balanced powered archive exit physically opens")
	await touch("relay_a")
	check(game.extra_level.relay_bits==[true,false,true,true,false],"Completed transfer latches the solved mechanical bank")
	check(not game.perform_shift(),"Archive rejects a second SHIFT")
	game.restart_chapter()
	await get_tree().create_timer(1.8).timeout
	check(game.stage=="chamber3" and not game.busy,"R reset returns a playable archive room")
	check(not game.used_shift and game.extra_level.relay_bits==[false,false,false,false,false],"Archive reset restores levers and the one-use SHIFT budget")
	await prepare_archive()
	game.selected.clear()
	game.select_item("archive_cell")
	await approach_archive_door()
	game.select_item(game.get_target())
	check(game.perform_shift(),"Archive remains solvable after reset")
	await get_tree().create_timer(1.5).timeout
	await move_to(Vector3(0,0.05,-25.0))
	await wait_for_stage("chamber4",6.0)
	await get_tree().create_timer(1.2).timeout
	check(game.checkpoint=="chamber4" and not game.has_ammo,"Archive connects to fourth room before Pandora cartridge")
	check(not game.devices.has("ammo"),"Room four contains no leftover demo cartridge")
	check(game.extra_level.level==4,"Fourth room builds the pressure module")
	check(game.states=={"ventilator":true,"release":false},"Pressure room starts with ventilation holding the active state")
	check(game.extra_level.valves==[false,true,true,true],"Four diverters start in the documented closed loop")
	check(game.extra_level.route()=="loop","Initial pipe graph actually loops")
	check(game.extra_level.in_hot_zone(Vector3(0,0,-8)),"Central grates are the environmental hazard zone")
	check(not game.extra_level.in_hot_zone(Vector3(5,0,-8)),"Recesses at the room sides are outside the hazard zone")
	await touch("lock")
	check(not game.lock_open,"Final lock requires power and a safe pressure route")

	# A mistaken early transfer remains recoverable; pressure has a long visible lead-in.
	await mark_pressure_pair()
	check(game.perform_shift(),"Pressure exchange is possible before the valves are prepared")
	check(not game.states.ventilator and game.states.release,"Pressure exchange moves exactly one active state")
	await place(Vector3(0,0.05,-8))
	var early_position: Vector3 = game.player.position
	await get_tree().create_timer(0.8).timeout
	check(game.player.position.distance_to(early_position)<0.1,"Wrong pressure route grants an initial warning grace")
	check(game.extra_level.exposure==0,"Warning grace causes no heat exposure")
	await place(Vector3(5,0.05,-9))
	game.extra_level.hazard_clock = 10.0
	await get_tree().create_timer(2.5).timeout
	check(game.player.position.x>4.2 and game.extra_level.exposure==0,"A physical side recess stays safe during an active pressure pulse")
	await place(Vector3(0,0.05,-8))
	game.extra_level.hazard_clock = 10.0
	game.extra_level.exposure = 0.0
	await get_tree().create_timer(2.5).timeout
	check(absf(game.player.position.x)>=4.2,"Sustained hot-floor exposure makes the character retreat to a refuge")
	check(game.stage=="chamber4" and game.used_shift,"Environmental retreat preserves room and spent SHIFT state")
	await get_tree().create_timer(1.1).timeout
	game.restart_chapter()
	await get_tree().create_timer(1.8).timeout
	check(game.stage=="chamber4" and not game.busy,"Pressure room can be reset after a mistimed transfer")
	check(game.states.ventilator and not game.states.release and not game.used_shift,"Pressure reset restores ventilation and one SHIFT")

	# The correct directed route is A→C→B→D→tank; every valve differs from its initial bit.
	for id in ["valve_a","valve_b","valve_c","valve_d"]:
		await touch(id)
	check(game.extra_level.valves==[true,false,false,false],"All four diverters reach the independently proven unique safe configuration")
	check(game.extra_level.route()=="cooled" and game.extra_level.current_route=="cooled","Actual pipe graph passes cooler C before ending in the tank")
	check(game.extra_level.route_path()=="A → C → B → D → БАК","Rendered route feedback matches the physical diagram")
	await mark_pressure_pair()
	check(game.perform_shift(),"Prepared pressure circuit accepts its single SHIFT")
	check(not game.states.ventilator and game.states.release and game.used_shift,"Safe transfer turns ventilation off while powering the exit drive")
	await place(Vector3(0,0.05,-8))
	game.extra_level.hazard_clock = 10.0
	await get_tree().create_timer(2.5).timeout
	check(absf(game.player.position.x)<0.2 and game.extra_level.exposure==0,"Correct cooling makes the same central floor safe with ventilation off")
	await touch("lock")
	await get_tree().create_timer(0.65).timeout
	check(game.lock_open,"Prepared final circuit permits the story lock interaction")
	await get_tree().create_timer(1.4).timeout
	check(game.door_roots.exit.shape.disabled,"Fourth-room final door physically opens")
	await place(Vector3(0,0.05,-26.8))
	await move_to(Vector3(0,0.05,-29.2))
	check(game.player.position.z<-29.0 and game.player.position.y>-.1,"Real capsule enters the final black passage on solid floor")
	await move_to(Vector3(0,0.05,-30.2))
	await wait_for_stage("chamber5",7.0)
	await get_tree().create_timer(1.2).timeout
	check(game.stage=="chamber5" and game.extra_level.level==5,"Fourth author room connects to the ten-myth campaign")
	check(not game.busy,"Campaign transition releases control")
	print("SHIFT EXTRA INTEGRATION: ",assertions," checks, ",failures.size()," failures")
	for failure in failures: print("EXTRA FAILED: ",failure)
	if quit_at_end: await game.quit_game(0 if failures.is_empty() else 1)
