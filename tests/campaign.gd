extends Node
## Sweeps the real player capsule through all fourteen rooms and watches every
## mandatory memory to completion. No developer teleport opens any exit.
var game: Node
var failures: Array[String] = []
var assertions := 0

func check(ok: bool, caption: String):
	assertions+=1
	print("CAMPAIGN ","PASS: " if ok else "FAIL: ",caption)
	if not ok: failures.append(caption)

func frames(count := 4):
	for i in range(count): await get_tree().physics_frame
	await get_tree().process_frame

func move_to(pos: Vector3, maximum := 600):
	for i in range(maximum):
		if game.busy or game.story_active: break
		var diff: Vector3=pos-game.player.position
		diff.y=0
		if diff.length()<0.04: break
		var step=diff.limit_length(0.055)
		game.player.velocity=step*60.0+Vector3(0,-0.5,0)
		game.player.move_and_slide()
		game.player.velocity=Vector3.ZERO
		if i==maximum-1: print("BLOCKED ",game.stage," at ",game.player.position," target ",pos)
		await get_tree().physics_frame

func aim(at: Vector3):
	var direction: Vector3=(at-game.camera.global_position).normalized()
	game.yaw=atan2(-direction.x,-direction.z)
	game.pitch=asin(direction.y)
	await frames()

func touch(id: String):
	var p: Vector3=game.devices[id].node.position
	await move_to(Vector3(p.x,0.05,p.z+1.75))
	await aim(p+Vector3(0,0.85,0))
	check(game.get_target()==id,"Real camera ray reaches "+id+" in "+game.stage)
	game.interact(game.get_target())
	await frames()

func mark_pair():
	for id in game.extra_level.NAMES[game.extra_level.level-5]:
		var pos: Vector3=game.devices[id].node.position
		await move_to(Vector3(pos.x,0.05,pos.z+1.75))
		await aim(pos+Vector3(0,0.9,0))
		check(game.get_target()==id,"Real camera selects SHIFT endpoint "+id)
		game.select_item(game.get_target())

func wait_stage(which: String, timeout := 8.0):
	var elapsed=0.0
	while game.stage!=which and elapsed<timeout:
		await get_tree().process_frame
		elapsed+=get_process_delta_time()
	check(game.stage==which,"Connected route enters "+which)
	await get_tree().create_timer(1.3).timeout

