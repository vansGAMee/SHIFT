extends Node
## The story's Russian originals remain the source for both language choices.
## Track text changes and render them once, after gameplay has updated its labels.
var game: Node
var catalog: Dictionary = {}
var replacements: Array = []
var labels: Array[Node] = []

func _ready():
	catalog=JSON.parse_string(FileAccess.get_file_as_string("res://assets/localization/en.json"))
	for source in catalog:
		replacements.append([source,catalog[source]])
		if source.to_upper()!=source:
			replacements.append([source.to_upper(),str(catalog[source]).to_upper()])
	replacements.sort_custom(func(a,b): return a[0].length()>b[0].length())
	get_tree().node_added.connect(watch)
	watch_tree(game)
	process_priority=100
	refresh()

func watch(node: Node):
	if node is Label or node is Label3D or node is BaseButton:
		if not labels.has(node): labels.append(node)

func watch_tree(node: Node):
	watch(node)
	for child in node.get_children(): watch_tree(child)

func translate(source: String) -> String:
	if game.language=="ru": return source
	if catalog.has(source): return catalog[source]
	var rendered=source
	for pair in replacements:
		if rendered.contains(pair[0]): rendered=rendered.replace(pair[0],pair[1])
	return rendered

func source_of(node: Node) -> String:
	return node.get_meta("translation_source",node.text)

func refresh():
	var live: Array[Node]=[]
	for node in labels:
		if not is_instance_valid(node): continue
		live.append(node)
		if node is OptionButton:
			if not node.has_meta("translation_options"):
				var options: Array[String]=[]
				for i in range(node.item_count): options.append(node.get_item_text(i))
				node.set_meta("translation_options",options)
			if game.language!=node.get_meta("translation_language",""):
				var options=node.get_meta("translation_options")
				for i in range(node.item_count): node.set_item_text(i,translate(options[i]))
				node.set_meta("translation_language",game.language)
			continue
		var current: String=node.text
		if current==node.get_meta("translation_rendered","__SHIFT_UNTRANSLATED__") and game.language==node.get_meta("translation_language",""): continue
		if current!=node.get_meta("translation_rendered","__SHIFT_UNTRANSLATED__"):
			node.set_meta("translation_source",current)
		var rendered=translate(node.get_meta("translation_source",current))
		if current!=rendered: node.text=rendered
		node.set_meta("translation_rendered",rendered)
		node.set_meta("translation_language",game.language)
	labels=live

func _process(_delta: float):
	refresh()
