extends Node3D

const Rules = preload("res://scripts/rules.gd")
const Atmosphere = preload("res://scripts/atmosphere.gd")
const Effects = preload("res://scripts/effects_v2.gd")
const Interface = preload("res://scripts/interface.gd")
const BLACK_MODEL = preload("res://assets/models/black_stone.glb")
const WHITE_MODEL = preload("res://assets/models/white_stone.glb")
const StoneVisual = preload("res://scripts/stone_visual.gd")
const ChargeRadiance = preload("res://scripts/charge_radiance.gd")
const DivineHand = preload("res://scripts/divine_hand.gd")
const HAND_TOKEN_POSITION := Vector3(-4.76,-.37,2.78)
const STEP := .46
const HEIGHT := .669
const SAVE_PATH := "user://match.json"
const SETTINGS_PATH := "user://settings.cfg"
var rules := Rules.new()
var scenery: Atmosphere
var fx: Effects
var ui: Interface
var stones: Dictionary = {}
var stone_root: Node3D
var playing := false
var busy := false
var paused := false
var names: Array = ["墨客","听雨"]
var anchor := Vector2i(-1,-1)
var direction := Vector2i.ZERO
var bow_preview: Node3D
var draw_audio: AudioStreamPlayer
var press_cell := Vector2i(-1,-1)
var press_screen := Vector2.ZERO
var hold_time := 0.0
var charge_preview: Node3D
var charge_material: ShaderMaterial
var charge_radiance: ChargeRadiance
var charge_audio: AudioStreamPlayer
var charge_ready := false
var charge_started := false
var shake_strength := 0.0
var shake_remaining := 0.0
var saved_match: Dictionary = {}
var verification_mode := false
var acting_player := -1
var acting_color := 0
var camera_motion: Tween
var camera_home: Transform3D
var camera_fov := 43.0
var cinema_focus := Vector3.ZERO
var in_cinema := false
var quitting := false
var stone_materials: Dictionary = {}
var hover_preview: Node3D
var hover_models: Dictionary = {}
var hover_cell := Vector2i(-1,-1)
var hand_token:Node3D
var hand_token_pressed:=false
var hand_effect:Node3D
var pointer_screen := Vector2(-1,-1)
var pointer_inside := false
var isolated_replay := false
const HOLD_SECONDS := 2.0
func _ready() -> void:
	get_tree().auto_accept_quit=false
	verification_mode = OS.get_cmdline_user_args().has("--verify")
	isolated_replay=verification_mode and OS.get_cmdline_user_args().has("--isolated-replay")
	DisplayServer.window_set_title("听雨弈境 · 自动回放（不保存棋局）" if verification_mode else "听雨弈境 · Rainfall")
	if DisplayServer.get_name() != "headless":
		if isolated_replay:
			# Keep GPU captures drawing on macOS without taking the user's input.
			var replay_window:=get_window()
			replay_window.mode=Window.MODE_WINDOWED
			for flag in [Window.FLAG_NO_FOCUS,Window.FLAG_MOUSE_PASSTHROUGH,Window.FLAG_RESIZE_DISABLED,Window.FLAG_ALWAYS_ON_TOP]:
				replay_window.set_flag(flag,true)
			replay_window.size=Vector2i(1280,800)
			var area:=DisplayServer.screen_get_usable_rect()
			replay_window.position=area.end-replay_window.size-Vector2i(24,24)
		if not verification_mode:
			var usable := DisplayServer.screen_get_usable_rect()
			var width := mini(2160,usable.size.x-120)
			var height := roundi(width/1.6)
			if height > usable.size.y-120:
				height = usable.size.y-120
				width = roundi(height*1.6)
			var desired := Vector2i(width,height)
			DisplayServer.window_set_size(desired)
			DisplayServer.window_set_position(usable.position+(usable.size-desired)/2)
		get_window().size_changed.connect(_resize_render)
		_resize_render()
	scenery = Atmosphere.new()
	add_child(scenery)
	fx = Effects.new()
	add_child(fx)
	stone_root = Node3D.new()
	stone_root.name = "Blender_Stones"
	add_child(stone_root)
	ui = Interface.new()
	add_child(ui)
	ui.start_requested.connect(begin_match)
	ui.resume_requested.connect(resume_match)
	ui.next_requested.connect(next_round)
	ui.menu_requested.connect(return_to_menu)
	ui.paused_changed.connect(func(value: bool):paused=value;_cancel_gesture();_refresh())
	ui.settings_changed.connect(apply_settings)
	get_window().mouse_exited.connect(_pointer_left)
	get_window().focus_exited.connect(_pointer_left)
	if isolated_replay:
		# Native desktop events cannot cancel scripted gestures in an unattended run.
		# The feedback runner exercises the same cancellation callback explicitly.
		get_window().mouse_exited.disconnect(_pointer_left)
		get_window().focus_exited.disconnect(_pointer_left)
	fx.impact.connect(scenery.duck)
	fx.thunder_struck.connect(func():shake(.028,.22))
	_load_settings()
	_make_hover_preview()
	_make_hand_token()
	_load_match()
	ui.show_menu(not saved_match.is_empty())
	await _warmup_visuals()
	if verification_mode:
		var test_path:="res://tests/playback_storm.gd" if OS.get_cmdline_user_args().has("--storm") else "res://tests/playback_v2.gd"
		if OS.get_cmdline_user_args().has("--effect-priority"):test_path="res://tests/playback_effect_priority.gd"
		if OS.get_cmdline_user_args().has("--audio-check"):test_path="res://tests/playback_audio.gd"
		if OS.get_cmdline_user_args().has("--settings-check"):test_path="res://tests/playback_settings.gd"
		if OS.get_cmdline_user_args().has("--feedback-check"):test_path="res://tests/playback_feedback.gd"
		if OS.get_cmdline_user_args().has("--hover-check"):test_path="res://tests/playback_feedback.gd"
		if OS.get_cmdline_user_args().has("--hand-check"):test_path="res://tests/playback_divine_hand.gd"
		var runner = load(test_path).new()
		add_child(runner)
		runner.call_deferred("run",self)

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and not quitting:
		quitting=true
		if not is_instance_valid(ui):
			get_tree().quit()
			return
		# Finish the audible release before closing the device. Preferences stay untouched.
		if playing:save_match()
		paused=true
		_cancel_gesture()
		await _shutdown_audio()
		get_tree().quit()

