extends Node
## Mandatory memories run on the main path. Timers pause with the game and
## settings; flags are committed only after the final subtitle is read.
signal finished(id: String)
signal line_changed(id: String, line_index: int)
var game: Node
var flags: Dictionary = {}
var secrets: Dictionary = {}
var active := false
var current := ""
var lines: Array = []
var remaining := 0.0
var index := 0
const BEATS = {
	"sisterIntroduced": [["Сестра: Смотри, братик. Под этой елью нас никто не найдёт.",4.0], ["Сестра: Ещё один миф? Только потом твоя очередь читать.",4.0]],
	"shiftOriginKnown": [["Я, в детстве: А если у одного есть огонь, а у другого нет?",4.0], ["Сестра: Значит, поменяем. Два состояния. Один обмен.",4.0], ["Я, в детстве: Назовём это SHIFT. Наша игра.",3.5]],
	"illnessKnown": [["Сестра: Снова принёс книжку?",3.3], ["Я: Ты же её любишь.",3.0], ["Сестра: Я тебя больше. Врачи говорят, лечение будет долгим.",4.8]],
	"promiseHeard": [["[Звонок. Больничная палата.]",2.8], ["Сестра: Ты завтра придёшь?",3.8], ["Я: Да. Обещаю.",4.0]],
	"emptyWard": [["Сестра, за дверью: Ты здесь?..",3.5], ["Я: Подожди…",4.0], ["[Пустая кровать. Только ветер за стеклом.]",3.5]],
	"lossConfirmed": [["Родственница: Её не стало сегодня утром.",5.0], ["Родственница: Болезнь оказалась сильнее лечения.",4.5], ["Я: Я же обещал прийти…",5.0]],
	"labyrinthKnown": [["Я: Эти стены… Я уже видел это.",4.0], ["[На бетоне проступают страницы детской книги.]",4.5], ["Я: Мы нарисовали этот лабиринт вместе.",4.0]],
	"regretHeard": [["[Неотвеченное сообщение.]",2.7], ["Сестра: Я нашла нашу книжку. Позвони, когда сможешь.",5.0], ["Я: Если бы я тогда ответил…",4.0], ["Я: Вчера не обменять. Даже здесь.",4.0]],
	"secondRevealed": [["[Те же рукава. Те же руки. Та же поза.]",4.0], ["Я: Ты… это я.",4.0], ["[На миг — ель. Я всё ещё лежу под ней.]",4.5], ["Я: Я никуда не уходил.",3.8]]
}

func enter_stage():
	active = false
	current = ""
	lines.clear()
	if game.ui:
		game.ui.subtitle.text = ""
		game.ui.mountain_memory.hide()
	game.story_active = false

func play(id: String) -> bool:
	if active or not BEATS.has(id): return false
	current = id
	lines = BEATS[id].duplicate(true)
	index = 0
	active = true
	game.story_active = true
	game.selected.clear()
	game.inspection = false
	game.player.velocity = Vector3.ZERO
	game.audio.duck_ambience(3.0)
	show_line()
	return true

func show_line():
	game.ui.subtitle.text = lines[index][0]
	game.ui.subtitle.show()
	remaining = float(lines[index][1])
	line_changed.emit(current,index)
	game.audio.play_cue("memory" if index==0 else "select")

func _process(delta: float):
	if not active or game.paused or game.ui.settings.visible: return
	remaining -= delta
	if remaining > 0: return
	index += 1
	if index < lines.size():
		show_line()
	else:
		var completed = current
		flags[completed] = true
		active = false
		game.story_active = false
		game.ui.subtitle.text = ""
		game.ui.mountain_memory.hide()
		game.save_progress()
		finished.emit(completed)

func skip_repeat():
	if active and flags.get(current,false):
		index = lines.size()-1
		remaining = 0

func find_secret(id: String, caption: String):
	if not secrets.has(id):
		secrets[id] = true
		game.audio.play_cue("memory")
		game.save_progress()
	game.ui.announce(caption+"\nВоспоминания: %d / 10" % secrets.size(),6)
