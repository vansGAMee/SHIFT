extends Node

# Regression for an existing valid chapter-II save followed by New Game.
# Run with XDG_DATA_HOME=/tmp/shift-startup-isolated and -- --startup-test.
# Main owns the single game instance; no second main.tscn is instantiated here.
var failures: Array[String] = []
var game: Node
var assertions := 0

func check(condition: bool, description: String):
	assertions += 1
	if condition:
		print("STARTUP PASS: ",description)
	else:
		failures.append(description)
		push_error("STARTUP FAIL: "+description)

func find_new_game(parent: Node) -> Button:
	for child in parent.get_children():
		if child is Button:
			if child.text.to_lower().begins_with("начать"):
				return child
		var nested: Button = find_new_game(child)
		if nested: return nested
	return null

func run(owner_game: Node):
	game = owner_game
	if not OS.get_user_data_dir().contains("shift-startup-"):
		push_error("Startup regression requires an isolated /tmp/shift-startup-* profile; refusing to touch the real save")
		await game.quit_game(2)
		return
	print("STARTUP DATA DIR: ",OS.get_user_data_dir())
	check(game.stage=="menu" and game.ui.menu.visible,"Cold launch shows menu")
	check(get_tree().root.get_child_count()==1,"Startup owns one game instance")
	# This file is in isolated test user data. Automation must never change it.
	var cfg := ConfigFile.new()
	cfg.set_value("journey","format_version",2)
	cfg.set_value("journey","started",true)
	cfg.set_value("journey","stage","chamber2")
	cfg.set_value("journey","ammo",false)
	check(cfg.save("user://journey.cfg")==OK,"Seed a valid second-chamber checkpoint in isolated user data")
	game.build_scene("menu")
	await get_tree().create_timer(0.15).timeout
	check(game.stage=="menu" and game.ui.menu.visible,"Existing chamber2 checkpoint keeps launch in menu")
	check(not game.ui.menu_continue.disabled,"Valid checkpoint enables Continue")
	var new_game: Button = find_new_game(game.ui.menu)
	check(is_instance_valid(new_game),"New Game is a real menu button")
	if not new_game:
		game.quit_game(1)
		return
	check(new_game.position.y<game.ui.menu_continue.position.y,"New Game appears before Continue")
	new_game.pressed.emit()
	await get_tree().create_timer(2.6).timeout
	check(game.stage=="prologue","Actual New Game button starts on the mountain")
	check(not game.has_rifle and not game.gun_pivot.visible,"New Game starts with empty hands")
	check(is_instance_valid(game.ground_rifle) and game.ground_rifle.visible,"Rifle lies separately in the grass")
	check(not game.has_ammo and not game.loaded_round,"New Game resets the cartridge state")
	var original: Vector3 = game.player.position
	await get_tree().create_timer(15.0).timeout
	check(game.stage=="prologue","Mountain remains active for fifteen seconds without input")
	check(game.player.position.is_equal_approx(original),"The lying player remains in place")
	var saved := ConfigFile.new()
	saved.load("user://journey.cfg")
	check(saved.get_value("journey","stage","")=="chamber2","Automation does not overwrite the isolated existing checkpoint")
	check(game.automation_session,"Startup test has persistent automation save isolation")
	print("STARTUP RESULT: ",assertions," checks, ",failures.size()," failures")
	game.quit_game(0 if failures.is_empty() else 1)