func _shutdown_audio() -> void:
	fx.set_sound_enabled(false)
	scenery.settings(false,false,ui.high_quality)
	await get_tree().create_timer(.28).timeout
	scenery.rain_audio.stop()
	scenery.music.stop()
	# Give the audio thread time to drain the stopped streams before device teardown.
	await get_tree().create_timer(.08).timeout

func _warmup_visuals() -> void:
	if DisplayServer.get_name()=="headless":return
	# Render each new material once behind the opening veil, so a first skill does not stall.
	var cover:=ColorRect.new()
	cover.color=Color("#080d0c")
	cover.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.root.add_child(cover)
	var words:=ui.label(cover,"听雨 · 入境",Vector2(470,365),Vector2(500,90),45,ui.IVORY,ui.brush)
	words.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	ui.stage.begin(1)
	ui.stage.inscription("bow",1)
	var at:=Vector3(0,.8,0)
	fx.smoke(at,1,1.0,true,4,.35)
	fx.smoke(at+Vector3.RIGHT,2,1.0,true,4,.35)
	fx.glint(at,1,.35)
	fx.lightning(at,1,false)
	fx.lightning(at+Vector3.RIGHT,2,false)
	fx.wave(at,1,3,.5)
	fx.wave(at,2,2,.5)
	var stroke:=fx.ribbon([at+Vector3.LEFT,at,at+Vector3.RIGHT],.15,Effects.INK)
	fx.fade(stroke,.4)
	var disk:=fx.moon_disk(at)
	disk.material_override.set_shader_parameter("strength",1.0)
	var stone:Node3D=BLACK_MODEL.instantiate()
	add_child(stone)
	stone.position=at
	var material:=ShaderMaterial.new()
	material.shader=preload("res://shaders/stone_ink.gdshader")
	for mesh:MeshInstance3D in stone.find_children("*","MeshInstance3D"):mesh.material_override=material
	var radiance:=ChargeRadiance.new()
	fx.add_child(radiance)
	radiance.position=at
	radiance.set_charge(.8)
	var hand_warmup:=DivineHand.new()
	add_child(hand_warmup)
	hand_warmup.elapsed=DivineHand.ASSEMBLY_TIME
	hand_warmup._update_pieces()
	hand_warmup.set_process(false)
	await get_tree().create_timer(1.4).timeout
	await RenderingServer.frame_post_draw
	disk.queue_free();stone.queue_free();radiance.cancel();hand_warmup.queue_free()
	await ui.stage.end()
	fx.clear_transients()
	var reveal:=create_tween()
	reveal.tween_property(cover,"modulate:a",0.0,.35)
	await reveal.finished
	cover.queue_free()

func _resize_render() -> void:
	get_window().scaling_3d_mode = Viewport.SCALING_3D_MODE_FSR
	get_window().scaling_3d_scale = clampf(1440.0 / maxf(get_window().size.x,1),.4,1.0)

func world(p: Vector2i) -> Vector3:
	return Vector3((p.x-7)*STEP,HEIGHT,(p.y-7)*STEP)

func world_float(p: Vector2) -> Vector3:
	return Vector3((p.x-7)*STEP,HEIGHT,(p.y-7)*STEP)

func screen_to_world(screen: Vector2, plane_height: float = HEIGHT) -> Vector3:
	var origin := scenery.camera.project_ray_origin(screen)
	var ray := scenery.camera.project_ray_normal(screen)
	if absf(ray.y) < .0001:
		return Vector3(1000,plane_height,1000)
	var distance := (plane_height-origin.y)/ray.y
	if distance < 0:
		return Vector3(1000,plane_height,1000)
	return origin+ray*distance

func screen_to_cell(screen: Vector2) -> Vector2i:
	var hit := screen_to_world(screen)
	var cell := Vector2i(roundi(hit.x/STEP)+7,roundi(hit.z/STEP)+7)
	if not rules.inside(cell) or Vector2(hit.x-world(cell).x,hit.z-world(cell).z).length() > STEP*.65:
		return Vector2i(-1,-1)
	return cell

func begin_match(players: Array) -> void:
	names = players.duplicate()
	rules.reset_match()
	_start_board()
	save_match()

