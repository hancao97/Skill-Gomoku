extends Node

var game
var checks:=0
var failures:Array[String]=[]
var output:="":
	set(value):
		output=value
		if not value.is_empty():DirAccess.make_dir_recursive_absolute(value)
var contacts:Array[Dictionary]=[]

func pause(seconds:float) -> void:
	await get_tree().create_timer(seconds).timeout

func check(value:bool, detail:String) -> void:
	checks+=1
	if not value:
		failures.append(detail)
		push_error("V2 FAILED: "+detail)
	else:print("V2 PASS: "+detail)

func capture(name:String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(output+"/"+name+".png")
	print("CAPTURE: ",name," FPS: ",Engine.get_frames_per_second())

func button(pos:Vector2, down:bool) -> void:
	var event:=InputEventMouseButton.new()
	event.set_meta("replay_input",true)
	event.position=pos;event.global_position=pos
	event.button_index=MOUSE_BUTTON_LEFT
	event.button_mask=MOUSE_BUTTON_MASK_LEFT if down else 0
	event.pressed=down
	get_viewport().push_input(event,true)

func motion(pos:Vector2) -> void:
	var event:=InputEventMouseMotion.new()
	event.set_meta("replay_input",true)
	event.position=pos;event.global_position=pos
	event.button_mask=MOUSE_BUTTON_MASK_LEFT
	get_viewport().push_input(event,true)

func pos(p:Vector2i) -> Vector2:
	return game.scenery.camera.unproject_position(game.world(p))

func click(p:Vector2i) -> void:
	button(pos(p),true)
	button(pos(p),false)
	await pause(.48)

func idle() -> void:
	var until:=Time.get_ticks_msec()+14000
	while game.busy and Time.get_ticks_msec()<until:await pause(.08)
	check(not game.busy,"animation releases input")

func inscription(key:String) -> void:
	var until:=Time.get_ticks_msec()+10000
	while game.ui.stage.title_key!=key and Time.get_ticks_msec()<until:await pause(.04)
	check(game.ui.stage.title_key==key,"ink inscription "+key)
	await pause(.82)

func fixture(round_index:int=0, turn:int=1) -> void:
	game.rules.reset_match()
	game.rules.round_index=round_index
	game.rules.turn=turn
	game._start_board()
	await pause(1.65)

func seed_board(cells:Array, color:int) -> void:
	for cell in cells:
		var p:=Vector2i(cell[0],cell[1])
		game.rules.put(p,color)
		var node:Node3D=game._make_stone(p,color)
		if game.rules.has_effects(color):game.fx.bind_aura(node,color)

func run(target) -> void:
	game=target
	game.apply_settings(true,true,true)
	var version:=str(ProjectSettings.get_setting("application/config/version")).split(".")
	output=ProjectSettings.globalize_path("res://verification/v%s.%s"%[version[0],version[1]])
	if OS.get_cmdline_user_args().has("--showcase"):
		await showcase()
		get_tree().quit()
		return
	game.fx.child_entered_tree.connect(func(node:Node):
		if node is AudioStreamPlayer and node.stream.resource_path.contains("/stone_"):
			var stone:Node3D=game.stones.get(game.rules.last)
			contacts.append({"height":stone.position.y if stone else -1.0,"sample":node.stream.resource_path,"rate":node.stream.mix_rate})
	)
	await pause(2.5)
	game.begin_match(["墨客","听雨"])
	await pause(1.65)
	check(game.scenery.rain_audio.stream is AudioStreamOggVorbis and game.scenery.rain_audio.stream.loop and absf(game.scenery.rain_audio.stream.get_length()-60)<.1,"60 second stereo recording loops by time")
	var ui_words:=""
	for node in game.ui.hud.find_children("*","Label",true,false):ui_words+=node.text
	check(not ["棋魂","技能","拉弓","蓄力","天地","遥遥","收弓"].any(func(word:String):return ui_words.contains(word)),"HUD does not reveal hidden skills")
	await click(Vector2i(7,7));await click(Vector2i(7,8))
	check(contacts.size()==2 and contacts.all(func(d:Dictionary):return is_equal_approx(d.height,game.HEIGHT) and d.rate==48000),"recorded stone clack begins at contact for both players")
	check(contacts.size()>=2 and contacts[0].sample!=contacts[1].sample,"subtle placement sample variation")
	await capture("01-normal-board")
	for index in 2:
		for player in [1,0]:
			var color:int=1 if player==index else 2
			await fixture(index,color)
			await click(Vector2i(7,7))
			var node:Node3D=game.stones[Vector2i(7,7)]
			var aura=node.find_children("*","GPUParticles3D",true,false)
			if player==1:
				check(aura.is_empty() and not game.fx.get_children().any(func(n:Node):return n is GeometryInstance3D),"player two has zero placement VFX, color %d"%color)
			else:
				check(aura.size()==1 and aura[0].get_meta("stone_color")==color,"first player keeps VFX in their current color %d"%color)
			await capture("player-%d-color-%d"%[player,color])
	# Both colors belonging to the other player stay plain even when held down.
	for index in 2:
		var color:int=2-index
		await fixture(index,color)
		button(pos(Vector2i(8,8)),true)
		await pause(2.15)
		check(not is_instance_valid(game.charge_preview),"other player cannot charge, color %d"%color)
		button(pos(Vector2i(8,8)),false)
		await pause(.4)
		check(game.rules.move_count==1 and game.rules.active(),"ordinary held click remains a normal move")
	await fixture(0,1)
	var press:=pos(Vector2i(8,8))
	button(press,true);await pause(.65)
	motion(press+Vector2(60,0));await pause(.1)
	button(press+Vector2(60,0),false)
	check(game.rules.move_count==0 and not is_instance_valid(game.charge_preview),"leaving the point cancels charge without placing")
	button(press,true);await pause(.5)
	game.ui.show_pause();await pause(.1)
	check(not is_instance_valid(game.charge_preview),"pause cancels held preview")
	button(press,false)
	game.ui.close_modal()
	# Exact T: White must reply, no readiness marker, outward drag fires toward center.
	await fixture(0,1)
	seed_board([[7,5],[7,6],[6,6]],1);seed_board([[8,6],[10,6]],2)
	await click(Vector2i(7,7))
	check(game.rules.turn==2 and game.rules.pending_skill=="","T waits for White's move")
	await click(Vector2i(0,0))
	check(game.rules.pending_skill=="bow" and not is_instance_valid(game.bow_preview),"ready bow remains hidden")
	await capture("02-bow-hidden")
	var start:=pos(Vector2i(6,6))
	var pull:Vector2=game.scenery.camera.unproject_position(game.world(Vector2i(6,6))+Vector3(-.95,0,0))
	button(start,true);motion(pull);await pause(.3)
	check(game.direction==Vector2i(1,0),"outward pull fixes arrow through middle")
	await capture("03-bow-draw")
	button(pull,false)
	await pause(.6);await capture("04-bow-flight")
	await inscription("bow");await capture("05-bow-calligraphy")
	check(game.rules.round_winner==0 and game.rules.wins==[1,0],"bow instantly awards one win")
	for x in range(7,15):check(game.rules.at(Vector2i(x,6))==1 and game.stones.has(Vector2i(x,6)),"bow fills visible ray including empty x=%d"%x)
	await idle()
	# White power after color swap, full 25 point square.
	await fixture(1,2)
	seed_board([[7,7],[8,7],[7,8]],2)
	seed_board([[6,7],[9,8],[4,3]],1)
	await click(Vector2i(8,8))
	await pause(.55);await capture("06-moon-orbit")
	await inscription("moon");await capture("07-moon-calligraphy")
	check(game.rules.board.count(2)==25 and game.rules.at(Vector2i(4,3))==1,"moon fills exactly 5 by 5 and preserves outside")
	check(game.stones.values().filter(func(n:Node3D):return n.get_meta("color")==2).size()==25,"25 white models match rules")
	await idle()
	# Long press an empty BOARD point, then release the charged stone.
	await fixture(0,1)
	seed_board([[6,6],[8,6],[7,9]],1);seed_board([[7,6],[8,8],[9,7]],2)
	press=pos(Vector2i(7,7))
	button(press,true);await pause(2.15)
	check(game.charge_ready and game.rules.move_count==0,"stationary board long press charges without premature placement")
	await capture("08-board-charge")
	button(press,false)
	await pause(.62);await capture("09-cosmos-closeup")
	await pause(.6);await capture("10-cosmos-impact")
	await inscription("cosmos");await capture("11-cosmos-calligraphy")
	check(game.rules.board.count(1)==225 and game.stones.size()==225 and game.rules.wins==[1,0],"cosmos fills all 225 intersections and scores once")
	await idle()
	await capture("12-result")
	var file:=FileAccess.open(output+"/playback-result.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"checks":checks,"failures":failures,"contacts":contacts},"  "))
	print("V2 PLAYBACK: ",checks," checks; ",failures.size()," failures")
	await game._shutdown_audio()
	get_tree().quit(0 if failures.is_empty() else 1)

func showcase() -> void:
	await fixture(0,1)
	seed_board([[7,5],[7,6],[6,6]],1);seed_board([[8,6],[10,6]],2)
	await click(Vector2i(7,7));await click(Vector2i(0,0))
	var start:=pos(Vector2i(6,6))
	var end:Vector2=game.scenery.camera.unproject_position(game.world(Vector2i(6,6))+Vector3(-1.0,0,0))
	button(start,true)
	for i in 20:
		motion(start.lerp(end,float(i+1)/20))
		await pause(.025)
	await pause(.3)
	button(end,false)
	await idle()
	await fixture(1,2)
	seed_board([[7,7],[8,7],[7,8]],2);seed_board([[6,7],[9,8],[4,3]],1)
	await click(Vector2i(8,8))
	await idle()
	await fixture(0,1)
	seed_board([[6,6],[8,6],[7,9]],1);seed_board([[7,6],[8,8],[9,7]],2)
	start=pos(Vector2i(7,7))
	button(start,true)
	await pause(2.25)
	button(start,false)
	await idle()
