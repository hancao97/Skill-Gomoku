extends Control

signal charge_ready
signal released(screen_position: Vector2)
var enabled := false
var charging := false
var ready_to_place := false
var progress := 0.0
var distance := 0.0
var reversals := 0
var last_direction := Vector2.ZERO
var clock := 0.0
var held_seconds := 0.0
var serif: Font

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	var variation := FontVariation.new()
	variation.base_font = load("res://assets/fonts/NotoSerifSC.ttf")
	variation.variation_opentype = {TextServerManager.get_primary_interface().name_to_tag("wght"):500.0}
	serif = variation
	set_process_input(true)

func reset() -> void:
	charging = false
	ready_to_place = false
	progress = 0
	distance = 0
	reversals = 0
	held_seconds = 0
	last_direction = Vector2.ZERO
	queue_redraw()

func _process(delta: float) -> void:
	clock += delta
	if charging:
		held_seconds += delta
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if not enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		if not ready_to_place:
			charging = true
		accept_event()

func _input(event: InputEvent) -> void:
	if not charging:
		return
	if event is InputEventMouseMotion:
		feed_motion(event.relative)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		charging = false
		if ready_to_place:
			released.emit(event.position)
		else:
			distance *= .75
			progress = minf(distance / 1700.0, .94)
		get_viewport().set_input_as_handled()

func feed_motion(relative: Vector2) -> void:
	if ready_to_place:
		return
	var step := relative.length()
	if step < 3.0:
		return
	var direction := relative.normalized()
	if last_direction != Vector2.ZERO and last_direction.dot(direction) < -.42:
		reversals += 1
	last_direction = direction
	distance += minf(step,90.0)
	progress = minf(minf(distance/1700.0, float(reversals)/9.0), .99)
	if distance >= 1700 and reversals >= 9 and held_seconds >= 1.5 and not ready_to_place:
		ready_to_place = true
		progress = 1.0
		charge_ready.emit()

func _draw() -> void:
	var center := Vector2(size.x*.5,54)
	var alpha := 1.0 if enabled else .27
	draw_circle(center,43,Color(.035,.10,.085,.7))
	draw_arc(center,45,-PI*.5,TAU-PI*.5,96,Color(.6,.65,.52,.15*alpha),1,true)
	if progress > 0:
		for i in 70:
			var start := -PI*.5 + TAU*float(i)/70.0
			if float(i)/70.0 > progress:
				break
			var tint := Color.from_hsv(fmod(float(i)/70.0+clock*.09,1.0),.48,1.0,alpha)
			draw_arc(center,45,start,start+TAU/70.0,3,tint,3,true)
	var radius := 31.0 + sin(clock*3.5)*progress*2.0
	for i in range(12,0,-1):
		var r := radius + float(i)*1.4
		var glow := Color.from_hsv(fmod(clock*.12+float(i)*.018,1.0),.65,.95,(.02+progress*.018)*alpha)
		draw_circle(center,r,glow)
	draw_circle(center+Vector2(0,3),radius,Color(0,0,0,.6*alpha))
	for i in range(30,0,-1):
		var t := float(i)/30.0
		var shade := .03 + (1.0-t)*.1
		var col := Color(shade*.65,shade,shade*.96,alpha)
		if ready_to_place:
			col = Color.from_hsv(fmod(clock*.18+t*.5,1.0),.45,.35+(1.0-t)*.65,alpha)
		draw_circle(center+Vector2(-3,-4)*(1.0-t),radius*t,col)
	draw_arc(center+Vector2(-4,-4),20,PI*1.05,PI*1.55,22,Color(.7,.88,.8,.38*alpha),2,true)
	var text := "炫彩已成 · 落子开天" if ready_to_place else ("来回搓动  %d%%" % int(progress*100) if charging else "按住棋魂石 · 来回搓动")
	draw_string(serif,Vector2((size.x-serif.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,14).x)*.5,122),text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color(.77,.83,.74,alpha))
	var hint := "拖到空位松手，或点击空位" if ready_to_place else ("仅首局执黑者，执黑时可用" if not enabled else "蓄满炫彩，落子即「天地大同」")
	draw_string(serif,Vector2((size.x-serif.get_string_size(hint,HORIZONTAL_ALIGNMENT_LEFT,-1,11).x)*.5,145),hint,HORIZONTAL_ALIGNMENT_LEFT,-1,11,Color(.51,.63,.55,alpha))