func run(owner_game: Node):
	game=owner_game
	game.no_chase=false
	# Preserve the established suites for the author's original four solutions.
	if "--from-myths" in OS.get_cmdline_user_args(): game.build_scene("chamber5")
	for script in ([] if "--from-myths" in OS.get_cmdline_user_args() else ["integration","extra_levels"]):
		var suite=load("res://tests/"+script+".gd").new()
		suite.quit_at_end=false
		game.add_child(suite)
		await suite.run(game)
		assertions+=suite.assertions
		failures.append_array(suite.failures)
		suite.queue_free()
	for level in range(5,15):
		if game.stage!="chamber"+str(level):
			check(false,"Cannot continue route at room "+str(level))
			break
		var room=game.extra_level
		check(not game.used_shift and game.states.values().count(true)==1,"Room %d starts with exactly one active state and one SHIFT" % level)
		check(not room.solved,"Room %d cannot be skipped" % level)
		if level==5:
			await mark_pair()
			check(game.perform_shift(),"Unprepared exchange remains an honest state swap")
			check(not room.solved and not game.door_roots.route.open,"Unprepared mirror frame keeps exit closed")
			game.restart_chapter()
			await get_tree().create_timer(1.8).timeout
			room=game.extra_level
			check(not game.used_shift and not room.manual.frame,"Reset restores preparation and SHIFT budget")
		if level==14:
			room.process_blast(20) if room.solved else null
			check(not room.wall_broken,"Unsolved wall cannot be destroyed")
		match level:
			5: await touch("frame")
			6: await touch("screen")
			7: await touch("cargo")
			8: await touch("preview")
			9: await touch("listen")
			10:
				await touch("rack_a")
				await touch("rack_b")
			11:
				await touch("phase")
				if not room.phase_locked:
					while not room.phase_open: await get_tree().physics_frame
					game.interact("phase")
			12: await touch("thread")
			13: await touch("path")
			14: await touch("shelter")
		check(room.prepared(),"Room %d preparation uses its real controls" % level)
		await mark_pair()
		var shifted=game.perform_shift()
		check(shifted,"Room %d accepts exactly one atomic exchange" % level)
		if not shifted: break
		check(game.states.values().count(true)==1,"Room %d conserves binary states" % level)
		check(room.solved and game.used_shift,"Room %d solution is latched" % level)
		check(not game.perform_shift(),"Room %d rejects repeated SHIFT" % level)
		await get_tree().create_timer(1.5).timeout
		if level==13:
			await move_to(Vector3(0,0.05,-8.1))
			await aim(Vector3(0,1.36,-10))
			check(game.get_target()=="pandora_ammo","Open casket exposes the real cartridge ray target")
			game.interact(game.get_target())
			check(game.has_ammo and not game.devices.pandora_ammo.node.visible,"The one cartridge is collected in room 13")
			check(game.get_target()!="pandora_ammo","Collected cartridge leaves no invisible interaction target")
		if level==14:
			await get_tree().create_timer(5.4).timeout
			check(room.wall_broken and game.narrative.flags.get("wallBroken",false),"Timed overload destroys the wall")
			check(room.wall_shapes.all(func(shape): return shape.disabled),"Destroyed wall has no remaining collision")
			await move_to(Vector3(0,0.05,-25.4))
			await wait_stage("finale",8)
			await get_tree().create_timer(13.5).timeout
			check(game.ui.credit_panel.visible,"Complete campaign reaches credits")
			check(game.narrative.flags.get("endingCompleted",false),"Ending commits completed story")
			var barrel: Vector3=-game.gun.get_node("Barrel").global_transform.basis.z.normalized()
			check(barrel.y>0.6,"Autonomous final action points into the sky")
			break
		if level==13:
			await move_to(Vector3(-1.7,0.05,-8.0))
			await move_to(Vector3(-1.7,0.05,-12))
		# Follow the actual walkway; the mirror frame needs a physical side step.
		if level==5:
			await move_to(Vector3(-1.5,0.05,-6.5))
			await move_to(Vector3(-1.5,0.05,-11))
		await move_to(Vector3(0,0.05,-11 if level==5 else -12 if level==13 else -9.5))
		await move_to(Vector3(0,0.05,-15.6))
		check(game.player.position.z<-15.4 and game.player.position.y>-.1,"Room %d capsule crosses real prepared geometry at %s" % [level,game.player.position])
		await move_to(Vector3(0,0.05,-16.25))
		await frames()
		check(game.story_active,"Room %d required memory starts on the main path" % level)
		if level==13:
			check(game.audio.music_player.stream_paused,"Second reveal stops the music immediately")
			game.paused=true
			var silence: float=game.audio._music_silence
			await get_tree().create_timer(.3).timeout
			check(game.audio._music_silence==silence,"Pause freezes the dramatic music break")
			game.paused=false
		if level==5 and game.story_active:
			game.paused=true
			var timer: float=game.narrative.remaining
			await get_tree().create_timer(.3).timeout
			check(game.narrative.remaining==timer,"Pause freezes the mandatory memory timer")
			game.paused=false
		var elapsed=0.0
		while game.story_active and elapsed<25:
			await get_tree().process_frame
			elapsed+=get_process_delta_time()
		check(room.beat_done and game.narrative.flags.get(room.BEAT_IDS[level-5],false),"Room %d mandatory story finishes without secrets" % level)
		if level==13: check(not game.audio.music_player.stream_paused and game.audio._music_return>0.99,"Music returns smoothly after the temporary silence")
		if level==13:
			room.chase_delay=0
			room.second.position=game.player.position+Vector3(0,0,.3)
			await frames()
			check(room.caught and game.has_ammo and game.used_shift,"Second contact softly recovers without losing item or solution")
		await move_to(Vector3(-2.4,0.05,-16.2))
		await move_to(Vector3(-2.4,0.05,-20))
		await move_to(Vector3(0,0.05,-20.3))
		await move_to(Vector3(0,0.05,-24))
		await wait_stage("chamber"+str(level+1))
	check(game.narrative.secrets.is_empty(),"All required story and ending work with zero secrets")
	for flag in ["sisterIntroduced","shiftOriginKnown","promiseHeard","lossConfirmed","regretHeard","secondRevealed","wallBroken","endingCompleted"]:
		check(game.narrative.flags.get(flag,false),"Final story flag: "+flag)
	# Regression: resetting after the cartridge but before its memory must replay
	# the revelation, rather than leave an open room with an unreachable story gate.
	game.narrative.flags.erase("secondRevealed")
	game.has_ammo=true
	game.build_scene("chamber13")
	await frames()
	check(game.used_shift and game.extra_level.solved and game.door_roots.route.open,"Pandora resume preserves opened casket and item")
	check(not game.extra_level.beat_started and not game.extra_level.beat_done,"Interrupted Pandora revelation is scheduled again")
	var room=game.extra_level
	room.beat_done=true
	room.chase=true
	room.chase_delay=0
	room.second.show()
	room.second.position=Vector3(0,0,-2)
	game.no_chase=true
	var before: Vector3=room.second.position
	room.process_chase(1)
	check(room.second.position==before,"No-chase setting freezes threat without altering the puzzle")
	game.no_chase=false
	game.build_scene("prologue")
	await frames()
	await aim(Vector3(.65,.12,4.4))
	check(game.get_target()=="ground_ammo","The nearby prologue cartridge has its own reachable ray target")
	game.reduced_flashes=true
	game.ui.flash.color.a=0
	game.ui.shift_flash()
	check(game.ui.flash.color.a==0,"Reduced-flash setting suppresses SHIFT flash")
	game.reduced_flashes=false
	game.ui.mountain_memory.show()
	game.toggle_pause()
	check(game.ui.pause_panel.visible and game.ui.pause_panel.get_index()>game.ui.mountain_memory.get_index(),"Pause menu stays above the mountain-memory overlay")
	game.toggle_pause()
	game.ui.mountain_memory.hide()
	print("SHIFT FULL CAMPAIGN: ",assertions," checks, ",failures.size()," failures")
	for failure in failures: print("CAMPAIGN FAILED: ",failure)
	await game.quit_game(0 if failures.is_empty() else 1)
