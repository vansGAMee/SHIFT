extends SceneTree
## Actual atomic-save / continue round trip. Refuses the user's real profile.
var game: Node
var failures: Array[String]=[]
var assertions:=0

func _initialize():
	call_deferred("run")

func check(ok: bool,caption: String):
	assertions+=1
	print("SAVE ","PASS: " if ok else "FAIL: ",caption)
	if not ok: failures.append(caption)

func write_progress():
	game.automating=false
	game.automation_session=false
	game.save_progress()
	game.automating=true
	game.automation_session=true

func run():
	if not OS.get_user_data_dir().contains("shift-save-"):
		push_error("Save regression requires an isolated /tmp/shift-save-* profile")
		quit(2)
		return
	game=load("res://scripts/main.gd").new()
	game.automating=true
	game.automation_session=true
	root.add_child(game)
	await create_timer(1.5).timeout
	game.journey_started=true
	game.has_ammo=true
	game.narrative.flags={"sisterIntroduced":true,"lossConfirmed":true}
	game.narrative.secrets={"5":true}
	game.build_scene("chamber13")
	write_progress()
	check(game.has_saved_journey(),"Written format-3 checkpoint is accepted")
	var cfg=ConfigFile.new()
	check(cfg.load(game.SAVE_PATH)==OK,"Atomic save can be read as a real ConfigFile")
	check(cfg.get_value("journey","stage","")=="chamber13","Room checkpoint survives serialization")
	check(cfg.get_value("journey","ammo",false),"Pandora item survives serialization")
	check(cfg.get_value("journey","story",{}).get("lossConfirmed",false),"Mandatory story flags survive serialization")
	check(cfg.get_value("journey","secrets",{}).has("5"),"Optional memories survive serialization")
	game.narrative.flags.regretHeard=true
	write_progress()
	cfg.load(game.SAVE_PATH)
	check(cfg.get_value("journey","story",{}).get("regretHeard",false),"Atomic rename replaces an existing save")
	check(not FileAccess.file_exists(game.SAVE_PATH+".tmp"),"Successful rename leaves no partial save")
	game.has_ammo=false
	game.narrative.flags.clear()
	game.narrative.secrets.clear()
	game.resume_saved()
	await create_timer(2.5).timeout
	check(game.stage=="chamber13" and game.has_ammo,"Continue restores the room and story item")
	check(game.narrative.flags.get("lossConfirmed",false) and game.narrative.secrets.has("5"),"Continue restores story and optional memories")
	check(game.used_shift and game.extra_level.solved,"Resumed Pandora preserves its completed puzzle")
	check(not game.extra_level.beat_started,"Unfinished revelation remains available after Continue")
	cfg.set_value("journey","stage","chamber999")
	cfg.save(game.SAVE_PATH)
	check(not game.has_saved_journey(),"Invalid room IDs cannot be continued")
	cfg.set_value("journey","stage","chamber2")
	cfg.set_value("journey","format_version",2)
	cfg.set_value("journey","ammo",true)
	cfg.save(game.SAVE_PATH)
	check(game.has_saved_journey(),"Legacy demo checkpoint is accepted")
	game.resume_saved()
	await create_timer(2.5).timeout
	check(game.stage=="chamber2" and not game.has_ammo,"Legacy cartridge is migrated out of early rooms")
	print("SHIFT SAVE ROUND TRIP: ",assertions," checks, ",failures.size()," failures")
	await game.quit_game(0 if failures.is_empty() else 1)
