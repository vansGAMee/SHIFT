extends CanvasLayer

const FONT = preload("res://assets/fonts/regular.ttf")
const MONO = preload("res://assets/fonts/mono.ttf")
var game: Node
var root: Control
var menu: Control
var settings: Control
var pause_panel: Control
var credit_panel: Control
var chapter: Label
var budget: Label
var prompt: Label
var message: Label
var pair: Label
var help: Label
var fps: Label
var cross: Label
var fade: ColorRect
var flash: ColorRect
var chapter_time := 0.0
var message_time := 0.0
var menu_continue: Button
var menu_new: Button
var subtitle: Label
var reset_panel: Control
var mountain_memory: TextureRect

func _init(owner_game: Node = null):
	game = owner_game

func _ready():
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	chapter = label_at("", Vector2(42, 32), 22)
	budget = label_at("", Vector2(940, 36), 17, MONO)
	budget.size = Vector2(298, 40)
	budget.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	fps = label_at("", Vector2(42, 80), 14, MONO)
	cross = label_at("·", Vector2(628, 338), 24, MONO)
	cross.size = Vector2(24, 36)
	cross.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt = label_at("", Vector2(240, 565), 19)
	prompt.size = Vector2(800, 68)
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	pair = label_at("", Vector2(170, 630), 17, MONO)
	pair.size = Vector2(940, 52)
	pair.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	message = label_at("", Vector2(180, 486), 20)
	message.size = Vector2(920, 70)
	message.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	help = label_at("", Vector2(42, 682), 14)
	subtitle = label_at("",Vector2(140,448),23)
	subtitle.size = Vector2(1000,94)
	subtitle.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	subtitle.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	subtitle.add_theme_color_override("font_shadow_color",Color.BLACK)
	subtitle.add_theme_constant_override("shadow_offset_y",3)
	menu = panel()
	var veil = ColorRect.new()
	veil.color = Color(0.025, 0.035, 0.048, 0.30)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	veil.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(veil)
	label_at("S H I F T", Vector2(83, 136), 83, MONO, menu)
	var sub = label_at("Всё ещё здесь.", Vector2(90, 245), 22, FONT, menu)
	sub.modulate = Color("d8c3ad")
	menu_new = button_at("Начать с горы", Vector2(86, 337), func(): game.new_game(), menu)
	menu_continue = button_at("Продолжить сохранение", Vector2(86, 392), func(): game.resume_saved(), menu)
	button_at("Настройки", Vector2(86, 447), func(): show_settings(), menu)
	button_at("Выйти", Vector2(86, 502), func(): game.quit_game(), menu)
	pause_panel = panel()
	backdrop(pause_panel)
	label_at("Пауза", Vector2(430, 145), 42, MONO, pause_panel)
	button_at("Вернуться", Vector2(430, 251), func(): game.toggle_pause(), pause_panel)
	button_at("Настройки", Vector2(430, 311), func(): show_settings(), pause_panel)
	button_at("Начать помещение заново", Vector2(430, 371), func(): request_reset(), pause_panel, 440)
	button_at("В главное меню", Vector2(430, 431), func(): game.show_menu(), pause_panel)
	button_at("Выйти", Vector2(430, 491), func(): game.quit_game(), pause_panel)
	label_at("WASD — идти    Мышь / стрелки — смотреть\nE — действие    ПКМ — контур    Shift — обмен\nF — осмотреть ружьё    Q — отменить выбор\nR — повторить комнату    F11 — полный экран", Vector2(430, 564), 15, FONT, pause_panel)
	pause_panel.hide()
	settings = panel()
	backdrop(settings)
	label_at("Настройки", Vector2(180, 95), 36, MONO, settings)
	label_at("Language / Язык",Vector2(720,95),19,FONT,settings)
	var language_choice=OptionButton.new()
	language_choice.position=Vector2(720,130)
	language_choice.size=Vector2(350,38)
	language_choice.add_item("English")
	language_choice.add_item("Русский")
	language_choice.select(1 if game.language=="ru" else 0)
	language_choice.item_selected.connect(func(index): game.set_language("ru" if index==1 else "en"))
	settings.add_child(language_choice)
	slider("Общая громкость", 175, game.master_volume, func(v): game.master_volume=v; game.audio.set_master(v))
	slider("Музыка", 243, game.music_volume, func(v): game.music_volume=v; game.audio.set_music(v))
	slider("Окружение", 311, game.ambience_volume, func(v): game.ambience_volume=v; game.audio.set_ambience(v))
	slider("Чувствительность мыши", 379, game.sensitivity / 0.006, func(v): game.sensitivity=maxf(0.0005,v*0.006))
	label_at("Детализация изображения", Vector2(180, 452), 17, FONT, settings)
	var quality = OptionButton.new()
	quality.position = Vector2(180, 482)
	quality.size = Vector2(460, 42)
	for q in ["Крупный пиксель · 480 × 270", "Классическая · 640 × 360", "Тонкий пиксель · 960 × 540"]:
		quality.add_item(q)
	quality.selected = game.quality
	quality.item_selected.connect(func(v): game.set_quality(v))
	style_control(quality, 17)
	settings.add_child(quality)
	var sway = CheckButton.new()
	sway.text = "Покачивание камеры"
	sway.position = Vector2(720, 170)
	sway.button_pressed = game.sway
	sway.toggled.connect(func(v): game.sway=v)
	style_control(sway, 17)
	settings.add_child(sway)
	setting_check("Без вспышек и искажений",234,game.reduced_flashes,func(v): game.reduced_flashes=v; game.display.material.set_shader_parameter("calm",v))
	setting_check("Без преследования",298,game.no_chase,func(v): game.no_chase=v)
	setting_check("Режим записи · без музыки",362,game.streamer_mode,func(v): game.streamer_mode=v; game.audio.streamer_mode=v)
	var access=label_at("Субтитры включены всегда.\nОшибочный обмен можно сбросить.\nПогоня не меняет сюжет и финал.",Vector2(720,448),16,FONT,settings)
	access.size=Vector2(450,110)
	button_at("Готово", Vector2(180, 612), func(): settings.hide(); game.save_settings(), settings)
	settings.hide()
	credit_panel = panel()
	backdrop(credit_panel)
	label_at("S H I F T", Vector2(409, 173), 64, MONO, credit_panel)
	var credits_text = "Всё ещё здесь.\n\nКонец\n\nИдея, концепция и геймдизайн — автор SHIFT\nОригинальная музыка — автор SHIFT\nРазработка и художественная реализация — с применением ИИ\n\nСпасибо, что остались."
	var credit_label = label_at(credits_text, Vector2(260, 291), 18, FONT, credit_panel)
	credit_label.size = Vector2(760, 270)
	credit_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button_at("В главное меню", Vector2(491, 591), func(): game.show_menu(), credit_panel)
	credit_panel.hide()
	mountain_memory=TextureRect.new()
	mountain_memory.texture=load("res://assets/textures/memory_mountain.png")
	mountain_memory.texture_filter=CanvasItem.TEXTURE_FILTER_NEAREST
	mountain_memory.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mountain_memory.expand_mode=TextureRect.EXPAND_IGNORE_SIZE
	mountain_memory.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_COVERED
	mountain_memory.mouse_filter=Control.MOUSE_FILTER_IGNORE
	root.add_child(mountain_memory)
	mountain_memory.hide()
	subtitle.move_to_front()
	reset_panel=panel()
	backdrop(reset_panel)
	label_at("Повторить эту комнату?",Vector2(320,240),32,FONT,reset_panel)
	label_at("Головоломка начнётся заново. Воспоминания сохранятся.",Vector2(320,310),18,FONT,reset_panel)
	button_at("Повторить",Vector2(320,390),func(): reset_panel.hide(); game.reset_pending=false; game.restart_chapter(),reset_panel)
	button_at("Вернуться",Vector2(680,390),func(): cancel_reset(),reset_panel)
	reset_panel.hide()
	flash = ColorRect.new()
	flash.color = Color(0.57, 0.76, 0.73, 0)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(flash)
	fade = ColorRect.new()
	fade.color = Color.BLACK
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.add_child(fade)
	set_gameplay(false)