func _start_board() -> void:
	playing = true
	paused = false
	busy = true
	acting_player = -1
	_clear_board()
	ui.show_game(names)
	ui.hud.modulate.a = 1.0
	scenery.set_camera(true,true)
	for y in Rules.SIZE:
		for x in Rules.SIZE:
			var p := Vector2i(x,y)
			if rules.at(p) != 0:
				var node := _make_stone(p,rules.at(p))
				if rules.has_effects(rules.at(p)):fx.bind_aura(node,rules.at(p))
	_refresh()
	await get_tree().create_timer(1.55).timeout
	busy = false
	if not rules.active():ui.show_result(rules)
	elif rules.pending_skill == "moon":await _moon()
	_refresh()

func _clear_board() -> void:
	_cancel_gesture()
	_hide_hover()
	fx.clear_transients()
	for child in stone_root.get_children():child.queue_free()
	stones.clear()
	if is_instance_valid(hand_effect):hand_effect.queue_free()
	hand_effect=null

func _make_stone(p:Vector2i, color:int) -> Node3D:
	var node:=StoneVisual.new(BLACK_MODEL if color==1 else WHITE_MODEL)
	stone_root.add_child(node)
	node.position=world(p)
	node.rotation.y=fposmod(float(p.x*17+p.y*23)*.29,TAU)
	node.set_meta("color",color)
	_neutral_stone(node,color)
	node.align_visual()
	stones[p]=node
	return node

func _neutral_stone(node:Node3D, color:int) -> void:
	if not stone_materials.has(color):
		var material:=StandardMaterial3D.new()
		material.albedo_color=Color("#111218") if color==1 else Color("#f3f4f7")
		material.roughness=.26 if color==1 else .31
		material.metallic=.03
		material.metallic_specular=.52
		stone_materials[color]=material
	for mesh:MeshInstance3D in node.find_children("*","MeshInstance3D"):
		mesh.material_override=stone_materials[color]

func _make_hover_preview() -> void:
	hover_preview=Node3D.new()
	hover_preview.name="PointerStone"
	add_child(hover_preview)
	for color in [Rules.BLACK,Rules.WHITE]:
		var model:=StoneVisual.new(BLACK_MODEL if color==Rules.BLACK else WHITE_MODEL)
		hover_preview.add_child(model)
		_neutral_stone(model,color)
		for mesh:MeshInstance3D in model.find_children("*","MeshInstance3D"):
			mesh.transparency=.22
			mesh.cast_shadow=GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		model.hide()
		hover_models[color]=model
	_hide_hover()

func _hide_hover() -> void:
	hover_cell=Vector2i(-1,-1)
	if is_instance_valid(hover_preview):hover_preview.hide()

func _pointer_left() -> void:
	pointer_inside=false
	_hide_hover()
	# Losing the window cannot leave an unseen charge waiting for a later release.
	if is_instance_valid(fx):_cancel_gesture()

func _update_hover() -> void:
	if not pointer_inside or not playing or busy or paused or in_cinema or ui.modal.visible or not rules.active() or anchor.x>=0 or press_cell.x>=0:
		_hide_hover()
		return
	var control:=get_viewport().gui_get_hovered_control()
	if control and control.mouse_filter!=Control.MOUSE_FILTER_IGNORE:
		_hide_hover()
		return
	var p:=screen_to_cell(pointer_screen)
	if not rules.inside(p) or rules.at(p)!=Rules.EMPTY:
		_hide_hover()
		return
	hover_cell=p
	hover_preview.position=world(p)
	hover_preview.set_meta("color",rules.turn)
	# The unadorned cursor is an input aid for both players, including with VFX off.
	hover_preview.show()
	for color:int in hover_models:
		var model:Node3D=hover_models[color]
		model.visible=color==rules.turn
		model.rotation.y=fposmod(float(p.x*17+p.y*23)*.29,TAU)
		model.align_visual()

func _convert(p:Vector2i, color:int, aura:bool=true) -> Node3D:
	if stones.has(p):
		if stones[p].get_meta("color")==color:return stones[p]
		stones[p].queue_free()
	var node:=_make_stone(p,color)
	if aura and rules.has_effects(color):fx.bind_aura(node,color)
	return node

func _refresh() -> void:
	ui.refresh(rules,busy,acting_player if busy else -1,acting_color)
	_update_hand_token()

func _make_hand_token() -> void:
	hand_token=StoneVisual.new(WHITE_MODEL)
	hand_token.name="WhiteStoneBesideBlackBowl"
	add_child(hand_token)
	hand_token.position=HAND_TOKEN_POSITION
	hand_token.scale=Vector3.ONE*1.16
	_neutral_stone(hand_token,Rules.WHITE)
	_update_hand_token()

func _update_hand_token() -> void:
	if is_instance_valid(hand_token):
		hand_token.visible=playing and rules.divine_hand_available() and not in_cinema

func _hand_token_hit(screen:Vector2) -> bool:
	if not is_instance_valid(hand_token) or not hand_token.visible:return false
	var center:=scenery.camera.unproject_position(HAND_TOKEN_POSITION)
	var edge:=scenery.camera.unproject_position(HAND_TOKEN_POSITION+Vector3.RIGHT*.27)
	return screen.distance_to(center)<=maxf(center.distance_to(edge),12.0)

