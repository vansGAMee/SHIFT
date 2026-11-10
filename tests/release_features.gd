extends Node
var game: Node
var assertions := 0
var failures: Array[String]=[]

func check(ok: bool, text: String):
	assertions+=1
	if not ok: failures.append(text); print("RELEASE FAIL: ",text)

func frames():
	await get_tree().process_frame
	await get_tree().process_frame

func run(owner_game: Node):
	game=owner_game
	var cyrillic=RegEx.new()
	cyrillic.compile("[А-Яа-яЁё]")
	check(game.language=="en","Fresh default language is English")
	for label in game.localizer.labels:
		if label is OptionButton:
			for i in range(label.item_count):
				if label.get_item_text(i)=="Русский": continue
				check(cyrillic.search(label.get_item_text(i))==null,"English dropdown option: "+label.get_item_text(i))
	for source in game.localizer.catalog:
		if source in ["Русский","Language / Язык"]: continue
		check(cyrillic.search(game.localizer.translate(source))==null,"Catalog translation complete: "+source)
	for level in range(1,15):
		game.build_scene("chamber"+str(level))
		await frames()
		for label in game.localizer.labels:
			if not is_instance_valid(label): continue
			if label.text in ["Русский","Language / Язык"]: continue
			check(cyrillic.search(label.text)==null,"English room %d label: %s" % [level,label.text])
	game.build_scene("menu")
	game.set_language("ru")
	check(game.ui.menu_new.text=="Начать с горы","Language switch immediately restores Russian menu")
	game.set_language("en")
	check(game.ui.menu_new.text=="Start at the mountain","Language switch immediately restores English menu")
	game.audio.reset_journey_music()
	game.build_scene("chamber4")
	check(game.audio._personal_kind=="chapter4","Room four selects the author's first track")
	check(not game.audio.personal_player.stream.loop,"Room four track never loops")
	check(game.audio._personal_gain<0.1,"Room four track is quiet")
	var stream=game.audio.personal_player.stream
	game.build_scene("chamber4")
	check(game.audio.personal_player.stream==stream,"Restarting a room does not restart its track")
	game.paused=true
	game.audio._process(0.1)
	check(game.audio.personal_player.stream_paused,"Pause freezes the author's track")
	game.paused=false
	game.audio.streamer_mode=true
	game.audio._process(0.1)
	check(game.audio.personal_player.volume_db<=-79,"Streamer mode mutes author tracks")
	game.audio.streamer_mode=false
	game.build_scene("finale")
	check(game.audio._personal_kind=="finale","Final scene selects the author's finale track")
	check(not game.audio.personal_player.stream.loop,"Finale track never loops")
	game.audio.set_scene("credits")
	check(game.audio._personal_kind=="finale" and game.audio.personal_player.playing,"Finale music continues into the credits")
	game.audio.personal_player.stop()
	game.audio._on_personal_finished()
	check(not game.audio.personal_player.playing,"Finished track stays stopped")
	print("SHIFT RELEASE FEATURES: ",assertions," checks, ",failures.size()," failures")
	game.stage="menu"
	await game.quit_game(0 if failures.is_empty() else 1)