func style_control(node: Control, size_px: int):
	node.add_theme_font_override("font", FONT)
	node.add_theme_font_size_override("font_size", size_px)
	for cname in ["font_color", "font_hover_color", "font_focus_color"]:
		node.add_theme_color_override(cname, Color("e6dfd2"))

func panel() -> Control:
	var p = Control.new()
	p.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	p.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(p)
	return p

func backdrop(p: Control):
	var b = ColorRect.new()
	b.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	b.color = Color(0.025, 0.032, 0.043, 0.94)
	p.add_child(b)

func label_at(text_value: String, at: Vector2, font_size: int, font: Font = FONT, parent: Node = null) -> Label:
	var l = Label.new()
	l.text = text_value
	l.position = at
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color("e4ded0"))
	l.add_theme_color_override("font_shadow_color", Color(0.015,0.018,0.027,0.9))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	(parent if parent else root).add_child(l)
	return l

func button_at(text_value: String, at: Vector2, action: Callable, parent: Control, width: float = 300) -> Button:
	var b = Button.new()
	b.text = text_value
	b.position = at
	b.size = Vector2(width, 46)
	b.alignment = HORIZONTAL_ALIGNMENT_LEFT
	style_control(b, 21)
	var normal = StyleBoxFlat.new()
	normal.bg_color = Color(0,0,0,0)
	normal.content_margin_left = 10
	var hover = normal.duplicate()
	hover.bg_color = Color(0.72,0.73,0.66,0.13)
	hover.border_width_left = 2
	hover.border_color = Color("d5b68d")
	b.add_theme_stylebox_override("normal", normal)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("focus", hover)
	b.add_theme_stylebox_override("pressed", hover)
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func slider(caption: String, y: float, value: float, action: Callable):
	label_at(caption, Vector2(180, y), 17, FONT, settings)
	var s = HSlider.new()
	s.position = Vector2(180,y+29)
	s.size = Vector2(460,20)
	s.min_value = 0
	s.max_value = 1
	s.step = 0.01
	s.value = value
	s.value_changed.connect(action)
	settings.add_child(s)