func _process(delta:float) -> void:
	_update_hover()
	_update_hand_token()
	if shake_remaining>0:
		shake_remaining=maxf(0,shake_remaining-delta)
		scenery.camera.h_offset=sin(shake_remaining*81.0)*shake_strength*shake_remaining
		scenery.camera.v_offset=cos(shake_remaining*67.0)*shake_strength*shake_remaining*.65
	else:
		scenery.camera.h_offset=0
		scenery.camera.v_offset=0
	if in_cinema:
		ui.stage.screen_material.set_shader_parameter("origin",scenery.camera.unproject_position(cinema_focus)/get_viewport().get_visible_rect().size)
	if press_cell.x>=0 and not busy and not paused and rules.can_charge():
		hold_time+=delta
		if hold_time>=.32:
			_update_charge()

func _unhandled_input(event:InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
		if event.keycode==KEY_F11:
			var mode:=DisplayServer.window_get_mode()
			DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED if mode==DisplayServer.WINDOW_MODE_FULLSCREEN else DisplayServer.WINDOW_MODE_FULLSCREEN)
			get_viewport().set_input_as_handled()
			return
		if event.keycode==KEY_ESCAPE:
			_cancel_gesture()
			if busy:return
			if ui.modal.visible and ui.modal_kind!="result":ui.close_modal()
			elif playing and not ui.modal.visible:ui.show_pause()
			get_viewport().set_input_as_handled()
			return
	if not playing or busy or paused or ui.modal.visible or not rules.active():return
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and event.pressed:
		if _hand_token_hit(event.position):
			if rules.can_divine_hand():
				hand_token_pressed=true
				press_screen=event.position
			get_viewport().set_input_as_handled()
			return
		var p:=screen_to_cell(event.position)
		if not rules.inside(p):return
		if rules.pending_skill=="bow" and rules.bow_anchors.has(p):
			anchor=p
			direction=Vector2i.ZERO
		elif rules.at(p)==0:
			press_cell=p
			press_screen=event.position
			hold_time=0.0
			charge_ready=false
		get_viewport().set_input_as_handled()

func _input(event:InputEvent) -> void:
	if isolated_replay and not event.get_meta("replay_input",false):
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouseMotion or event is InputEventMouseButton:
		pointer_screen=event.position
		pointer_inside=true
		if event is InputEventMouseMotion:_update_hover()
	if anchor.x<0 and press_cell.x<0 and not hand_token_pressed:return
	if busy or paused or ui.modal.visible:
		_cancel_gesture()
		return
	if event is InputEventMouseMotion:
		if hand_token_pressed:
			if event.position.distance_to(press_screen)>18:_cancel_gesture()
		elif anchor.x>=0:_aim_bow(event.position)
		elif event.position.distance_to(press_screen)>26:_cancel_gesture()
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT and not event.pressed:
		if hand_token_pressed:
			var activate:=_hand_token_hit(event.position) and rules.can_divine_hand()
			_cancel_gesture()
			if activate:_divine_hand()
		elif anchor.x>=0:
			var shot_anchor:=anchor
			var shot_direction:=direction
			anchor=Vector2i(-1,-1)
			_clear_preview()
			if shot_direction!=Vector2i.ZERO:_bow(shot_anchor,shot_direction)
			elif stones.has(shot_anchor):stones[shot_anchor].position=world(shot_anchor)
		else:
			var p:=press_cell
			var charged:=charge_ready and rules.can_charge()
			_cancel_gesture()
			if charged:_cosmos(p)
			else:place(p)
		get_viewport().set_input_as_handled()

func _cancel_gesture() -> void:
	hand_token_pressed=false
	if stones.has(anchor):stones[anchor].position=world(anchor)
	anchor=Vector2i(-1,-1)
	direction=Vector2i.ZERO
	press_cell=Vector2i(-1,-1)
	hold_time=0.0
	charge_ready=false
	charge_started=false
	if is_instance_valid(charge_preview):charge_preview.queue_free()
	charge_preview=null
	if is_instance_valid(charge_radiance):charge_radiance.cancel()
	charge_radiance=null
	if is_instance_valid(charge_audio):fx.release_sound(charge_audio)
	charge_audio=null
	_clear_preview()

func _update_charge() -> void:
	if not charge_started:
		charge_started=true
		fx.clear_lightning()
		charge_audio=fx.sound("charge",-12)
	var t:=clampf((hold_time-.32)/(HOLD_SECONDS-.32),0,1)
	if not ui.effects_on:
		charge_ready=t>=1.0
		return
	if not is_instance_valid(charge_preview):
		charge_preview=StoneVisual.new(BLACK_MODEL)
		charge_preview.name="BoardHeldStone"
		add_child(charge_preview)
		charge_preview.position=world(press_cell)
		charge_material=ShaderMaterial.new()
		charge_material.shader=preload("res://shaders/stone_ink.gdshader")
		for mesh:MeshInstance3D in charge_preview.find_children("*","MeshInstance3D"):
			mesh.material_override=charge_material
		fx.smoke(world(press_cell)+Vector3.UP*.18,1,.9,false,20,1.0).reparent(charge_preview)
		charge_radiance=ChargeRadiance.new()
		fx.add_child(charge_radiance)
	charge_preview.position=world(press_cell)+Vector3.UP*(.12+t*.58)
	charge_preview.rotation.y=hold_time*3.0
	charge_preview.scale=Vector3.ONE*(1.0+t*1.15)
	charge_material.set_shader_parameter("charge",t)
	charge_radiance.position=charge_preview.position+Vector3.UP*.12
	charge_radiance.set_charge(t)
	if t>=1.0 and not charge_ready:
		charge_ready=true
		fx.smoke(charge_preview.position,1,1.6,true,28,.7).reparent(charge_preview)

