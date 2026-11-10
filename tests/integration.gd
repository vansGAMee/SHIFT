extends Node

# Exercises the actual Godot scene, state machine, ray queries and collision shapes.
# Run: godot --headless --path . -- --test
var game: Node
var failures: Array[String] = []
var assertions := 0
var quit_at_end := true

func check(condition: bool, description: String):
	assertions += 1
	if condition:
		print("PASS: ",description)
	else:
		failures.append(description)
		push_error("FAIL: "+description)

func frames(count: int = 3):
	for i in range(count):
		await get_tree().physics_frame
	# Slow machines can run multiple physics catch-up ticks before the next _process.
	await get_tree().process_frame
	await get_tree().physics_frame

func place(pos: Vector3):
	game.player.position = pos
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	await frames(4)

func aim(point: Vector3):
	var direction: Vector3 = (point-game.camera.global_position).normalized()
	game.yaw = atan2(-direction.x,-direction.z)
	game.pitch = asin(direction.y)
	game.player.rotation.y = game.yaw
	# The camera is top_level and no longer inherits player yaw.
	game.camera.rotation = Vector3(game.pitch,game.yaw,0)
	await frames(2)

func target_at(point: Vector3, expected: String, description: String):
	await aim(point)
	var actual: String = game.get_target()
	if actual != expected:
		var forward: Vector3 = -game.camera.global_transform.basis.z
		var query := PhysicsRayQueryParameters3D.create(game.camera.global_position,game.camera.global_position+forward*24,3)
		var hit: Dictionary = game.camera.get_world_3d().direct_space_state.intersect_ray(query)
		print("RAY DIAGNOSTIC stage=",game.stage," busy=",game.busy," player=",game.player.global_position," camera=",game.camera.global_position," forward=",forward," point=",point," hit=",hit)
	check(actual==expected,description+" (target="+actual+")")

func move_to_z(destination: float, seconds: float = 1.5):
	# Sweep the real capsule in small physical increments, never teleport through geometry.
	var count := maxi(1,int(seconds*60.0))
	for i in range(count):
		var remaining: float = destination-game.player.position.z
		if absf(remaining)<0.025: break
		game.player.move_and_collide(Vector3(0,0,clampf(remaining,-0.08,0.08)))
		await get_tree().physics_frame

func wait_for_stage(expected: String, timeout: float = 8.0):
	var elapsed := 0.0
	while game.stage != expected and elapsed<timeout:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
	check(game.stage==expected,"Scene transition reaches "+expected)
	await frames(5)