func show_settings():
	settings.show()
	settings.move_to_front()

func set_gameplay(active: bool):
	for node in [chapter, budget, prompt, pair, message, help, cross]:
		node.visible = active

func announce(text_value: String, duration: float = 4.0):
	message.text = text_value
	message_time = duration
	message.modulate.a = 1.0

func chapter_title(text_value: String):
	chapter.text = text_value
	chapter_time = 7.0
	chapter.modulate.a = 1

func shift_flash():
	if game.reduced_flashes: return
	flash.color = Color(0.60,0.80,0.73,0.23)
	create_tween().tween_property(flash, "color:a", 0.0, 0.65)

func fade_to(alpha: float, seconds: float):
	var t = create_tween()
	t.tween_property(fade, "color:a", alpha, seconds)
	await t.finished

func _process(delta: float):
	if game.paused or settings.visible: return
	if message_time > 0:
		message_time -= delta
		message.modulate.a = minf(message_time,1.0)
	if chapter_time > 0:
		chapter_time -= delta
		chapter.modulate.a = minf(chapter_time,1.0)

func setting_check(caption: String,y: float,value: bool,action: Callable):
	var check=CheckButton.new()
	check.text=caption
	check.position=Vector2(720,y)
	check.button_pressed=value
	check.toggled.connect(action)
	style_control(check,17)
	settings.add_child(check)

func request_reset():
	if game.busy or game.stage in ["menu","finale","prologue"]: return
	game.reset_pending=true
	game.paused=true
	pause_panel.hide()
	reset_panel.show()
	reset_panel.move_to_front()
	Input.mouse_mode=Input.MOUSE_MODE_VISIBLE

func cancel_reset():
	reset_panel.hide()
	game.reset_pending=false
	game.paused=false
	Input.mouse_mode=Input.MOUSE_MODE_CAPTURED if not game.automating else Input.MOUSE_MODE_VISIBLE