func place(p:Vector2i) -> void:
	if busy or paused or not playing:return
	var result:=rules.place(p)
	if not result.ok:return
	busy=true
	acting_player=result.player
	acting_color=result.color
	save_match()
	_refresh()
	var node:=_make_stone(p,result.color)
	if result.skill=="moon":fx.clear_lightning()
	var opponents:Array[Node3D]=[]
	if result.storm:
		for q:Vector2i in stones:
			if rules.at(q)==3-result.color:opponents.append(stones[q])
	await fx.placement(node,result.color,result.empowered,result.storm,opponents)
	await get_tree().create_timer(.13).timeout
	if rules.pending_skill=="moon":await _moon()
	elif not rules.active():await _round_end()
	else:
		busy=false
		_refresh()
	save_match()

func _clear_preview() -> void:
	if is_instance_valid(bow_preview):bow_preview.queue_free()
	bow_preview=null
	if is_instance_valid(draw_audio):fx.release_sound(draw_audio)
	draw_audio=null

func _aim_bow(mouse:Vector2) -> void:
	if not stones.has(anchor):return
	var base:=world(anchor)
	var delta:=base-screen_to_world(mouse)
	if is_instance_valid(bow_preview):bow_preview.queue_free()
	bow_preview=null
	direction=Vector2i.ZERO
	var dist:=.22
	for candidate:Vector2i in rules.bow_directions(anchor):
		var projection:=delta.dot(Vector3(candidate.x,0,candidate.y))
		if projection>dist:
			dist=projection
			direction=candidate
	if direction==Vector2i.ZERO:
		stones[anchor].position=base
		if is_instance_valid(draw_audio):fx.release_sound(draw_audio,.08)
		draw_audio=null
		return
	if not is_instance_valid(draw_audio):
		fx.clear_lightning()
		draw_audio=fx.sound("bow_draw",-14)
	if is_instance_valid(draw_audio) and not draw_audio.has_meta("releasing"):
		var tension:=clampf((dist-.22)/.93,0,1)
		draw_audio.volume_db=lerpf(-17,-10,tension)+fx.volume_db
		draw_audio.pitch_scale=lerpf(.90,1.10,tension)
	var vector:=Vector3(direction.x,0,direction.y).normalized()
	var pull:=base-vector*minf(dist,1.15)+Vector3.UP*.22
	stones[anchor].position=pull
	if not ui.effects_on:return
	bow_preview=Node3D.new()
	bow_preview.name="ActiveBowDraw"
	add_child(bow_preview)
	var frame:=rules.bow_frame(anchor,direction)
	var a:=world(frame.ends[0])+Vector3.UP*.17
	var b:=world(frame.ends[1])+Vector3.UP*.17
	var cord:Array[Vector3]=[a,a.lerp(pull,.5),pull,pull.lerp(b,.5),b]
	fx.ribbon(cord,.040,Effects.INK).reparent(bow_preview)
	var arc:Array[Vector3]=[]
	for i in 33:
		var t:=float(i)/32
		arc.append(a.lerp(b,t)+vector*sin(t*PI)*(.34+minf(dist,1.15)*.16))
	fx.ribbon(arc,.18,Effects.INK).reparent(bow_preview)
	fx.ribbon(arc,.012,Color(.17,.17,.17,.70)).reparent(bow_preview)

func _camera_to(position_target:Vector3, look:Vector3, field:float, seconds:float) -> void:
	if camera_motion and camera_motion.is_running():camera_motion.kill()
	var pose:=Transform3D(Basis.IDENTITY,position_target).looking_at(look,Vector3.UP)
	camera_motion=create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_motion.tween_property(scenery.camera,"position",position_target,seconds)
	camera_motion.tween_property(scenery.camera,"quaternion",pose.basis.get_rotation_quaternion(),seconds)
	camera_motion.tween_property(scenery.camera,"fov",field,seconds)

func _cinema_begin(color:int, focus:Vector3, close:bool=false) -> void:
	fx.clear_lightning()
	shake_remaining=0.0
	camera_home=scenery.camera.transform
	camera_fov=scenery.camera.fov
	cinema_focus=focus
	in_cinema=true
	ui.stage.begin(color)
	create_tween().tween_property(ui.hud,"modulate:a",0.0,.24)
	scenery.duck(.9)
	_camera_to(focus+Vector3(-.65,5.4 if close else 8.1,5.0 if close else 7.0),focus+Vector3.UP*(1.35 if close else .25),43,.48)

func _cinema_end() -> void:
	if camera_motion and camera_motion.is_running():camera_motion.kill()
	camera_motion=create_tween().set_parallel().set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	camera_motion.tween_property(scenery.camera,"transform",camera_home,.65)
	camera_motion.tween_property(scenery.camera,"fov",camera_fov,.65)
	create_tween().tween_property(ui.hud,"modulate:a",1.0,.6)
	await ui.stage.end()
	await get_tree().create_timer(.2).timeout
	in_cinema=false

