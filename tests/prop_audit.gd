extends Node
## Exercise the actual physics ray at every device in every room, including secrets.
var game: Node
var assertions := 0
var failures: Array[String] = []

func check(ok: bool, description: String):
	assertions += 1
	if not ok: failures.append(description); print("PROP FAIL: ",description)

func aim_from(point: Vector3, offset: Vector3):
	game.player.position=Vector3(point.x+offset.x,0.05,point.z+offset.z)
	game.player.reset_physics_interpolation()
	game.camera.global_position=Vector3(point.x+offset.x,1.69,point.z+offset.z)
	game.camera.look_at(point)
	await get_tree().physics_frame
	await get_tree().process_frame

func run(owner_game: Node):
	game=owner_game
	game.automating=true
	game.ui.hide()
	for level in range(1,15):
		game.build_scene("chamber"+str(level))
		game.paused=true
		await get_tree().physics_frame
		await get_tree().physics_frame
		for id in game.devices:
			var item: Dictionary=game.devices[id]
			var point: Vector3=item.node.global_position+item.get("focus",Vector3(0,0.85,0))
			if id=="memory_book": point=item.node.global_position+Vector3(0,0.05,0)
			var expected="generator" if id=="relay" else "ventilator" if id=="ventilator_relay" else id
			if not item.node.visible:
				await aim_from(point,Vector3(0,0,1.4))
				check(game.get_target()!=expected,"Hidden "+id+" has no active prompt")
				continue
			var reachable=false
			for offset in [Vector3(0,0,1.4),Vector3(1.4,0,0.3),Vector3(-1.4,0,0.3)]:
				await aim_from(point,offset)
				if game.get_target()==expected: reachable=true; break
			check(reachable,"Room %d visible %s is reachable at its model" % [level,id])
			if id=="secret":
				check(item.node.name=="MemoryObject"+str(level),"Secret has its own story model in room "+str(level))
				check(game.extra_level.prompt_for(id).begins_with(item.title),"Secret caption names its visible object in room "+str(level))
				game.paused=false
				game.interact(game.get_target())
				check(game.narrative.secrets.get(str(level),false),"Visible secret can actually be examined in room "+str(level))
				check(game.ui.message.text.begins_with(game.extra_level.SECRETS[level-5]),"Examination shows this object's story in room "+str(level))
				game.paused=true
				if "--capture-props" in OS.get_cmdline_user_args():
					game.ui.fade.color.a=0
					await RenderingServer.frame_post_draw
					game.get_viewport().get_texture().get_image().save_png("res://builds/prop-"+str(level)+".png")
		if level<13: check(not game.devices.has("ammo"),"No early collectible round in room "+str(level))
	print("SHIFT PROP AUDIT: ",assertions," checks, ",failures.size()," failures")
	await game.quit_game(0 if failures.is_empty() else 1)