func run(owner_game: Node):
	game = owner_game
	game.automating = true
	game.ui.fade.color.a = 0
	print("SHIFT INTEGRATION TESTS START")
	check(game.stage=="menu","Initial scene is menu")
	check(game.ui.menu.visible,"Menu is visible")

	# The prologue is a live 3D scene. Looking/inspection never points the rifle at the player.
	game.build_scene("prologue")
	await frames()
	var original_position: Vector3 = game.player.position
	game._physics_process(1.0)
	check(game.player.position.is_equal_approx(original_position),"Prologue has fixed lying position")
	check(not game.has_rifle,"Prologue starts with empty hands")
	check(is_instance_valid(game.ground_rifle) and game.ground_rifle.visible,"Rifle is a separate 3D object on nearby grass")
	check(not game.gun_pivot.visible,"Held rifle is hidden before pickup")
	check(not game.ground_rifle.get_node("ReloadHand").visible and not game.ground_rifle.get_node("LeftHand").visible,"Ground rifle has no visible floating hands")
	await target_at(game.ground_rifle.global_position,"rifle","Ground rifle is reachable by a real camera ray")
	game.target = game.get_target()
	var pickup_key := InputEventKey.new()
	pickup_key.physical_keycode = KEY_E
	pickup_key.pressed = true
	game.automating = false
	game._unhandled_input(pickup_key)
	game.automating = true
	await frames(3)
	check(game.has_rifle,"E picks up the rifle from the grass")
	check(not is_instance_valid(game.ground_rifle) or not game.ground_rifle.visible,"Picked ground rifle disappears")
	check(game.gun_pivot.visible,"Held rifle becomes visible after pickup")
	await get_tree().create_timer(0.95).timeout
	check(not game.reload_busy,"Pickup animation completes before inspection input")
	game.inspection = true
	game.inspect_rotation = Vector2(0.3,-0.3)
	await get_tree().create_timer(0.2).timeout
	check(game.inspected>0,"Rifle inspection animates in real time")
	check(game.gun_pivot.rotation.x>-0.7,"Prologue inspection stays in safe viewing range")
	var inspect_key := InputEventKey.new()
	inspect_key.physical_keycode = KEY_F
	inspect_key.pressed = true
	game.automating = false
	game._unhandled_input(inspect_key)
	game.automating = true
	check(not game.inspection,"F physically exits rifle inspection")
	game.automating = false
	game._unhandled_input(inspect_key)
	game.automating = true
	check(game.inspection,"F physically re-enters rifle inspection")
	check(game.gun.has_node("Bolt") and game.gun.has_node("ReloadHand") and game.gun.has_node("Barrel"),"Rifle exposes animated bolt, hand and actual muzzle marker")
	check(not game.has_ammo,"Prologue cartridge is a visible story echo, not a loading minigame")
	game.scene_time = 9.0
	game.interact("")
	await wait_for_stage("chamber1",6.0)
	await get_tree().create_timer(1.2).timeout
	check(not game.busy,"Prologue transition releases input")

	# Chapter 1: E changes only the physical source; equal-state swap is rejected for free.
	check(game.states=={"source":false,"door":false},"First chamber starts with both devices off")
	await place(Vector3(-3,0.05,-2.9))
	await target_at(Vector3(-3,1.1,-5),"source","Source is reachable by real camera ray")
	game.select_item("source")
	game.select_item("door")
	check(not game.perform_shift(),"Equal-state exchange is rejected")
	check(not game.used_shift,"Rejected exchange preserves the one SHIFT charge")
	game.interact("source")
	check(game.states.source,"Nearby physical lever charges source")
	check(game.perform_shift(),"Opposite-state source/door pair exchanges")
	check(not game.states.source and game.states.door,"First exchange atomically moves the active state to door")
	check(game.used_shift,"Successful exchange consumes exactly one charge")
	await frames(3)
	check(game.door_roots.door.shape.disabled,"Open door collision is disabled")
	game.interact("source")
	check(not game.states.source,"Source cannot create new charge after completed exchange")
	game.select_item("source")
	check(game.selected.is_empty(),"Spent chamber rejects further selection")
	await place(Vector3(0,0.05,-13.0))
	await target_at(Vector3(0,1.6,-14.60),"door","Door retains a visible target after opening")
	await move_to_z(-14.4,0.6)
	await wait_for_stage("chamber2",5.0)
	await get_tree().create_timer(1.2).timeout

	# Chapter 2: wrong timing really blocks the physical route, then reset restores it.
	check(game.states.generator and not game.states.bridge,"Second chamber starts generator on / bridge off")
	check(game.door_roots.gate.open,"Generator powers the real shutter")
	await place(Vector3(-5,0.05,-3.1))
	await target_at(Vector3(-5,1.0,-5),"generator","Main generator is camera-selectable")
	game.select_item("generator")
	game.select_item("bridge")
	check(game.perform_shift(),"Early second-room exchange is legal but mistimed")
	await get_tree().create_timer(1.8).timeout
	check(not game.door_roots.gate.shape.disabled,"Early exchange restores shutter collision")
	await place(Vector3(0,0.05,-9.1))
	await move_to_z(-10.6,0.5)
	check(game.player.position.z>-9.6,"Closed shutter physically prevents crossing")
	game.restart_chapter()
	await get_tree().create_timer(1.7).timeout
	check(game.stage=="chamber2" and not game.busy,"Reset returns to playable second chamber")
	check(game.states.generator and not game.states.bridge and not game.used_shift,"Reset restores both states and SHIFT charge")

	# There is no floor in the pit before the bridge is raised.
	await frames()
	var pit_query := PhysicsRayQueryParameters3D.create(Vector3(0,0.5,-13),Vector3(0,-1.0,-13),1)
	var pit_hit: Dictionary = game.camera.get_world_3d().direct_space_state.intersect_ray(pit_query)
	check(pit_hit.is_empty(),"Unraised bridge leaves a real physical pit")
	await place(Vector3(0,0.05,-9.0))
	await move_to_z(-10.5,0.7)
	check(game.player.position.z<-10.4 and game.player.position.y>-.1,"Open shutter admits player onto narrow landing")
	await target_at(Vector3(-1.25,1.1,-10.52),"generator","Landing relay resolves to the SAME generator state")
	game.select_item(game.get_target())
	await target_at(Vector3(1.25,1.1,-10.52),"bridge","Bridge console is selectable from landing")
	game.select_item(game.get_target())
	check(game.selected.size()==2,"Landing provides both distinct SHIFT endpoints")
	check(game.perform_shift(),"Generator/bridge exchange works from landing")
	await get_tree().create_timer(1.85).timeout
	check(not game.states.generator and game.states.bridge,"Second-room output states are consistent")
	check(not game.door_roots.gate.shape.disabled,"Shutter closes behind the player")
	check(not game.bridge_shape.disabled,"Raised bridge has active collision")
	check(absf(game.bridge.position.y+0.12)<.01,"Bridge animation reaches the walkable floor height")
	var bridge_hit: Dictionary = game.camera.get_world_3d().direct_space_state.intersect_ray(pit_query)
	check(not bridge_hit.is_empty(),"Previously empty pit now has a physical bridge surface")
	await move_to_z(-16.2,1.6)
	check(game.player.position.z<-16.0,"Real capsule walks across complete bridge to far bank")
	check(game.player.position.y>-.1,"Crossing bridge does not fall or invoke recovery")

	# The original buttstock interaction remains; the one cartridge belongs in room 13.
	check(not game.has_ammo,"Rooms one and two do not award the Pandora cartridge")
	await place(Vector3(-2.3,0.05,-16.3))
	check(game.devices.memory_book.node.name=="ChildhoodBook","Book interaction owns the book model, not a console")
	await target_at(Vector3(-2.3,1.7,-18.0),"","Space above the book is not a phantom console target")
	await target_at(Vector3(-2.3,1.09,-18.0),"memory_book","Visible childhood book is camera-selectable")
	game.interact("memory_book")
	game.inspection = false
	await place(Vector3(1.75,0.05,-20.3))
	game.interact("lock")
	await get_tree().create_timer(0.6).timeout
	check(game.lock_open,"Original buttstock interaction breaks the old lock")
	check(not game.busy,"Lock animation releases control")
	await get_tree().create_timer(1.4).timeout
	check(game.door_roots.exit.shape.disabled,"Final door collision opens")
	await place(Vector3(0,0.05,-22.0))
	await move_to_z(-24.3,1.0)
	check(game.player.position.z<-24.1 and game.player.position.y>-.1,"Player walks into black corridor on solid floor")
	await move_to_z(-25.1,0.5)
	await wait_for_stage("chamber3",7.0)
	await get_tree().create_timer(1.2).timeout
	check(game.checkpoint=="chamber3","Second chamber connects to the new third-room checkpoint")
	check(not game.has_ammo,"Cartridge is reserved for room 13")
	check(not game.busy,"Third chamber releases player input after transition")

	print("SHIFT INTEGRATION: ",assertions," checks, ",failures.size()," failures")
	for failure in failures:
		print("FAILED: ",failure)
	if quit_at_end: await game.quit_game(0 if failures.is_empty() else 1)
