extends CanvasLayer

signal start_requested(names: Array)
signal resume_requested
signal next_requested
signal menu_requested
signal paused_changed(paused: bool)
signal settings_changed(sound: bool, music: bool, quality: bool, effects: bool, skills: bool)

const IVORY := Color("#e9e7cf")
const MUTED := Color("#8eaa99")
const GOLD := Color("#d9b979")
const JADE := Color("#8cddbf")
var serif: Font = preload("res://assets/fonts/NotoSerifSC.ttf")
var sans: Font = preload("res://assets/fonts/NotoSansSC.ttf")
var brush: Font = preload("res://assets/fonts/MaShanZheng.ttf")
var root: Control
var menu: Control
var hud: Control
var modal: Control
var veil: ColorRect
var popup: Panel
var turn_label: Label
var turn_sub: Label
var round_label: Label
var score_labels: Array[Label] = []
var name_labels: Array[Label] = []
var color_labels: Array[Label] = []
var active_bars: Array[ColorRect] = []
var entry_names: Array[LineEdit] = []
var resume_button: Button
var toast_label: Label
var stage: Control
var calligraphy: Control
var calligraphy_tween: Tween
var notice_tween: Tween
var player_names: Array = ["墨客","听雨"]
var sound_on := true
var music_on := true
var high_quality := true
var effects_on := true
var skills_on := true
var in_menu := true
var modal_kind := ""
var busy_now := false

func _ready() -> void:
	serif = weighted(serif,550)
	sans = weighted(sans,450)
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	var theme := Theme.new()
	theme.default_font = sans
	theme.default_font_size = 16
	root.theme = theme
	var vignette := ColorRect.new()
	vignette.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vignette.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://shaders/vignette.gdshader")
	vignette.material = shader
	root.add_child(vignette)
	_build_menu()
	_build_hud()
	toast_label = label(root,"",Vector2(380,825),Vector2(1010,36),15,IVORY)
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.modulate.a = 0
	_build_calligraphy()
	stage = preload("res://scripts/cinematic.gd").new()
	root.add_child(stage)
	modal = group(root)
	veil = ColorRect.new()
	veil.color = Color(.008,.024,.02,.75)
	veil.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	modal.add_child(veil)
	popup = Panel.new()
	popup.position = Vector2(430,210)
	popup.size = Vector2(580,480)
	popup.add_theme_stylebox_override("panel",panel_style(Color("#102b25"),Color("#64725a"),20))
	modal.add_child(popup)
	modal.hide()
	show_menu(false)

func weighted(base: Font, weight: float) -> Font:
	var variation := FontVariation.new()
	variation.base_font = base
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):weight}
	return variation