func _bow(p:Vector2i, d:Vector2i) -> void:
	var result:=rules.shoot_bow(p,d)
	if not result.ok:
		if stones.has(p):stones[p].position=world(p)
		return
	busy=true
	acting_player=0
	acting_color=Rules.BLACK
	save_match()
	_refresh()
	if not ui.effects_on:
		await _finish_plain_skill("bow_release",-4)
		return
	var projectile:Node3D=stones[p]
	stones.erase(p)
	var vector:=Vector3(d.x,0,d.y).normalized()
	var start:=projectile.position
	var end:=world(result.path.back())+vector*3.8+Vector3.UP*.18
	_cinema_begin(1,world(p).lerp(world(result.path.back()),.42))
	fx.smoke(start,1,1.7,true,35,.9)
	await get_tree().create_timer(.36).timeout
	fx.sound("bow_release",-4)
	ui.stage.strike(.8)
	shake(.07,.4)
	var trace:Array[Vector3]=[]
	for i in 25:trace.append(start.lerp(end,float(i)/24)+Vector3.UP*.1)
	var stroke:=fx.ribbon(trace,.52,Effects.INK)
	fx.fade(stroke,1.15)
	var edge:=fx.ribbon(trace,.012,Color(.17,.17,.17,.70))
	fx.fade(edge,.55)
	var progress:={"next":0}
	var flight:=create_tween()
	flight.tween_method(func(t:float):
		projectile.position=start.lerp(end,t)
		while progress.next<result.path.size():
			var q:Vector2i=result.path[progress.next]
			if (world(q)-projectile.position).dot(vector)>0:break
			if result.changed.has(q):_convert(q,1)
			fx.smoke(world(q)+Vector3.UP*.16,1,1.1,true,13,.8)
			progress.next+=1
	,0.0,1.0,.48).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	await flight.finished
	projectile.queue_free()
	for q:Vector2i in result.changed:_convert(q,1)
	fx.sound("impact",-5)
	fx.slashes(world(result.path.back()),1,2.2,7)
	ui.stage.strike(.7)
	ui.stage.inscription("bow",1)
	await get_tree().create_timer(2.7).timeout
	await _cinema_end()
	await _round_end(.25)

func _moon() -> void:
	if not rules.skills_enabled or rules.pending_skill!="moon":return
	busy=true
	acting_player=0
	acting_color=Rules.WHITE
	_refresh()
	if not ui.effects_on:
		if rules.resolve_moon().ok:await _finish_plain_skill("moon_impact",-5)
		return
	var center:=world_float(rules.moon_center)
	var orbit:Array[Vector2i]=rules.moon_ring.duplicate()
	_cinema_begin(2,center)
	var disk:=fx.moon_disk(center+Vector3.UP*.05)
	var disk_material:ShaderMaterial=disk.material_override
	fx.sound("moon_rise",-7)
	var streaks:=Node3D.new()
	add_child(streaks)
	for i in 4:
		var points:Array[Vector3]=[]
		for j in 28:
			var theta:=float(i)*TAU/4-float(j)/27*2.2
			points.append(Vector3(cos(theta)*.95,.06,sin(theta)*.95))
		fx.ribbon(points,.07,Effects.SILVER).reparent(streaks,false)
	var tween:=create_tween()
	tween.tween_method(func(t:float):
		var rise:=smoothstep(0,.6,t)*.85
		var merge:=smoothstep(.26,.90,t)
		streaks.position=center+Vector3.UP*rise
		streaks.rotation.y=-t*t*TAU*6
		disk.position.y=HEIGHT+rise+.08
		disk_material.set_shader_parameter("strength",smoothstep(.1,.55,t))
		disk_material.set_shader_parameter("formation",merge)
		disk_material.set_shader_parameter("rotation_phase",t*t*18.0)
		for q in orbit:
			var offset:=world(q)-center
			var phi:=atan2(offset.z,offset.x)+t*t*TAU*6
			var radius:=lerpf(Vector2(offset.x,offset.z).length(),.95,merge)
			stones[q].position=center+Vector3(cos(phi)*radius,rise,sin(phi)*radius)
			stones[q].scale=Vector3.ONE*(1.0-merge*.74)
	,0.0,1.0,1.9).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)
	await tween.finished
	fx.glint(center+Vector3.UP*.8,4.0,.45)
	var collapse:=create_tween()
	collapse.tween_property(disk,"position:y",HEIGHT+.02,.15).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
	await collapse.finished
	disk.queue_free()
	streaks.queue_free()
	for q in orbit:
		stones[q].position=world(q)
		stones[q].scale=Vector3.ONE
	var result:=rules.resolve_moon()
	save_match()
	fx.sound("moon_impact",-5)
	scenery.duck(1.0)
	ui.stage.strike(1.0)
	shake(.07,.65)
	fx.wave(center,2,6.0,.9)
	fx.slashes(center,2,3.0,12)
	var area:Array[Vector2i]=result.area
	area.sort_custom(func(a:Vector2i,b:Vector2i):return world(a).distance_squared_to(center)<world(b).distance_squared_to(center))
	for q in area:
		var node:=_convert(q,2)
		node.position.y+=.28
		create_tween().tween_property(node,"position:y",HEIGHT,.17).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		fx.glint(world(q)+Vector3.UP*.22,.6,.42)
		await get_tree().create_timer(.014).timeout
	ui.stage.inscription("moon",2)
	await get_tree().create_timer(2.7).timeout
	await _cinema_end()
	await _round_end(.25)