func group(parent: Node) -> Control:
	var node := Control.new()
	node.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func panel_style(background: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = background
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.content_margin_left = 18
	style.content_margin_right = 18
	style.content_margin_top = 10
	style.content_margin_bottom = 10
	return style

func label(parent: Node, text: String, pos: Vector2, dimensions: Vector2, font_size: int = 16, color: Color = IVORY, font: Font = null) -> Label:
	var node := Label.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.add_theme_font_override("font",font if font else sans)
	node.add_theme_font_size_override("font_size",font_size)
	node.add_theme_color_override("font_color",color)
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(node)
	return node

func button(parent: Node, text: String, pos: Vector2, dimensions: Vector2, action: Callable, primary: bool = false) -> Button:
	var node := Button.new()
	node.text = text
	node.position = pos
	node.size = dimensions
	node.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	node.add_theme_font_override("font",serif)
	node.add_theme_font_size_override("font_size",17)
	node.add_theme_color_override("font_color",Color("#182f25") if primary else IVORY)
	node.add_theme_color_override("font_hover_color",Color("#102a21") if primary else Color.WHITE)
	node.add_theme_stylebox_override("normal",panel_style(GOLD if primary else Color(.03,.10,.08,.85),GOLD if primary else Color("#42594a"),8))
	node.add_theme_stylebox_override("hover",panel_style(Color("#ebd39a") if primary else Color("#214a3c"),GOLD,8))
	node.add_theme_stylebox_override("pressed",panel_style(Color("#b8a46f") if primary else Color("#102f26"),JADE,8))
	node.add_theme_stylebox_override("focus",panel_style(Color(0,0,0,0),JADE,8))
	node.pressed.connect(action)
	parent.add_child(node)
	return node

func _build_menu() -> void:
	menu = group(root)
	var shade := ColorRect.new()
	shade.position = Vector2.ZERO
	shade.size = Vector2(510,900)
	shade.color = Color(.008,.032,.025,.65)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu.add_child(shade)
	label(menu,"R A I N F A L L   /   同 席 对 弈",Vector2(72,62),Vector2(450,30),13,GOLD)
	var title := label(menu,"听雨\n弈境",Vector2(65,117),Vector2(340,268),110,IVORY,brush)
	title.add_theme_constant_override("line_spacing",-16)
	label(menu,"松间一局棋，落子有回声。",Vector2(75,410),Vector2(400,40),21,IVORY,serif)
	label(menu,"雨 林 棋 境   ·   双 人 同 屏   ·   五 局 三 胜",Vector2(75,467),Vector2(410,28),12,MUTED)
	label(menu,"首局执黑",Vector2(76,530),Vector2(150,28),12,GOLD)
	label(menu,"首局执白",Vector2(263,530),Vector2(150,28),12,MUTED)
	for i in 2:
		var field := LineEdit.new()
		field.position = Vector2(75+i*187,563)
		field.size = Vector2(168,42)
		field.text = player_names[i]
		field.max_length = 8
		field.placeholder_text = "玩家一" if i == 0 else "玩家二"
		field.add_theme_stylebox_override("normal",panel_style(Color(.04,.10,.08,.85),Color("#53654f"),6))
		field.add_theme_font_override("font",serif)
		field.add_theme_font_size_override("font_size",18)
		field.add_theme_color_override("font_color",IVORY)
		menu.add_child(field)
		entry_names.append(field)
	button(menu,"入 林  ·  开 局    →",Vector2(75,635),Vector2(355,54),func():
		player_names = [entry_names[0].text.strip_edges(),entry_names[1].text.strip_edges()]
		for i in 2:
			if player_names[i].is_empty():
				player_names[i] = "玩家一" if i == 0 else "玩家二"
		start_requested.emit(player_names),true)
	resume_button = button(menu,"续上未尽之局",Vector2(75,705),Vector2(210,42),func(): resume_requested.emit())
	button(menu,"玩法 / 设置",Vector2(295,705),Vector2(135,42),show_help)
	label(menu,"执子如执心，听雨不知时。",Vector2(75,815),Vector2(390,28),13,MUTED,serif)
	label(menu,"十五道 · 无禁手",Vector2(1175,807),Vector2(220,26),13,IVORY,serif)

func _build_hud() -> void:
	hud = group(root)
	var shade := ColorRect.new()
	shade.size = Vector2(345,900)
	shade.color = Color(.008,.028,.02,.86)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(shade)
	label(hud,"听雨弈境",Vector2(36,27),Vector2(240,55),35,IVORY,brush)
	label(hud,"R A I N F A L L",Vector2(39,84),Vector2(240,20),10,GOLD)
	round_label = label(hud,"第一局 · 五局三胜",Vector2(560,30),Vector2(500,40),18,IVORY,serif)
	round_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(hud,"局间小憩  ☰",Vector2(1225,30),Vector2(174,40),show_pause)
	for i in 2:
		var card := Panel.new()
		card.position = Vector2(32,148+i*112)
		card.size = Vector2(286,96)
		card.add_theme_stylebox_override("panel",panel_style(Color(.022,.065,.052,.87),Color("#3b5545"),10))
		card.mouse_filter = Control.MOUSE_FILTER_IGNORE
		hud.add_child(card)
		var bar := ColorRect.new()
		bar.position = Vector2(0,18)
		bar.size = Vector2(3,59)
		bar.color = GOLD
		bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		card.add_child(bar)
		active_bars.append(bar)
		name_labels.append(label(card,player_names[i],Vector2(22,14),Vector2(133,34),23,IVORY,serif))
		color_labels.append(label(card,"执黑" if i == 0 else "执白",Vector2(23,58),Vector2(225,23),12,MUTED))
		score_labels.append(label(card,"○ ○ ○",Vector2(159,22),Vector2(115,29),18,GOLD))
	turn_label = label(hud,"墨客 · 执黑",Vector2(39,390),Vector2(290,36),24,IVORY,serif)
	turn_sub = label(hud,"点击棋盘交点落子",Vector2(40,433),Vector2(280,31),13,MUTED)
	label(hud,"黑棋先行 · 每局换色 · 先取三胜",Vector2(445,860),Vector2(700,24),12,MUTED,serif).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(hud,"Esc  小憩",Vector2(1260,858),Vector2(145,27),11,MUTED)

func show_menu(has_save: bool) -> void:
	in_menu = true
	menu.show()
	hud.hide()
	modal.hide()
	resume_button.visible = has_save

func show_game(names: Array) -> void:
	player_names = names
	in_menu = false
	menu.hide()
	hud.show()
	modal.hide()
	modal_kind = ""

func refresh(rules: RefCounted, busy: bool, acting_player: int = -1, acting_color: int = 0) -> void:
	busy_now = busy
	var shown_player: int = acting_player if acting_player >= 0 else rules.current_player()
	var shown_color: int = acting_color if acting_player >= 0 else rules.turn
	var numbers := ["一","二","三","四","五"]
	round_label.text = "第%s局   /   五局三胜" % numbers[clampi(rules.round_index,0,4)]
	for i in 2:
		name_labels[i].text = player_names[i]
		name_labels[i].add_theme_font_size_override("font_size",23 if str(player_names[i]).length() <= 5 else 16)
		var marks := ""
		for j in 3:
			marks += "● " if j < rules.wins[i] else "○ "
		score_labels[i].text = marks.strip_edges()
		color_labels[i].text = ("执黑" if rules.color_for(i) == 1 else "执白")
		active_bars[i].visible = rules.active() and shown_player == i
	turn_label.text = "%s · %s" % [player_names[shown_player],"执黑" if shown_color == 1 else "执白"]
	turn_sub.text = "落子中…" if busy else "第 %d 手  ·  点击交点落子" % (rules.move_count+1)
	if not rules.active():
		turn_sub.text = "此局已定"

func toast(text: String, seconds: float = 2.6) -> void:
	if notice_tween and notice_tween.is_running():
		notice_tween.kill()
	toast_label.text = text
	toast_label.modulate.a = 1
	notice_tween = create_tween()
	notice_tween.tween_interval(seconds)
	notice_tween.tween_property(toast_label,"modulate:a",0.0,.5)

func _build_calligraphy() -> void:
	calligraphy = Control.new()
	calligraphy.position = Vector2(365,110)
	calligraphy.size = Vector2(1030,210)
	calligraphy.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(calligraphy)
	calligraphy.hide()

func inscription(text: String, subtitle: String, tint: Color = GOLD, duration: float = 3.5) -> void:
	for child in calligraphy.get_children():
		child.queue_free()
	if calligraphy_tween and calligraphy_tween.is_running():
		calligraphy_tween.kill()
	calligraphy.show()
	calligraphy.modulate.a = 0
	calligraphy.scale = Vector2(1.12,1.12)
	calligraphy.pivot_offset = Vector2(515,90)
	var type_size := 103 if text.length() <= 4 else 76
	var shadow := label(calligraphy,text,Vector2(4,5),Vector2(1030,123),type_size,Color("#0b1b16"),brush)
	shadow.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	shadow.add_theme_constant_override("outline_size",12)
	shadow.add_theme_color_override("font_outline_color",Color(.01,.03,.02,.5))
	var main := label(calligraphy,text,Vector2.ZERO,Vector2(1030,123),type_size,tint,brush)
	main.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	main.add_theme_constant_override("outline_size",2)
	main.add_theme_color_override("font_outline_color",Color("#586645"))
	var sub := label(calligraphy,subtitle,Vector2(0,139),Vector2(1030,34),16,IVORY,serif)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	calligraphy_tween = create_tween().set_parallel()
	calligraphy_tween.tween_property(calligraphy,"modulate:a",1.0,.3)
	calligraphy_tween.tween_property(calligraphy,"scale",Vector2.ONE,.55).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	calligraphy_tween.chain().tween_interval(duration-1.0)
	calligraphy_tween.chain().tween_property(calligraphy,"modulate:a",0.0,.7)
	calligraphy_tween.chain().tween_callback(calligraphy.hide)

func clear_popup(size: Vector2 = Vector2(580,480)) -> void:
	for child in popup.get_children():
		popup.remove_child(child)
		child.queue_free()
	popup.size = size
	popup.position = (Vector2(1440,900)-size)*.5
	modal.show()

func close_modal() -> void:
	modal.hide()
	modal_kind = ""
	paused_changed.emit(false)

func show_pause() -> void:
	if in_menu or busy_now or modal_kind == "result":
		return
	modal_kind = "pause"
	paused_changed.emit(true)
	clear_popup(Vector2(480,365))
	label(popup,"棋间听雨",Vector2(38,25),Vector2(400,65),43,IVORY,brush)
	label(popup,"棋局会自动保存，雨声不急。",Vector2(40,96),Vector2(400,30),15,MUTED,serif)
	button(popup,"继续对局",Vector2(40,155),Vector2(400,47),close_modal,true)
	button(popup,"玩法与设置",Vector2(40,218),Vector2(193,45),show_help)
	button(popup,"回到序页",Vector2(247,218),Vector2(193,45),func():close_modal();menu_requested.emit())
	label(popup,"Esc  返回棋盘",Vector2(42,299),Vector2(395,27),12,MUTED)

func show_help() -> void:
	modal_kind = "help"
	paused_changed.emit(true)
	clear_popup(Vector2(730,725))
	label(popup,"棋  中  万  象",Vector2(36,20),Vector2(660,60),39,IVORY,brush)
	var text := "十五道棋盘，黑棋先行。任一方向连成五子即胜，无禁手。\n每局互换黑白，先赢三局者获胜；和棋重赛本局，黑白不换。\n\n两人共用鼠标，点击空交点落子。棋局会自动保存。\nEsc 小憩 · F11 全屏"
	var body := label(popup,text,Vector2(38,98),Vector2(657,200),16,IVORY)
	body.add_theme_constant_override("line_spacing",5)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label(popup,"声音与画面",Vector2(40,309),Vector2(650,28),17,GOLD,serif)
	for item in [["雨声与音效",sound_on,0],["林间泛音",music_on,1],["完整光影",high_quality,2],["特效",effects_on,3],["特技",skills_on,4]]:
		var box := CheckButton.new()
		box.text = item[0]
		box.button_pressed = item[1]
		var index: int = item[2]
		box.name = ["SoundToggle","MusicToggle","QualityToggle","EffectsToggle","SkillsToggle"][index]
		box.position = Vector2(35+index*220,350) if index<3 else Vector2(35+(index-3)*340,470)
		box.size = Vector2(210 if index<3 else 310,42)
		box.toggled.connect(func(value: bool):
			if index == 0: sound_on = value
			elif index == 1: music_on = value
			elif index == 2: high_quality = value
			elif index == 3: effects_on = value
			else: skills_on = value
			settings_changed.emit(sound_on,music_on,high_quality,effects_on,skills_on))
		popup.add_child(box)
	label(popup,"完整光影包含体积雾与环境遮蔽。关闭可提升帧率。",Vector2(41,403),Vector2(640,24),12,MUTED)
	label(popup,"棋子光效、雷电震子与招式演出",Vector2(43,518),Vector2(307,27),13,MUTED)
	label(popup,"允许触发隐藏招式",Vector2(383,518),Vector2(307,27),13,MUTED)
	var note:=label(popup,"关闭特效不影响招式结果；关闭特技后按普通五子棋规则落子。\n更改立即生效，下次进入游戏仍会保留。",Vector2(41,571),Vector2(649,55),13,MUTED)
	note.add_theme_constant_override("line_spacing",5)
	note.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	button(popup,"心 中 有 数  ·  返 回",Vector2(40,649),Vector2(650,44),close_modal,true)

func show_result(rules: RefCounted) -> void:
	modal_kind = "result"
	clear_popup(Vector2(650,447))
	var draw: bool = rules.round_winner < 0
	var match_done: bool = rules.match_winner >= 0
	var title := "棋逢对手" if draw else ("此境称魁" if match_done else "一局已定")
	label(popup,title,Vector2(40,22),Vector2(570,68),48,GOLD,brush).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var winner: String = "" if draw else player_names[rules.round_winner]
	label(popup,"满盘皆落，再弈一局。" if draw else winner+(" · 三胜定乾坤" if match_done else " · 得此一胜"),Vector2(40,106),Vector2(570,44),25,IVORY,serif).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label(popup,"%s    %d  :  %d    %s" % [player_names[0],rules.wins[0],rules.wins[1],player_names[1]],Vector2(40,176),Vector2(570,40),25,GOLD,serif).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var sub := "落子声歇，松雨未停。"
	if not match_done:
		sub = "和棋重赛，黑白不换。" if draw else "下一局交换黑白。"
	label(popup,sub,Vector2(40,235),Vector2(570,35),16,MUTED,serif).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	button(popup,"再赴一局" if match_done else ("重赛本局" if draw else "交换黑白 · 下一局"),Vector2(40,307),Vector2(570,49),func():modal.hide();next_requested.emit(),true)
	button(popup,"留雨于此 · 回到序页",Vector2(183,371),Vector2(285,40),func():modal.hide();menu_requested.emit())

func flash(color: Color, alpha: float) -> void:
	var rect := ColorRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.color = Color(color,alpha)
	root.add_child(rect)
	var tween := create_tween()
	tween.tween_property(rect,"color:a",0.0,.7)
	tween.tween_callback(rect.queue_free)