func _cosmos(p:Vector2i) -> void:
	if busy or paused or not rules.can_charge():return
	var result:=rules.cosmos(p)
	if not result.ok:return
	busy=true
	acting_player=0
	acting_color=Rules.BLACK
	save_match()
	_refresh()
	if not ui.effects_on:
		await _finish_plain_skill("cosmos_impact",-4)
		return
	var origin:=world(p)
	var stone:=_make_stone(p,1)
	stone.position=origin+Vector3.UP*2.25
	stone.scale=Vector3.ONE*3.5
	var mat:=ShaderMaterial.new()
	mat.shader=preload("res://shaders/stone_ink.gdshader")
	mat.set_shader_parameter("charge",1.0)
	for mesh:MeshInstance3D in stone.find_children("*","MeshInstance3D"):mesh.material_override=mat
	_cinema_begin(1,origin,true)
	fx.sound("cosmos_descent",-6)
	fx.smoke(stone.position,1,3.0,false,45,1.5).reparent(stone)
	await get_tree().create_timer(.55).timeout
	var hang:=create_tween()
	hang.tween_property(stone,"position:y",HEIGHT+2.55,.25).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	await hang.finished
	var slam:=create_tween().set_parallel()
	slam.tween_property(stone,"position",origin,.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	slam.tween_property(stone,"scale",Vector3.ONE,.20).set_trans(Tween.TRANS_QUART).set_ease(Tween.EASE_IN)
	await slam.finished
	_neutral_stone(stone,1)
	for child in stone.get_children():
		if child is GPUParticles3D:child.queue_free()
	fx.bind_aura(stone,1)
	fx.sound("cosmos_impact",-4)
	scenery.duck(1.0)
	ui.stage.strike(1.25)
	shake(.15,.9)
	fx.wave(origin,1,16,1.3)
	fx.smoke(origin+Vector3.UP*.15,1,3.4,true,75,1.45)
	fx.slashes(origin,1,6.8,22)
	_camera_to(Vector3(-.6,11.8,10.4),Vector3(0,.4,0),43,.75)
	var cells:Array[Vector2i]=[]
	for y in 15:
		for x in 15:cells.append(Vector2i(x,y))
	cells.sort_custom(func(a:Vector2i,b:Vector2i):return a.distance_squared_to(p)<b.distance_squared_to(p))
	var progress:={"index":0}
	var fill:=create_tween()
	fill.tween_method(func(radius:float):
		while progress.index<cells.size():
			var q:Vector2i=cells[progress.index]
			if Vector2(q-p).length()>radius:break
			var node:=_convert(q,1,false)
			node.scale=Vector3.ONE*.15
			create_tween().tween_property(node,"scale",Vector3.ONE,.22).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
			if progress.index%8==0:fx.smoke(world(q)+Vector3.UP*.12,1,1.15,true,10,1.0)
			progress.index+=1
	,0.0,21.0,1.25).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	await fill.finished
	ui.stage.strike(.35)
	ui.stage.inscription("cosmos",1)
	await get_tree().create_timer(2.75).timeout
	await _cinema_end()
	await _round_end(.25)

func _finish_plain_skill(cue:String, volume:float) -> void:
	fx.clear_lightning()
	# Gameplay resolves identically with visuals off; synchronize pieces directly.
	for y in Rules.SIZE:
		for x in Rules.SIZE:
			var p:=Vector2i(x,y)
			var color:=rules.at(p)
			if color!=Rules.EMPTY:
				_convert(p,color,false)
			elif stones.has(p):
				stones[p].queue_free()
				stones.erase(p)
	fx.sound(cue,volume)
	scenery.duck(.8)
	save_match()
	await _round_end(.3)

func _divine_hand() -> void:
	if busy or paused or not playing:return
	var result:=rules.divine_hand()
	if not result.ok:return
	busy=true
	acting_player=0
	acting_color=Rules.WHITE
	_cancel_gesture()
	_hide_hover()
	fx.clear_lightning()
	save_match()
	_refresh()
	if not ui.effects_on:
		await _finish_plain_skill("hand_impact",-5)
		return
	var focus:=world(Vector2i(7,7))
	_cinema_begin(Rules.WHITE,focus)
	_camera_to(Vector3(0,11.8,10.5),Vector3(0,1.1,.1),44,.65)
	hand_effect=DivineHand.new()
	hand_effect.source=HAND_TOKEN_POSITION
	hand_effect.cell_landed.connect(func(p:Vector2i):
		_convert(p,Rules.WHITE,false)
		if (p.x+p.y)%9==0:fx.glint(world(p)+Vector3.UP*.12,.44,.34)
	)
	add_child(hand_effect)
	fx.sound("hand_gather",-8)
	fx.glint(HAND_TOKEN_POSITION+Vector3.UP*.14,.8,.55)
	fx.smoke(HAND_TOKEN_POSITION+Vector3.UP*.18,Rules.WHITE,1.0,true,22,.85)
	for i in 4:
		var trail:Array[Vector3]=[]
		var end:=world(Vector2i(8+i,5))+Vector3.UP*2.0
		var bend:=HAND_TOKEN_POSITION.lerp(end,.50)+Vector3(0,2.9+float(i)*.15,0)
		for j in 20:
			var t:=float(j)/19.0
			trail.append(HAND_TOKEN_POSITION.lerp(bend,t).lerp(bend.lerp(end,t),t))
		fx.fade(fx.ribbon(trail,.04,Color(.94,.94,.94,.48),true),1.4)
	await hand_effect.assembled
	fx.sound("hand_point",-9)
	await hand_effect.contacted
	fx.sound("hand_impact",-5)
	scenery.duck(1.0)
	ui.stage.strike(.9)
	shake(.075,.5)
	var tip:=world(Rules.HAND_TIP)
	fx.glint(tip+Vector3.UP*.15,2.5,.6)
	fx.wave(tip,Rules.WHITE,15.5,.86)
	fx.slashes(tip,Rules.WHITE,4.7,11)
	fx.smoke(tip+Vector3.UP*.1,Rules.WHITE,1.5,true,35,.8)
	await hand_effect.finished
	hand_effect.queue_free()
	hand_effect=null
	ui.stage.inscription("divine_hand",Rules.WHITE)
	await get_tree().create_timer(2.7).timeout
	await _cinema_end()
	await _round_end(.25)

func shake(strength:float, duration:float) -> void:
	if not ui.effects_on:return
	shake_strength=strength
	shake_remaining=duration

func _round_end(delay:float=1.2) -> void:
	busy=true
	fx.clear_lightning()
	_refresh()
	if rules.round_winner==0 and rules.finish_kind=="normal":
		var color:=rules.color_for(0)
		fx.sound("victory",-10)
		if rules.has_effects(color):
			for p:Vector2i in rules.winning_line:fx.smoke(world(p)+Vector3.UP*.1,color,1.4,true,18,1.0)
	save_match()
	await get_tree().create_timer(delay).timeout
	busy=false
	ui.show_result(rules)
	_refresh()

func next_round() -> void:
	if rules.match_winner >= 0:
		rules.reset_match()
	elif not rules.next_round():
		return
	_start_board()
	save_match()

func return_to_menu() -> void:
	if busy:
		return
	_cancel_gesture()
	save_match()
	playing = false
	paused = false
	scenery.set_camera(false,true)
	ui.show_menu(not saved_match.is_empty())

func save_match() -> void:
	if verification_mode:
		return
	saved_match = {"players":names.duplicate(),"rules":rules.serialize()}
	var file := FileAccess.open(SAVE_PATH+".tmp",FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(saved_match))
		file.close()
		DirAccess.rename_absolute(SAVE_PATH+".tmp",SAVE_PATH)

func _load_match() -> void:
	if verification_mode or not FileAccess.file_exists(SAVE_PATH):
		return
	var data = JSON.parse_string(FileAccess.get_file_as_string(SAVE_PATH))
	if not data is Dictionary or not data.get("players") is Array or data.players.size() != 2:
		return
	var probe := Rules.new()
	if not data.get("rules") is Dictionary or not probe.restore(data.rules):
		return
	saved_match = data

func resume_match() -> void:
	if saved_match.is_empty():
		return
	if rules.restore(saved_match.rules):
		names = saved_match.players.duplicate()
		_start_board()

func apply_settings(sound: bool, music: bool, quality: bool, effects: bool = true, skills: bool = true) -> void:
	var visual_change:=rules.effects_enabled!=effects
	var skill_change:=rules.skills_enabled!=skills
	if visual_change or skill_change:_cancel_gesture()
	ui.sound_on=sound
	ui.music_on=music
	ui.high_quality=quality
	ui.effects_on=effects
	ui.skills_on=skills
	rules.configure_features(effects,skills)
	fx.set_visuals_enabled(effects)
	if visual_change:
		shake_remaining=0.0
		for p:Vector2i in stones:
			var stone:Node3D=stones[p]
			if not effects:
				stone.remove_meta("aura")
			elif rules.has_effects(rules.at(p)):
				fx.bind_aura(stone,rules.at(p))
	scenery.settings(sound,music,quality)
	fx.set_sound_enabled(sound)
	if verification_mode:
		return
	if (visual_change or skill_change) and playing and not busy:save_match()
	_save_settings()

func _save_settings(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	config.set_value("audio","sound",ui.sound_on)
	config.set_value("audio","music",ui.music_on)
	config.set_value("graphics","full",ui.high_quality)
	config.set_value("graphics","effects",ui.effects_on)
	config.set_value("gameplay","skills",ui.skills_on)
	config.save(path)

func _load_settings(path: String = SETTINGS_PATH) -> void:
	var config := ConfigFile.new()
	config.load(path)
	ui.sound_on = config.get_value("audio","sound",true)
	ui.music_on = config.get_value("audio","music",true)
	ui.high_quality = config.get_value("graphics","full",true)
	ui.effects_on = config.get_value("graphics","effects",true)
	ui.skills_on = config.get_value("gameplay","skills",true)
	apply_settings(ui.sound_on,ui.music_on,ui.high_quality,ui.effects_on,ui.skills_on)
